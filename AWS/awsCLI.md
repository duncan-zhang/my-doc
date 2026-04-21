# 🛠 AWS CLI 維運筆記：身分控管與環境配置

## 📂 1. 核心設定檔解析 (`~/.aws/`)

當安裝完 AWS CLI 後，所有的身分控管都圍繞在以下兩個檔案。

### **A. `~/.aws/credentials` (敏感金鑰)**
專門存放存取金鑰，**建議權限設為 `600`** 以防其他使用者讀取。
```ini
[default]
aws_access_key_id = AKIAXXXXXXXXXXXXXXXX
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[duncanchang]
aws_access_key_id = AKIAYYYYYYYYYYYYYYYY
aws_secret_access_key = EXAMPLEKEY/7MDENG/bPxRfiCYwJalrXUtnFEMI
```

### **B. `~/.aws/config` (一般設定)**
存放非敏感資訊，如區域 (Region) 或輸出格式。
```ini
[default]
region = ap-northeast-1
output = json

[profile duncanchang]
region = ap-northeast-1
output = json
```
> 💡 **關鍵差異**：在 `config` 檔中，非預設 Profile 必須加上 **`profile`** 前綴；但在 `credentials` 檔中則直接寫名稱即可。

---

## ⚙️ 2. 初始化與管理指令

除了手動編輯，建議使用官方指令來維護設定：

* **互動式初始化**：引導輸入 Key 並自動寫入檔案。
  ```bash
  aws configure --profile duncanchang
  ```
* **列出所有設定檔**：查看目前電腦存了哪些 Profile。
  ```bash
  aws configure list-profiles
  ```
* **診斷生效來源**：確認目前的設定是來自「環境變數」、「設定檔」還是「IAM 角色」。
  ```bash
  aws configure list --profile duncanchang
  ```

---

## 🚀 3. 多帳號切換與 EKS 實戰

### **A. 環境變數切換 (Session-based)**
在當前終端機視窗生效，避免每個指令都要掛 `--profile`：
```bash
export AWS_PROFILE=duncanchang

# 驗證目前身分是否切換成功
aws sts get-caller-identity 
```

### **B. EKS 常用維運指令**

在執行 `kubectl` 之前，必須先透過 AWS CLI 取得叢集存取權：

```bash
# 1. 檢查目前身分 (確保權限正確)
aws sts get-caller-identity --profile duncanchang

# 2. 列出帳號內所有 EKS 叢集
aws eks list-clusters --profile duncanchang

# 3. 更新 Kubeconfig (將 EKS 連線憑證寫入 ~/.kube/config)
# 這是橋接 AWS IAM 與 Kubernetes 權限的最重要步驟
aws eks update-kubeconfig --region <region-code> --name <cluster-name> --profile duncanchang
aws eks update-kubeconfig --region <region-code> --name <cluster-name> --profile duncanchang --alias <alias-name>
```

---

