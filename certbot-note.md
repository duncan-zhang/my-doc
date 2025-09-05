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
相關指令及說明
```sh
#case1
sudo certbot certonly --nginx --email email@example.com --agree-tos -d www.example.com
#case2
sudo certbot certonly --nginx --register-unsafely-without-email --agree-tos -d www.example.com
```
`certonly` : 只申請憑證，不會自動修改 Nginx/Apache 配置
`--register-unsafely-without-email` : 註冊 ACME 帳號時 不綁定 Email
`--dry-run` : 模擬申請憑證流程