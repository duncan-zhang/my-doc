# Gitlab CI/CD pipeline note

---
## CI CD detached 
- **環境** : Cd

### CI configuration

#### gitlab 
- gitrunner需要enable到group/project中
- 產出group/project access token提供給cd抓`Package registry`使用
  - 最低權限配置: 
    - Role : Reporter
    - Scopes: read_api 可讀取`Package registry`即可
- project -> CI/CD -> Variables 必要變數配置

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
    - |
      curl --header "JOB-TOKEN: $CI_JOB_TOKEN" \
        --upload-file tls-dashboard.tar.gz \
       "http://10.0.101.37/api/v4/projects/$CI_PROJECT_ID/packages/generic/tls-dashboard/$CI_COMMIT_SHA/tls-dashboard.tar.gz"

trigger-cd:
  stage: trigger-cd
  script:
    - apk add --no-cache curl
    - |
      curl --request POST \
        --form "token=glptt-5b15d3faf2182e19dc3c661611a8c735725c8197" \
        --form "ref=main" \
        --form "variables[BUILD_VERSION]=$CI_COMMIT_SHA" \
        --form "variables[SOURCE_PROJECT_ID]=$CI_PROJECT_ID" \
        http://10.0.101.37/api/v4/projects/39/trigger/pipeline
  tags:
    - alpine
```


### CD configuration