# Self-Managed Gitlab

## Install self-managed Gitlab on Ubuntu
1. 必要套件安裝
```sh
sudo apt update
sudo apt install -y curl openssh-server ca-certificates tzdata perl
```
若須自己發送郵件也可自架，或是使用公用郵件伺服器
```sh
sudo apt install -y postfix
```
2. 添加資料庫及安裝
```sh
 curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
```
安裝**gitlab-ee**
```sh
sudo apt install gitlab-ee
# 配置域名也可後配
sudo EXTERNAL_URL="https://gitlab.example.com" apt install gitlab-ee
# Specifiy version: 
sudo EXTERNAL_URL="https://gitlab.example.com" apt install gitlab-ee=16.2.3-ee.0
```
鎖定版號
```sh
sudo apt-mark hold gitlab-ee
```
3. 配置網頁登入域名(選用)
```sh
sudo vim /etc/gitlab/gitlab.rb
```
- `external_url 'http://<IP or Domain_name>'` 修改連入IP或Domain
重新配置
```sh
sudo gitlab-ctl reconfigure
```

4. 獲取`root passwd`登入網頁
```sh
sudo cat /etc/gitlab/initial_root_password
```
登入網頁

### 常用指令
```sh
sudo gitlab-ctl status
sudo gitlab-ctl restart
sudo gitlab-ctl reconfigure
```

---

## Install Gitlab Runner on Ubuntu
1. 安裝
```sh
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner -y
```
- 指定版號安裝
```sh
sudo apt-cache madison gitlab-runner
sudo apt install gitlab-runner=17.7.1-1 gitlab-runner-helper-images=17.7.1-1
```
- 更新
```sh
sudo apt update
sudo apt install gitlab-runner
```
2. 配置runner
```sh
#交互式配置
sudo gitlab-runner register
#
#Enter the GitLab instance URL (for example, https://gitlab.com/):
#<IP or Domain>
#Enter the registration token:
#<Get from Brower CICD Runner token>
#Enter a description for the runner:
#<defaut_hostname>
#Enter tags for the runner (comma-separated):
#<Skip or input>
#Enter optional maintenance note for the runner:
#<docker>
#Enter the default Docker image (for example, ruby:2.7):
#<ubuntu:lastest>
#Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
#Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml" 
```
3. 簡易測試Runner
新增`.gitlab-ci.yml`
```sh
stages:
  - test
  # tags:
  #   - alpine
test-job:
  stage: test
  script:
    - echo "Runner 正常啟動"
    - echo "目前的時間：$(date)"
    - uname -a
    - whoami
```
## Install Gitlab Runner on docker
1. 建立資料夾及docker-compose.yml
```sh
mkdir -p gitlab-runner
cd gitlab-runner
vim docker-compose.yml
```
2. 撰寫docker-compose.yml
```yaml
version: '3.8'

services:
  gitlab-runner01:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner01
    restart: always
    volumes:
      - ./config/runner01:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
    dns:
      - 8.8.8.8
      - 1.1.1.1
  gitlab-runner02:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner02
    restart: always
    volumes:
      - ./config/runner02:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
    dns:
      - 8.8.8.8
      - 1.1.1.1
```
- `./config/runner0X`: 將`config.toml`便於管理
- `docker.sock`: 可對主機docker進行呼叫

3. 建立gitlab與runner連線
```sh
docker exec -it gitlab-runner01 gitlab-runner register \
  --non-interactive \
  --url "<gitlab_domain>" \
  --registration-token "<gitlab-runner_token>" \
  --executor "docker" \
  --description "runner01" \
  --docker-image "alpine:latest" \
  --tag-list "alpine,runner01"
```
- 權限許可情況下可登入 gitlab WebUI -> priojects -> <your_project> -> settings -> CI/CD -> Runners

4. 修改gitlab-runner的`config.toml`
#### build路徑mount
```sh 
[runners.docker]concurrent = 1
check_interval = 0
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "runner01"
  output_limit = 10000
  url = "<gitlab_domain>"
  id = 1
  token = "<gitlab-runner_token>"
  token_obtained_at = 2025-06-09T06:23:31Z 
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.feature_flags]
    FF_USE_FASTZIP = true #可加速壓縮讀寫
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache/runner01:/cache", "/builds/runner01:/builds"] #cache與builds掛於主機中查閱
    pull_policy = ["if-not-present"] #當本機沒有吻合image時才拉取
    shm_size = 0
    network_mtu = 0
```
- `builds`: 將路徑掛於主機以便排查問題。

#### Docker image pull 優化
```sh
...
[runners.docker]
pull_policy = "if-not-present"
...
```
- `always` :*每次都會強制從 Docker registry（如 Docker Hub）拉取最新的 image，即使本地已經存在
- `if-not-present` : 只有在本地不存在該 image 時才會從遠端拉取（最常用，節省時間與頻寬）
- `never` : 永遠不會從 registry 拉取 image，如果本地沒有會導致錯誤