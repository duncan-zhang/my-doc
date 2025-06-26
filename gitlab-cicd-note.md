# Gitlab CI/CD pipeline note

### CI configuration

#### gitlab 
- gitrunner需要enable到group/project中
- 產出group/project access token提供給cd抓`Package registry`使用
  - 最低權限配置: 
    - Role : Reporter
    - Scopes: read_api 可讀取`Package registry`即可
- project &rarr; CI/CD &rarr; Variables 必要變數配置

#### .gitlab-ci.yml
```yml
stages:
  - build
  - trigger-cd

build_job:
  stage: build
  tags:
    - alpine
  image: node:18
  script:
    - cd node_app
    - date
    - node -v
    - node get_cert_info.js
    - cd ..
    - tar czvf tls-dashboard.tar.gz web_service/
  artifacts:
    name: "tls-dashboard"
    paths:
      - web_service/
  after_script:
    # 打包後資料上傳到gitlab -> deploy -> Package registry
    # 相關參數模型如下，基本上無須變動
    - |
      curl --header "JOB-TOKEN: $CI_JOB_TOKEN" \
        --upload-file tls-dashboard.tar.gz \
       "http://<gitlab-domain>/api/v4/projects/$CI_PROJECT_ID/packages/generic/tls-dashboard/$CI_COMMIT_SHA/tls-dashboard.tar.gz"

trigger-cd:
  stage: trigger-cd
  script:
    - apk add --no-cache curl
    #透過variables把變數從CI帶到CD
    - |
      curl --request POST \
        --form "token=<pipeline trigger tokens>" \
        --form "ref=main" \
        --form "variables[BUILD_VERSION]=$CI_COMMIT_SHA" \
        --form "variables[SOURCE_PROJECT_ID]=$CI_PROJECT_ID" \
        http://<gitlab-domain>/api/v4/projects/<CD_project_ID>/trigger/pipeline
  tags:
    - alpine
```
**build_job** : 
 - `$CI_JOB_TOKEN`: gitlab的預設job參數
 - `$CI_COMMIT_SHA`: commit的雜湊號碼
 - `ref=<branch>`: 指 CD 端的分支
**trigger-cd** :  
 - `pipeline trigger tokens` : 由 CD 提供此token
 - `CD_project_ID` : 需確認 CD 專案 ID 號碼

#### 額外補充 CI 執行呼叫特定 CD deploy.yml
```yml
...
trigger-cd:
  stage: trigger-cd
  script:
    - apk add --no-cache curl
    #透過variables把變數從CI帶到CD
    - |
      curl --request POST \
        --form "token=<pipeline trigger tokens>" \
        --form "ref=main" \
        --form "variables[DEPLOY_TARGET]=A" \
        http://<gitlab-domain>/api/v4/projects/<CD_project_ID>/trigger/pipeline
  tags:
    - alpine
```
- `form "variables[DEPLOY_TARGET]=A` : 帶入變數相關變數可由 CD 的 rule 判斷該執行對應deploy.yml(參考下方CD)


### CD configuration

### 單一 CI 管理 單一 CD 版本

#### gitlab 
- gitrunner需要enable到group/project中
- project &rarr; CI/CD &rarr; Pipeline trigger tokens 建立token提供給 CI 端
- project &rarr; CI/CD &rarr; Variables 必要變數配置

#### .gitlab-ci.yml
```yml
default:
  tags:
    - alpine

stages:
  - deploy

deploy_job:
  stage: deploy
  script:
    - apk add --no-cache curl file
    # echo 變數是否有從 CI 帶入到 CD
    - echo "BUILD_VERSION = $BUILD_VERSION"
    - echo "SOURCE_PROJECT_ID = $SOURCE_PROJECT_ID"
    - |
      curl --header "PRIVATE-TOKEN: $ci_proj_token" \
      "http://<gitlab-domain>/api/v4/projects/$SOURCE_PROJECT_ID/packages/generic/tls-dashboard/$BUILD_VERSION/tls-dashboard.tar.gz" \
      -o tls-dashboard.tar.gz
      tar xzvf tls-dashboard.tar.gz
    - ls -lh tls-dashboard.tar.gz
    - file tls-dashboard.tar.gz
    - tar xzvf tls-dashboard.tar.gz  
```
**deploy_job** :
- `$BUILD_VERSION` : 由 CI 帶入的 `$CI_COMMIT_SHA` commit雜湊碼
- `$SOURCE_PROJECT_ID` : 由 CI 帶入的 `$CI_PROJECT_ID` 專案 ID
**Comment**
- `$CI_JOB_TOKEN`: 每個專案是獨有的JOB TOKEN，CI並非指這專案是CI或CD，完全是預設名稱。
---

### 多數 CI 管理 單一 CD 版本

#### gitlab 
- gitrunner需要enable到group/project中
- project &rarr; CI/CD &rarr; Pipeline trigger tokens 建立token提供給 CI 端
- project &rarr; CI/CD &rarr; Variables 必要變數配置

#### 資料架構及說明
**正確資料結構**
```sh
cd/
├── deploy/
│   ├── .gitkeep
│   ├── deploy-A.yml
│   ├── deploy-B.yml
│   └── deploy-C.yml
├── .gitlab-ci.yml
└── README.md
```
~~錯誤資料結構~~
```sh
cd/
├── deploy-A.yml
├── deploy-B.yml
├── deploy-C.yml
├── .gitlab-ci.yml
└── README.md
```
1. 若要達成透過`.gitlab-ci.yml`去執行deploy中的yml，目前已知必須透過建立資料夾的方式去執行才能成功指定yml
2. 當把deploy的yml放在同一層資料中，會出現`bug`，結果會是A、B無法執行，僅C是可以執行的
3. 是如何驗證出bug呢?
   - 將deploy-A、B、C三份文件合併成一份`.gitlab-ci.yml`時，執行是可正常指定ABC的
   - 可用curl直接對CD的API呼叫
     ```yml
           curl --request POST \
         --form "token=<pipeline trigger tokens>" \
         --form "ref=main" \
         --form "variables[DEPLOY_TARGET]=A" \
         http://<gitlab-domain>/api/v4/projects/<CD_project_ID>/trigger/pipeline
     ```

#### .gitlab-ci.yml
```yml
include:
  - local: 'deploy/deploy-A.yml'
  - local: 'deploy/deploy-B.yml'
  - local: 'deploy/deploy-C.yml'
```
#### deploy-A.yml
```yml
stages:
  - deploy
deploy-job:
  stage: deploy
  script:
    - echo "deploy-A.yml"
  tags:
    - alpine
  rules:
    - if: '$DEPLOY_TARGET == "A"'
```
- B、C.yml照抄改參數即可

---
## 重要資訊

### gitrunner相關

#### 1. 專案架構下的限制
當gitlab呼叫啟動gitlab-runner執行作業時，會從group往project建立資料夾，在runner在docker環境中可以切換目錄(cd)最終也只能在container中切換。
因此當跨group時，是無法直接透過資料夾的切換去取得另一group中相關資料。

`資料結構圖`
``` sh
#container中
.
├── cd
│   ├── cert-check-cd
│   └── cert-check-cd.tmp
├── ci
│   ├── cert-checker
└── └── cert-checker.tmp
```

#### 2. CD API呼叫的限制方式

##### .gitlab-ci.yml
```yml
workflow:
  rules:
    - if: '$CI_PIPELINE_SOURCE == "trigger" || $CI_PIPELINE_SOURCE == "api"'
      when: always
    - when: never

include:
  - local: 'deploy/deploy-A.yml'
  - local: 'deploy/deploy-B.yml'
```
- `$CI_PIPELINE_SOURCE` : API呼叫來源種類

**其它可用的 pipeline 來源參數**
| 來源                | 變數值                 |
| ------------------- | --------------------- |
| push                | push                  |
| merge request event | merge_request_event   |
| trigger             | trigger               |
| schedule            | schedule              |
| web                 | web                   |
| api                 | api                   |
| external            | external              |
| pipeline            | pipeline              |
| parent_pipeline     | parent_pipeline       |
| chat                | chat                  |

#### 3. 關於 CI 後打包結果該如何讓 CD 抓到資料
基於gitlab安全政策的關係，跨Group是無法直接獲取打包後資料，解法如下:
1. 用 GitLab Package Registry 傳遞 artifacts(gitlab原生方案)
  - 優點:
    - ✅ 原生支援：GitLab 內建、跨 group 專案都可用
    - ✅ 權限細緻：用 project access token 控管存取
    - ✅ 版本控管：支援多版本、多檔案、API 易用
    - ✅ 不佔用 repo 歷史：不會讓 git repo 膨脹
    - ✅ 自動清理：可設保留天數/數量
  - 缺點:
    - ⚠️ 需 API 操作：需手動寫 curl 或腳本（但容易自動化）
    - ⚠️ 需管理 token：需要有存取權限的 token，管理稍麻煩
    - ⚠️ 社群版有流量/容量限制（企業版可調整）
2. SCP/S3/FTP 共享資料夾 作為 artifacts 中繼站
  - 優點:
    - ✅ 彈性高：不限於 GitLab，檔案、路徑都自訂
    - ✅ 適合大檔案/多環境：有現成檔案伺服器或 NAS 可直接用
    - ✅ 可獨立管理存取權限
  - 缺點:
    - ⚠️ 需維護額外主機或服務（運維成本）
    - ⚠️ 安全控管自行負責（權限、加密、認證）
    - ⚠️ SCP/SSH 易受帳號權限、網路、互信設定影響 
    - ⚠️ CI/CD yaml 必須嵌入密碼/token，管理需謹慎
3. docker環境下在CI打包後，scp/rsync2傳送到主機層
  - 優點:
    - ✅ 不用預先設定 volume，只要主機開 ssh/scp 即可
    - ✅ 靈活：可同時傳給多台主機、分多環境
    - ✅ 權限明確分離（host 檔案由 ssh 控制）
    - ✅ 適合多 runner/多主機場景
  - 缺點:
    - ⚠️ 效能較低（走網路層傳輸，雖然本機會很快，但還是多了一層 overhead）
    - ⚠️ 密碼/金鑰管理要小心（要存進 CI/CD secrets，建議用金鑰優於帳密）
    - ⚠️ 防火牆/SSH 設定須允許本地登入
    - ⚠️ 容易遇到權限問題（如資料夾歸屬、寫入權限）

