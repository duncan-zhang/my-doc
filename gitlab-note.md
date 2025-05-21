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
cat /etc/gitlab/initial_root_password
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
#Enter the GitLab instance URL (for example, https://gitlab.com/):<IP or Domain>
#Enter the registration token:<Get from Brower CICD Runner token>
#Enter a description for the runner:<Runner_Name>
#Enter optional maintenance note for the runner:<docker>
#Enter the default Docker image (for example, ruby:2.7):<ubuntu:lastest>
#
#Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
#Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml" 
```
3. 簡易測試Runner
新增`.gitlab-ci.yml`
```sh
stages:
  - test
  
test-job:
  stage: test
  script:
    - echo "Runner 正常啟動"
    - echo "目前的時間：$(date)"
    - uname -a
    - whoami
```