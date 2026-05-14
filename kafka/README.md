# 🚀 Kafka on Kubernetes (Strimzi) 研究與實作專案

本專案旨在研究並實踐如何將 **Apache Kafka** 部署於 **Kubernetes (K8s)** 環境。透過 **Strimzi Operator** 實現 Kafka 叢集的聲明式管理，並建置完整的 UI 監控與指標匯出體系。

---

## 📖 Kafka 核心概念 (Core Concepts)

Kafka 是分布式的「數位中央神經系統」，其底層與傳統 Message Queue 有本質區別。

### 🔹 四大核心組件

* **Producer (生產者)**：發布訊息至 Topic。
* **Broker (代理伺服器)**：儲存與轉發數據的節點，K8s 中以 `StatefulSet` 呈現。
* **Topic (主題)**：數據分類標籤，由多個 **Partition (分區)** 組成。
* **Consumer (消費者)**：訂閱 Topic 並處理數據，透過 **Offset (書籤)** 記錄讀取進度。

### 🔹 Log 持久化機制

* 採用 **Append-only Log** 結構，數據不會因讀取後消失。
* **Retention Policy**：根據時間或大小限制自動清理舊數據。

---

## 🛠️ Strimzi 元件架構 (Strimzi Components)

Strimzi 將 Kafka 管理自動化，以下是本專案使用的關鍵自定義資源 (CR)：

| 元件名稱 | 職責 | 關鍵說明 |
| --- | --- | --- |
| **Cluster Operator** | 叢集大腦 | 負責監控 YAML 變更並自動部署 Kafka 基礎設施。 |
| **Listeners** | 連線入口 | **核心功能**：自動建立 Bootstrap Service 與 Per-Broker Service。支援 `internal` 或 `loadbalancer`。 |
| **KafkaNodePools** | 節點池管理 | 支援 KRaft 模式，可分離 Controller 與 Broker 節點，實現冷熱數據儲存分離。 |
| **Entity Operator** | 內部管理 | 包含 **Topic Operator** (管理 Topic CR) 與 **User Operator** (管理權限/憑證)。 |
| **Kafka Exporter** | 數據轉譯 | 將 Kafka JMX 指標轉為 Prometheus 格式，用於監測消費堆積 (Lag)。 |

---

## 🏗️ 環境部署 (Installation)

### 1. 安裝 Strimzi Operator

使用 Helm 部署管理員，設定監控所有 Namespace：

```bash
# 建立專屬 Namespace
kubectl create namespace kafka
kubectl create namespace operator

# 安裝 Operator
helm install strimzi-cluster-operator oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --namespace operator \
  --version 0.45.1 \
  --set watchAnyNamespace=true

```

> 💡 **註**：`watchAnyNamespace=true` 會自動建立 ClusterRole，允許 Operator 跨 Namespace 管理 Kafka 資源。

### 2. 部署 Kafka 叢集

套用設定檔以建立實體叢集與監控指標配置：

```bash
# 配置 Prometheus 指標抓取規則 (ConfigMap)
kubectl apply -f kafka-metrics.yaml -n kafka

# 部署 Kafka Cluster (含 Broker/Controller 定義)
kubectl apply -f kafka-cluster.yaml -n kafka

```

### 3. 部署管理工具 (Kafka UI)

本專案提供兩種權限等級的 UI 介面：

```bash
# 部署 Admin 版 (具備建立 Topic/生產訊息權限)
kubectl apply -f kafka-ui-admin.yaml -n kafka

# 部署 Viewer 版 (僅供檢視數據與監測使用)
kubectl apply -f kafka-ui-viewer.yaml -n kafka

```

---

## 🚀 實作連線與測試 (Testing)

### 1. 內部連線資訊

K8s 內部 Service 地址（供應用程式連線使用）：
`kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`

### 2. 資料注入測試

使用專案提供的腳本進行模擬測試：

```bash
# 1. 建立測試用 Topic
kubectl apply -f kafka-topic.yaml -n kafka

# 2. 注入測試資料
chmod +x topic-date.sh
./topic-date.sh

```

> ✅ **驗證方式**：登入 Kafka UI (Admin) 查看 `Messages` 頁籤，確認資料是否正確寫入各個 Partition。

---

## 🔍 監控排錯流程 (Troubleshooting)

### ❗ 核心守則：異常時先看 Operator 日誌

當你執行 `kubectl apply` 部署 Kafka 相關資源（如 Cluster、Topic、User）卻發現沒有生效或 Pod 狀態異常時，請檢查 **Cluster Operator** 的日誌，它會告訴你 YAML 解析錯誤或資源分配失敗的原因。

**查看 Operator 日誌指令：**

```bash
# 透過 Label 直接抓取 operator pod 日誌
kubectl logs -f -n operator -l name=strimzi-cluster-operator

```

### 🛠️ 其他常見排查步驟

1. **檢查 Pod 狀態**：`kubectl get pods -n kafka` (確保 Broker 與 Controller 均為 1/1 Ready)。
2. **檢查 UI 連線**：若 UI 顯示 Offline，檢查 UI Pod 的 Log 是否有 `UnknownHostException`。
3. **檢查 Service Endpoints**：確認 Bootstrap Service 是否正確綁定到 Broker IP。

---

## 📊 監控維運 (Monitoring)

若需啟動指標監控，請套用 PodMonitor：

```bash
# 提供 metric 給 Prometheus 抓取
kubectl apply -f kafka-podmonitor.yaml -n kafka

```

---

*本研究由 Kafka 專案研究團隊整理與實作。相關設定檔參考 [Strimzi 文檔](https://strimzi.io/docs/operators/latest/full/configuring#type-KafkaSpec-reference)。*