# ☸️ Kubernetes 連線配置與工具筆記 (`~/.kube/`)

## 📂 1. 目錄結構與檔案功能
在 Mac/Linux 環境下，`~/.kube/` 是控制中心，管理所有叢集接入點。

| 檔案/目錄 | 角色 | 詳細說明 |
| :--- | :--- | :--- |
| **`config`** | **核心設定** | 存放所有叢集的 API 地址、憑證與連線身分（Contexts）。 |
| **`cache/`** | **資源快取** | 暫存叢集 API 資源清單（如 Pod/Service 的定義），加速指令反應。 |
| **`kubectx`** | **狀態紀錄** | 專供 `kubectx` 工具使用，紀錄「上一次」與「當前」的叢集名稱。 |

---

## 🛠 2. 建立連線：AWS EKS 橋接邏輯
連線到 EKS 的關鍵在於透過 AWS CLI 將 **雲端憑證** 寫入本地 **Kubeconfig**。

### **A. 建立連線並指定別名 (Alias)**
為了避免 ARN 名稱（包含帳號 ID 與長字串）造成混淆，建議在更新時直接指定別名。

```bash
aws eks update-kubeconfig \
  --region <region-code> \
  --name <cluster-name> \
  --profile duncanchang \
  --alias <簡短別名，如 dev-eks>
```

### **B. 運作原理 (Under the Hood)**
1. **認證切換**：`config` 檔案會紀錄 `exec` 指令，連線時自動呼叫 `aws cli` 使用 `duncanchang` Profile 獲取臨時 Token。
2. **通訊憑證**：從 AWS 抓取該叢集的 **Endpoint** (API 網址) 與 **CA 憑證** 並填入 `~/.kube/config`。

---

## 🚀 3. Context 管理與切換技巧

### **A. kubectl 原生指令 (手動管理)**
| 功能 | 指令 |
| :--- | :--- |
| **查看所有連線** | `kubectl config get-contexts` |
| **確認目前叢集** | `kubectl config current-context` |
| **手動重新命名** | `kubectl config rename-context <舊名稱> <新名稱>` |

### **B. kubectx 工具 (高效維運)**
`kubectx` 是 `~/.kube/config` 的**前端 UI 切換器**，操作效率最高。

| 功能 | 實戰指令 |
| :--- | :--- |
| **快速列出叢集** | `kubectx` |
| **切換指定叢集** | `kubectx <name>` |
| **回到上一個叢集** | `kubectx -` |
| **建立/修改別名** | `kubectx <alias>=<origin_arn_name>` |
| **顯示目前選定** | `kubectx -c` |

> **範例**：`kubectx duncan-cluster=arn:aws:eks:ap-east-2:471486728480:cluster/freshman-duncan`

---
