# [實驗筆記] Kubernetes 出口流量管理：基於 MikroTik CHR 的多出口 PCC 分流架構

## 1. 研究目標
* **流量導向控制**：實踐 K8s Pod 流量經由 MikroTik CHR 進行統一出口管理。
* **高動態輪詢**：建立具備高度輪詢（PCC）能力的多出口（Outbound）網路環境，實現 IP 負載平衡。

---

## 2. 網路層級規劃 (VPC & Subnets)

### A. 基礎設施配置
* **VPC**: `Duncan-VPC` (10.0.0.0/16)
* **外網規劃 (Public Subnet)**：作為多 IP 路由配送出口，各網段互不干涉。
    * `EC2-Public-01`: 10.0.100.0/28 (Target: IGW)
    * `EC2-Public-02`: 10.0.100.16/28 (Target: IGW)
    * `EC2-Public-03`: 10.0.100.32/28 (Target: IGW)
* **私有網段 (Private Subnet)**：K8s Node 規劃網段，預設路由指向 CHR。
    * `EKS-Primary`: 10.0.16.0/20
    * `EKS-Secondary`: 10.0.32.0/20

---

## 3. 核心配置步驟

### Step 1. AWS 虛擬硬體配置
1.  **ENI 建立與綁定**：
    * 分別在 `EC2-Public-02` 與 `03` 建立獨立的 Network Interface (ENI)。
    * **關鍵動作**：關閉 `Source/Destination Check` (Disable)。
2.  **EIP 關聯**：申請兩組 Elastic IP，並以 1:1 方式關聯至上述產出的 ENI。
3.  **掛載至 CHR**：將新增的 ENI 掛載至 MikroTik CHR 執行體，系統將識別為 `ether2` 與 `ether3`。

### Step 2. MikroTik CHR 內部配置
#### 1. 介面與路由初始化
```sh
# IP 位址配置
/ip address
add address=10.0.100.8/28 interface=ether2
add address=10.0.100.39/28 interface=ether3

# 建立 FDB 路由表 (為 PCC 做準備)
/routing table
add name=to_WAN1 fib
add name=to_WAN2 fib
add name=to_WAN3 fib

# 配置預設路由與分流地圖
/ip route
add dst-address=0.0.0.0/0 gateway=10.0.100.1 distance=1 check-gateway=ping
add dst-address=0.0.0.0/0 gateway=10.0.100.17 distance=2 check-gateway=ping 
add dst-address=0.0.0.0/0 gateway=10.0.100.33 distance=3 check-gateway=ping 

add dst-address=0.0.0.0/0 gateway=10.0.100.1 routing-table=to_WAN1 check-gateway=ping
add dst-address=0.0.0.0/0 gateway=10.0.100.17 routing-table=to_WAN2 check-gateway=ping
add dst-address=0.0.0.0/0 gateway=10.0.100.33 routing-table=to_WAN3 check-gateway=ping
```

#### 2. 防火牆與 PCC 標記 (Mangle)
```sh
/ip firewall mangle
# 1. 內網互訪白名單排除
add chain=prerouting action=accept dst-address=10.0.0.0/8 in-interface=ether1

# 2. Input 標記：確保回程路徑一致
add chain=input action=mark-connection new-connection-mark=WAN1_conn passthrough=yes in-interface=ether1
add chain=input action=mark-connection new-connection-mark=WAN2_conn passthrough=yes in-interface=ether2
add chain=input action=mark-connection new-connection-mark=WAN3_conn passthrough=yes in-interface=ether3

# 3. PCC 核心分流 (3線輪詢)
add chain=prerouting action=mark-connection new-connection-mark=WAN1_conn passthrough=yes \
    connection-state=new dst-address-type=!local in-interface=ether1 per-connection-classifier=both-addresses-and-ports:3/0
add chain=prerouting action=mark-connection new-connection-mark=WAN2_conn passthrough=yes \
    connection-state=new dst-address-type=!local in-interface=ether1 per-connection-classifier=both-addresses-and-ports:3/1
add chain=prerouting action=mark-connection new-connection-mark=WAN3_conn passthrough=yes \
    connection-state=new dst-address-type=!local in-interface=ether1 per-connection-classifier=both-addresses-and-ports:3/2

# 4. 路由引導 (Prerouting & Output)
add chain=prerouting action=mark-routing new-routing-mark=to_WAN1 passthrough=no connection-mark=WAN1_conn in-interface=ether1
add chain=prerouting action=mark-routing new-routing-mark=to_WAN2 passthrough=no connection-mark=WAN2_conn in-interface=ether1
add chain=prerouting action=mark-routing new-routing-mark=to_WAN3 passthrough=no connection-mark=WAN3_conn in-interface=ether1

add chain=output action=mark-routing new-routing-mark=to_WAN1 passthrough=no connection-mark=WAN1_conn
add chain=output action=mark-routing new-routing-mark=to_WAN2 passthrough=no connection-mark=WAN2_conn
add chain=output action=mark-routing new-routing-mark=to_WAN3 passthrough=no connection-mark=WAN3_conn

# 5. NAT 與系統優化
/ip firewall nat
add chain=srcnat out-interface=ether1 action=masquerade
add chain=srcnat out-interface=ether2 action=masquerade
add chain=srcnat out-interface=ether3 action=masquerade

/ip settings set rp-filter=loose
```

---

## 4. 驗證機制

### A. 測試環境部署
使用 `alpine.yaml` 建立測試 Pod，並掛載必要的測試工具。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-alpine
  annotations:
    sidecar.istio.io/inject: "true"
spec:
  containers:
  - name: alpine
    image: alpine:
    command:
      - "/bin/sh"
      - "-c"
      - |
        apk add --no-cache curl bind-tools openssh-client
        echo "Curl installed. Ready for testing."
        sleep infinity
    volumeMounts:
    - name: ssh-key-volume
      mountPath: /root/.ssh
      readOnly: true
  volumes:
  - name: ssh-key-volume
    secret:
      secretName: duncan-ssh-key
      defaultMode: 0400
```

### B. 多 IP 輪詢腳本 (`myip.sh`)
執行此腳本持續發送請求，觀察輸出之外部 IP 是否呈現輪詢狀態。
```sh
#!/bin/sh
TOTAL=60
i=1
echo "--- 開始執行 3-WAN 出口輪詢測試 ---"
while [ $i -le $TOTAL ]; do
    CURRENT_IP=$(curl -s --max-time 2 http://ifconfig.me)
    CURRENT_TIME=$(date +%H:%M:%S)
    [ -z "$CURRENT_IP" ] && echo "$CURRENT_TIME | FAIL" || echo "$CURRENT_TIME | IP: $CURRENT_IP"
    i=$((i + 1))
    sleep 1
done
```

---

## 5. 注意事項與提醒
* **AWS Check**: 務必確認 AWS Console 上的 `Source/Destination Check` 已關閉，否則封包會被 VPC 丟棄。
* **路由對稱**：使用 `rp-filter=loose` 解決非對稱路由導致的連線中斷問題。
* **白名單**：Mangle 第一條規則的內網白名單（10.0.0.0/8）不可省略，否則會影響 EKS 內部 Service 與 API Server 的通訊。

