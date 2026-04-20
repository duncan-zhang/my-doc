# 實驗筆記：Cloud Hosted Router (MikroTik) 部署與路由管理

## 1. 研究目標
* 實踐 VPC 內部流量導向 CHR 進行統一管理（防火牆、頻寬限制、VPN 等）。
* 建立具備高度可控性的出口（Outbound）網路環境。

## 2. 實驗架構

### A. 網路層級 (VPC & Subnets)
* **VPC**: `Duncan-VPC` (10.0.0.0/16)
* **管理網段 (Public Subnet)**:
    * `EC2` (10.0.0.0/22)
    * 部署 CHR，需配置 **Public IP**
    * Route Table 指向 **Internet Gateway (IGW)**。
* **私有網段 (Private Subnet)**:
    * `EKS-Tertiary` (10.0.48.0/20)
    * 模擬後端應用程式，無 Public IP。

### B. 虛擬主機 (Virtual Machines)
1.  **MikroTik CHR**:
    * **核心設定**: 必須在 AWS Console 執行 `Actions` -> `Networking` -> `Change source/destination check` -> **Stop**。
      若無法使用請同時確認ENI的`Change source/destination check`是否也關閉
      要開啟firewall masquerade功能
    * **角色**: 作為 `EKS-Tertiary` 的 Default Gateway (NAT 閘道器)。
2.  **Amazon Linux**:
    * **角色**: 測試端點，位於私有網段`EKS-Tertiary`。

## 3. 關鍵配置補充 (Missing Pieces)

要讓此架構運作，除了 AWS 路由表，CHR 內部必須完成以下配置：

### I. MikroTik 內部 NAT 設定
若不設定 Source NAT (Masquerade)，封包離開 CHR 進入 Internet 後，回傳時會找不到私有 IP。
```bash
# 透過 WinBox 終端機或 SSH 執行
/ip firewall nat
add chain=srcnat action=masquerade out-interface=ether1 comment="Allow Subnet to CHR Outbound"
```

### II. AWS 路由表 (Route Table) 設定
請確認 `RTB-Tertiary` 的設定如下：
| Destination | Target | 說明 |
| :--- | :--- | :--- |
| 10.0.0.0/16 | local | VPC 內部互通 |
| **0.0.0.0/0** | **eni-XXXXX** | **所有對外流量強制導向 CHR 的網卡** |

### III. 安全組 (Security Group) 規則建議
* **CHR Security Group**:
    * **Inbound**: 
        * 允許 `10.0.48.0/20` (All Traffic)
        * 允許你的管理 IP (WinBox 8291, SSH 22)
    * **Outbound**: 允許 `0.0.0.0/0` (All Traffic)

## 4. 測試結果

### 第一階段：連通性測試
在 **Amazon Linux** 上執行：
1.  `ping 8.8.8.8` 可ping通

### 第二階段：出口 IP 驗證 (Identity)
在 **Amazon Linux** 上執行：
* **指令**: `curl ifconfig.me`
* **意義**: 證明 SNAT (Source NAT) 成功，外部伺服器只會看到 Router 的地址。
* **結果**: 回傳的 IP 是 **CHR 的 Elastic IP (EIP)**。

## 5. 結論與分析
* 測試結果符合預期，可透過CHR控制對外上網控制。


