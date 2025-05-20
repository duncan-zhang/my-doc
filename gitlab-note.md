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
3.配置網頁登入域名(選用)
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

---
### 常用指令
```sh
sudo gitlab-ctl status
sudo gitlab-ctl restart
sudo gitlab-ctl reconfigure
```