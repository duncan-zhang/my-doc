# Certbot Note

## Install Certbot on Ubuntu

**Nginx 伺服器**
```sh
sudo apt update -y
sudo apt install certbot python3-certbot-nginx -y
```
**Nginx 安裝**
(略)

**DNS 指向**
(略)

## 申請方式
相關指令
```sh
sudo certbot certonly --nginx --email email@example.com --agree-tos -d www.example.com
```

