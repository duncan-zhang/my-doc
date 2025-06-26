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
       "http://10.0.101.37/api/v4/projects/$CI_PROJECT_ID/packages/generic/tls-dashboard/$CI_COMMIT_SHA/tls-dashboard.tar.gz"

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
        http://10.0.101.37/api/v4/projects/<CD_project_ID>/trigger/pipeline
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
        http://10.0.101.37/api/v4/projects/<CD_project_ID>/trigger/pipeline
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
      "http://10.0.101.37/api/v4/projects/$SOURCE_PROJECT_ID/packages/generic/tls-dashboard/$BUILD_VERSION/tls-dashboard.tar.gz" \
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
         http://10.0.101.37/api/v4/projects/<CD_project_ID>/trigger/pipeline
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
│   └── cert-checker.tmp
```