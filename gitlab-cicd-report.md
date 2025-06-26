# Gitlab Detached CI/CD Report

## 1. 測試目標
- **目標**: 將CI(Build、Test)與CD(Deploy)分成不同Group，並讓CI打包後資料能安全、有效地傳遞給CD進行部署。
- **限制條件**: 不經第三方雲端服務(如 S3、GCS、阿里雲等)，也不希望artifacts/variables洩漏或權限交錯。

---

## 2. 測試流程

### 2.1. CI/CD 結構設計
- **CI 專案（Group-A）**：負責程式編譯、打包，並產生 artifacts。
- **CD 專案（Group-B）**：負責從 CI 專案取得 artifacts，執行部署流程。

### 2.2. Pipeline 串接方式
- CI pipeline 完成後，透過 GitLab Trigger API 或 curl 主動觸發 CD pipeline，並帶入關鍵變數（如 commit sha、build version 等）。
- CD pipeline 透過 API 或專案 Access Token，利用 `curl` 指令下載指定 artifacts。

### 2.3. Artifacts 傳遞與佈署
- CI pipeline 中將 build 產物封裝成 artifacts（如 tar.gz、zip）。
- CD pipeline 自動化下載對應 artifacts，並解壓部署至目標伺服器。

---

## 3. 優化建議

### 3.1. 安全性與權限管理
- 建議使用 GitLab Project Access Token 進行跨專案 artifacts 讀取，避免帳號密碼硬編碼。
- 僅給 CD 專案最小必要權限（如 read_api、read_repository）。

### 3.2. 變數傳遞與可維運性
- 觸發 CD pipeline 時，透過 API 傳遞必要的 build 資訊（如 `$CI_PROJECT_ID`, `$CI_COMMIT_SHA`，或自訂版本號）。
- 所有密碼、Token 統一管理於 CI/CD variables，並設為 Masked/Protected。

### 3.3. 錯誤處理與檢查機制
- 在 artifacts 下載/傳遞後，檢查檔案存在性與正確性（如檢查 checksum）。
- 若部署失敗，pipeline 能明確顯示錯誤點，利於回溯。

### 3.4. 可擴展性
- 多個環境、多個 artifacts 可用同一套機制，僅需調整變數與 Token 權限。
- 後續可擴充至多組 CI/CD、跨 project/group，或自動回報 deploy 結果至原 CI。

---

## 4. 實務優化重點

| 項目            | 建議做法                                 |
|-----------------|------------------------------------------|
| Artifacts 傳遞  | 推薦用 GitLab API + Project Access Token  |
| Pipeline 串接   | 用 trigger/cURL，帶明確變數               |
| 檔案驗證        | 傳檔後加 checksum 校驗                    |
| 變數控管        | 全數用 CI/CD Variables，避免硬編碼         |
| 權限安全        | CD pipeline 用專屬 Token，最小權限原則     |
| 目錄與路徑      | 每步驟加 `ls`/`pwd` debug，避免路徑錯誤    |

---

## 5. 補充
- 若日後需支援更大規模、或有多組部署目標，可考慮引入「通用 artifacts 儲存策略」（如 NFS、私有 S3），但基礎架構不變。
- 密碼/Token 統一用 GitLab Secret/Protected 變數，不寫死在 YAML、腳本或 cURL 指令中。

---
