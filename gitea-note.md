# Gitea 安裝筆記

## 前置安裝

### 1.Docker
安裝(略)

### 2.Database
1. 安裝
```sh
sudo apt install mysql-server -y
sudo mysql
sudo sed -i 's/^bind-address\s*=\s*127\.0\.0\.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql.service
```
```sh
ALTER USER 'root'@'localhost' IDENTIFIED BY 'my_password';
FLUSH PRIVILEGES;
exit
```
2. 本地數據庫
```sh
CREATE USER 'gitea' IDENTIFIED BY 'gitea';
CREATE DATABASE giteadb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_bin';
GRANT ALL PRIVILEGES ON giteadb.* TO 'gitea'@'%';
FLUSH PRIVILEGES;
```

## Gitea 安裝
gitea下載
```sh
wget -O gitea https://dl.gitea.com/gitea/1.23.7/gitea-1.23.7-linux-amd64
chmod +x gitea
```
準備環境  
檢查是否安裝git。需Git version >= 2.0。
```sh
git --version
```
建立用戶
```sh# On Ubuntu/Debian:
sudo adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Git Version Control' \
   --group \
   --disabled-password \
   --home /home/git \
   git
 ```
建立工作路徑
```sh
sudo mkdir -p /var/lib/gitea/{custom,data,log}
sudo chown -R git:git /var/lib/gitea/
sudo chmod -R 750 /var/lib/gitea/
sudo mkdir /etc/gitea
sudo chown root:git /etc/gitea
sudo chmod 770 /etc/gitea
```
配置Gitea文件到全局模式
```sh
export GITEA_WORK_DIR=/var/lib/gitea/
sudo mv gitea /usr/local/bin/gitea
```
添加bash自動補全
```sh 
wget https://raw.githubusercontent.com/go-gitea/gitea/main/contrib/autocompletion/bash_autocomplete
sudo mv bash_autocomplete /usr/share/bash-completion/completions/gitea
```
配置systemd
```sh
sudo vim /etc/systemd/system/gitea.service
```
Gitea.service context
```sh
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target
###
# Don't forget to add the database service dependencies
###
#
#Wants=mysql.service
#After=mysql.service
#
#Wants=mariadb.service
#After=mariadb.service
#
#Wants=postgresql.service
#After=postgresql.service
#
#Wants=memcached.service
#After=memcached.service
#
#Wants=redis.service
#After=redis.service
#
###
# If using socket activation for main http/s
###
#
#After=gitea.main.socket
#Requires=gitea.main.socket
#
###
# (You can also provide gitea an http fallback and/or ssh socket too)
#
# An example of /etc/systemd/system/gitea.main.socket
###
##
## [Unit]
## Description=Gitea Web Socket
## PartOf=gitea.service
##
## [Socket]
## Service=gitea.service
## ListenStream=<some_port>
## NoDelay=true
##
## [Install]
## WantedBy=sockets.target
##
###

[Service]
# Uncomment the next line if you have repos with lots of files and get a HTTP 500 error because of that
# LimitNOFILE=524288:524288
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
# If using Unix socket: tells systemd to create the /run/gitea folder, which will contain the gitea.sock file
# (manually creating /run/gitea doesn't work, because it would not persist across reboots)
#RuntimeDirectory=gitea
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea
# If you install Git to directory prefix other than default PATH (which happens
# for example if you install other versions of Git side-to-side with
# distribution version), uncomment below line and add that prefix to PATH
# Don't forget to place git-lfs binary on the PATH below if you want to enable
# Git LFS support
#Environment=PATH=/path/to/git/bin:/bin:/sbin:/usr/bin:/usr/sbin
# If you want to bind Gitea to a port below 1024, uncomment
# the two values below, or use socket activation to pass Gitea its ports as above
###
#CapabilityBoundingSet=CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_BIND_SERVICE
###
# In some cases, when using CapabilityBoundingSet and AmbientCapabilities option, you may want to
# set the following value to false to allow capabilities to be applied on gitea process. The following
# value if set to true sandboxes gitea service and prevent any processes from running with privileges
# in the host user namespace.
###
#PrivateUsers=false
###

[Install]
WantedBy=multi-user.target
```
啟用服務&&自動啟用
```sh
sudo systemctl enable gitea && sudo systemctl start gitea
```

## Git act_runner安裝

[官方下載頁面](https://gitea.com/gitea/act_runner/releases)  
[代碼倉庫](https://gitea.com/gitea/act_runner)  

切換成root  
`目前使用root問題比較少`
```sh
sudo -i
```

軟體下載
```sh
wget -O act_runner  https://gitea.com/gitea/act_runner/releases/download/v0.2.11/act_runner-0.2.11-linux-amd64
chmod +x act_runner
./act_runner --version
#act_runner version v0.2.11
```
全域配置
```sh
mv act_runner /usr/local/bin/
act_runner --version
```
設定檔配置config.yaml
1. 產出原生配置檔
```sh
sudo mkdir /etc/act_runner
act_runner generate-config > /etc/act_runner/config.yaml
```
2. 修改配置檔
`非互動式配置`
```sh 
act_runner register \
  --no-interactive \
  --instance http://127.0.0.1:3000 \
  --token <token_id> \
  --name <your_name> \
  --config /etc/act_runner/config.yaml
```
3. 將`.runner`配置
```sh
#檢查是否有.runner
sudo ls -al 
sudo mkdir /var/lib/act_runner
sudo mv .runner /var/lib/act_runner
```

使用Systemd啟動act_runner
1. 建置systemd.service
```sh
sudo vim /etc/systemd/system/act_runner.service
```
2. systemd context
```sh
[Unit]
Description=Gitea Actions runner
Documentation=https://gitea.com/gitea/act_runner
After=docker.service

[Service]
ExecStart=/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml
ExecReload=/bin/kill -s HUP $MAINPID
WorkingDirectory=/var/lib/act_runner
TimeoutSec=0
RestartSec=10
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```
加載新的 systemd 單元文件
```sh
sudo systemctl daemon-reload
```
3. 啟用服務&&自動啟用
```sh
sudo systemctl enable act_runner && sudo systemctl start act_runner 
```
```sh
sudo systemctl status act_runner 
```