# Windows Server + IIS + MSSQL

## 維運與系統管理整理文件

網站網址:
https://ccrab.rcec.sinica.edu.tw/

## 一、系統基本資訊（System Overview）

### 1. 系統架構
- 作業系統：Windows Server 2019 Standard
- Web Server：IIS（ASP.NET Core 6 Hosting）
- 應用程式：ASP.NET Core 6
- 程式語言：C# / HTML5 / JavaScript
- 資料庫：Microsoft SQL Server 2019
- 系統型態：
  - 單機式架構
  - 非 High Availability（無 Load Balancer / Failover）

### 2. 系統資料流（Request Flow）
```csharp
[Client]
    │  HTTP/HTTPS
    ▼
[IIS]  ← 反向代理、SSL、Rewrite、安全
    │  透過 AspNetCoreModuleV2
    ▼
[Kestrel]  ← 真正執行你的 ASP.NET Core 程式
    │
    ▼
[Your App Code]（Controllers, Middlewares）
    │
    ▼
[IIS 回傳 Response] → Client
```

---

## 二、系統安裝與建置順序（標準建議）

### 建議安裝流程

1. ✔ Windows 更新 + .NET Framework 4.8
2. ✔ 安裝 IIS + Role Services
3. ✔ 安裝 SQL Server 2019（含 SSMS）
4. ✔ 安裝 URL Rewrite
5. ✔ 安裝 ASP.NET Core Hosting Bundle 6.0
6. ✔ 部署你的 ASP.NET Core 6 Web API / Web App
7. ✔ 設定 HTTPS Binding（憑證）
8. ✔ 設定 App Pool（No Managed Code）
9. ✔ 開啟日誌、壓縮、Request Filtering 安全條件

---

## 三、IIS Role Services 建議設定

1️⃣ Common HTTP Features
| 項目                 | 建議    | 說明       |
| ------------------ | ----- | -------- |
| Default Document   | ✔     | 必備       |
| Static Content     | ✔     | 必備       |
| HTTP Errors        | ✔     | 錯誤頁      |
| Directory Browsing | ❌     | 避免目錄暴露   |
| HTTP Redirection   | ✔（選用） | 80 → 443 |
| WebDAV             | ❌     | 禁用，安全風險  |

2️⃣ Health and Diagnostics
| 項目              | 建議      |
| --------------- | ------- |
| HTTP Logging    | ✔ 必備    |
| Request Monitor | ✔ 建議    |
| Tracing         | ❌（除錯才用） |

3️⃣ Performance
| 項目                  | 建議 |
| ------------------- | -- |
| Static Compression  | ✔  |
| Dynamic Compression | ✔  |

4️⃣ Security
| 項目                   | 建議        |
| -------------------- | --------- |
| Request Filtering    | ✔ 必備      |
| Windows / Basic Auth | ❌（未使用 AD） |
| IP Restrictions      | 視需求       |

5️⃣ Application Development（關鍵）
| 項目                         | 建議 |
| -------------------------- | -- |
| .NET Extensibility 4.x     | ✔  |
| ASP.NET 4.x                | ✔  |
| ISAPI Extensions / Filters | ✔  |
| CGI / ASP                  | ❌  |

6️⃣ Management Tools
| 項目                     | 建議               |
| ---------------------- | ---------------- |
| IIS Management Console | ✔                |
| IIS Management Scripts | ✔                |
| Management Service     | ✔（Web Deploy 需求） |

---

## 四、ASP.NET Core 6 Hosting

[Net Code 6 Hosting Bundle](https://dotnet.microsoft.com/zh-tw/download/dotnet/6.0)

安裝
  - 安裝 ASP.NET Core 6 Hosting Bundle
  - 安裝後必須執行
    ```sh
    iisreset
    ```

驗證
```sh
dotnet --list-runtimes
```

需看到：
  - Microsoft.AspNetCore.App 6.x
  - Microsoft.NETCore.App 6.x

IIS Modules 中需存在：
  ```sh
  AspNetCoreModuleV2
  ```

---

## 五、MSSQL Server 2019 維運重點

### SQL Server 安裝設定
  - 安裝模式：Custom（Evaluation）
  - Features：
    - ✔ Database Engine Services
    - ✔ Full-Text Search
  - Instance：
    - Default Instance：MSSQLSERVER
  - Authentication：
    - Mixed Mode
    - Administrator 為 SQL Admin

### SQL Server 安裝後必做事項（重要）
1. 啟用 TCP/IP（供應用程式連線）
2. 安裝 SSMS
3. 測試：
  - Windows Authentication
  - sa 登入（Mixed Mode）

## 六、資料庫備份與還原機制

### 備份設定
- 方式：SQL Server Maintenance Plan
- 頻率：每日 12:00
- 保留時間：3 個月
- 位置：
  ```sh
  D:\Database_Auto\
  ```

### 還原流程（重點）
1. 開啟 SSMS
2. Restore Database
3. 選擇最新 .bak
  - 不需要事先建立 DB 或 Tables
4. 確認 DB 狀態為 Online

⚠️ .bak 內已包含：
- DB 結構
- Tables / Data
- Index / Schema

---

## 七、Web 站台備份(無)
- 目前方式：人工壓縮備份
- 路徑：
  ```sh
  D:\WebsiteBackup\
  ```
⚠️ 尚未規劃自動排程備份

---

## 八、日誌與監控

### Log 來源
- 系統事件：Windows Event Viewer
- 網站存取：IIS W3C Access Log

### 監控方式
- Windows Resource Monitor
- Windows Performance Monitor
⚠️ 無外部監控、告警、SLA

---

## 九、故障識別（Incident Handling）

### HTTP 狀態碼判斷
| 狀態碼 | 意義                    |
| --- | ------------------------ |
| 200 | 正常                      |
| 400 | Client Request 錯誤       |
| 404 | 資源不存在                 |
| 500 | Server發生未知或無法處理的錯誤 |
| 502 | Gateway / Backend 回應異常 |

---

## 十、交接與注意事項
- SSL 憑證：
  - GTLSCA
  - 到期時間：約明年 3 月
- 系統具備管理後台（需控管權限）

---

## 十一、維運補充建議（強烈）

以下項目為原始文件未涵蓋，但在**實際維運、交接、稽核與災害復原**中屬於高度必要，建議納入正式維運文件或 Runbook。

---

### ⬜ Web 站台自動備份（排程）

**目的**  
避免人為遺漏，確保 Web 程式碼、設定檔可回溯。

**建議作法**
- 以排程方式每日或每週自動備份：
  - IIS 站台實體目錄
  - `web.config` / `appsettings.json`
- 備份方式：
  - PowerShell Script + Task Scheduler
  - 或搭配 Web Deploy
- 建議至少保留：
  - 7～30 天版本

---

### ⬜ DB 還原演練紀錄

**目的**  
確保備份檔「真的可用」，避免災難發生時才發現無法還原。

**建議作法**
- 定期（每季或半年）進行：
  - `.bak` 還原測試
- 紀錄內容：
  - 演練日期
  - 使用備份檔名稱
  - 還原耗時
  - 是否成功
  - 問題與改善事項

---

### ⬜ 監控告警（CPU / RAM / Disk / IIS / SQL）

**目的**  
在服務中斷前即發現異常，降低 MTTR。

**建議監控項目**
- 系統層：
  - CPU 使用率
  - 記憶體使用率
  - 磁碟剩餘空間
- 服務層：
  - IIS Worker Process
  - SQL Server Service
  - HTTP Response Code（500 / 502）

**建議工具**
- Windows Performance Monitor（基礎）
- 第三方監控（如 Zabbix、Prometheus、Uptime Kuma）

---

### ⬜ SSL 憑證到期提醒

**目的**  
避免因憑證過期造成服務中斷。

**建議作法**
- 建立到期清冊：
  - 憑證類型（GTLSCA）
  - 憑證用途
  - 到期日
- 提前提醒：
  - 30 天 / 14 天 / 7 天
- 可搭配：
  - 行事曆提醒
  - 監控系統檢查憑證有效期限

---

### ⬜ 帳號與權限稽核

**目的**  
降低資安風險，符合稽核要求。

**建議盤點項目**
- Windows 系統帳號
- IIS App Pool Identity
- SQL Server Login / DB User
- 管理後台帳號

**建議作法**
- 定期檢查：
  - 是否有離職人員帳號
  - 是否有過度權限（如 sa）
- 建立：
  - 帳號清冊
  - 權限變更紀錄

---

### ⬜ RTO / RPO 定義

**目的**  
讓單位與維運人員對「可接受中斷程度」有共識。

**建議定義**
- **RTO（Recovery Time Objective）**
  - 服務中斷後，最長可接受復原時間
- **RPO（Recovery Point Objective）**
  - 最多可接受資料遺失時間

**範例**
- RTO：4 小時
- RPO：24 小時（每日備份）

---

### ⬜ Runbook（500 / 502 / DB 連線失敗）

**目的**  
降低人員經驗差異，縮短排障時間。

**建議至少包含**
- HTTP 500
  - 檢查 IIS / Event Viewer / App Log
- HTTP 502
  - 檢查 IIS ↔ Kestrel / App Pool 狀態
- DB 連線失敗
  - SQL Service 是否啟動
  - Connection String
  - Login 權限

**Runbook 建議格式**
- 現象
- 可能原因
- 檢查步驟
- 修復方式
- 是否需升級通報

---

> 📌 建議將以上項目納入：
> - 維運手冊  
> - 交接文件  
> - 災害復原計畫（DR Plan）  
> - 資安 / 稽核附件
