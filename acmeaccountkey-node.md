#Acme Account Key 申請流程

## 建立 ACME Account Key 方法
1. 產生金鑰
```sh
openssl genrsa -out account.key 4096
```
2. 產生 EC 金鑰 (P-256)
```sh
openssl ecparam -genkey -name prime256v1 -noout -out account.key
```
3. 確認格式
檔案會是 PEM 格式
```sh
-----BEGIN EC PRIVATE KEY-----
MHcCA...
-----END EC PRIVATE KEY-----
```
4. 把 PEM 轉成 Base64（方便存 JSON / 環境變數)
```sh
base64 -w 0 account.key > account.key.b64
```

## 驗證 ACME Account Key 方法
1. 安裝 acme.sh
```sh
curl https://get.acme.sh | sh
source ~/.bashrc
```
2. 註冊 ACME 帳號
```sh
~/.acme.sh/acme.sh --register-account \
  -m your@email.com \
  --accountkey ./account.key
```
- 用account.key原生金鑰，不需使用Base64版
3. 確認驗證結果  
如果失敗，會看到類似：
```sh
[Wed Aug 27 05:28:00 PM CST 2025] Please refer to https://curl.haxx.se/libcurl/c/libcurl-errors.html for error code: 60
[Wed Aug 27 05:28:00 PM CST 2025] Cannot init API for: https://acme.zerossl.com/v2/DV90.
[Wed Aug 27 05:28:00 PM CST 2025] Sleeping for 10 seconds and retrying.
[Wed Aug 27 05:28:13 PM CST 2025] No EAB credentials found for ZeroSSL, let's obtain them
```
  - 此錯誤表示是因與zerossl驗證產生錯誤，直接改用 Let’s Encrypt（繞過 ZeroSSL）  
  解決方法
```sh
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

~/.acme.sh/acme.sh --register-account \
  -m duncan751122@fiami.com.tw \
  --accountkey ./account.key
```

如果成功，會看到類似：
```sh
[Wed Aug 27 05:29:27 PM CST 2025] Registering account: https://acme-v02.api.letsencrypt.org/directory
[Wed Aug 27 05:29:28 PM CST 2025] Registered
[Wed Aug 27 05:29:28 PM CST 2025] ACCOUNT_THUMBPRINT='K-T5s5zO7GIfMygNXTYKOLUOVHJExOi2m97gM-ApkYo'
```
