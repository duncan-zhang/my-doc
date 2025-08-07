# 🌐 OpenVPN 安裝與設定指南（Ubuntu）

## 📚 目錄

- [安裝 OpenVPN](#安裝-openvpn)
- [互動式安裝流程說明](#互動式安裝流程說明)
- [安裝完成後操作](#安裝完成後操作)
- [基本操作與服務管理](#基本操作與服務管理)
- [伺服器設定檔 server.conf 範例](#伺服器設定檔-serverconf-範例)
- [新增／查詢／刪除用戶](#新增查詢刪除用戶)
- [指定用戶內網 IP](#指定用戶內網-ip)
- [補充：openvpn vs openvpn@server](#補充openvpn-vs-openvpnserver)
- [（可選）建立指定路由配置](#可選建立指定路由配置)

---

## 🛠️ 安裝 OpenVPN

使用 [angristan/openvpn-install](https://github.com/angristan/openvpn-install)

### 安裝指令

```sh
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh 
sudo ./openvpn-install.sh 
```
#### 🔧 互動式安裝流程說明
基本設定
```sh
I need to ask you a few questions before starting the setup.
You can leave the default options and just press enter if you are okay with them.

I need to know the IPv4 address of the network interface you want OpenVPN listening to.
Unless your server is behind NAT, it should be your public IPv4 address.
IP address: www.mycompany.com #輸入外網IP or Domain
Your host does not appear to have IPv6 connectivity.

Do you want to enable IPv6 support (NAT)? [y/n]: n #是否要支援IPv6

What port do you want OpenVPN to listen to?
   1) Default: 1194
   2) Custom
   3) Random [49152-65535]
Port choice [1-3]: 1 #是否要修改服務端口

What protocol do you want OpenVPN to use?
UDP is faster. Unless it is not available, you shouldn't use TCP.
   1) UDP
   2) TCP
Protocol [1-2]: 1 #協議選擇

What DNS resolvers do you want to use with the VPN?
   1) Current system resolvers (from /etc/resolv.conf)
   2) Self-hosted DNS Resolver (Unbound)
   3) Cloudflare (Anycast: worldwide)
   4) Quad9 (Anycast: worldwide)
   5) Quad9 uncensored (Anycast: worldwide)
   6) FDN (France)
   7) DNS.WATCH (Germany)
   8) OpenDNS (Anycast: worldwide)
   9) Google (Anycast: worldwide)
   10) Yandex Basic (Russia)
   11) AdGuard DNS (Anycast: worldwide)
   12) NextDNS (Anycast: worldwide)
   13) Custom
DNS [1-12]: 9 #DNS選擇

Do you want to use compression? It is not recommended since the VORACLE attack makes use of it.
Enable compression? [y/n]: n #是否進行壓縮 建議是不壓縮較安全

Do you want to customize encryption settings?
Unless you know what you're doing, you should stick with the default parameters provided by the script.
Note that whatever you choose, all the choices presented in the script are safe (unlike OpenVPN's defaults).
See https://github.com/angristan/openvpn-install#security-and-encryption to learn more.

Customize encryption settings? [y/n]: n #預設選n

Okay, that was all I needed. We are ready to setup your OpenVPN server now.
You will be able to generate a client at the end of the installation.
Press any key to continue...

(略)...
```
建立 VPN 用戶
```sh
Tell me a name for the client.
The name must consist of alphanumeric character. It may also include an underscore or a dash.
Client name: duncan-home #vpn client name

Do you want to protect the configuration file with a password?
(e.g. encrypt the private key with a password)
   1) Add a passwordless client
   2) Use a password for the client
Select an option [1-2]: 1 #建議選1即可

```
- ✅ 安裝完成後會生成 client_name.ovpn，可匯入至 OpenVPN 客戶端使用

#### 🌍 安裝完成後操作
⚠️ 請務必設定 防火牆 DNAT / port-forwarding，確保用戶能從外網連入 VPN。

## 📡 基本操作與服務管理

#### 查看 OpenVPN 服務狀態
```sh
sudo systemctl status openvpn@service
```

#### 編輯伺服器設定
```sh
sudo vim /etc/openvpn/server.conf
```
#### 🧾 伺服器設定檔 server.conf 範例
```sh
port 1194
proto udp
dev tun
user nobody
group nogroup
persist-key
persist-tun
keepalive 10 120
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "redirect-gateway def1 bypass-dhcp"
dh none
ecdh-curve prime256v1
tls-crypt tls-crypt.key
crl-verify crl.pem
ca ca.crt
cert server_tfuF86j6HNqVEGD5.crt
key server_tfuF86j6HNqVEGD5.key
auth SHA256
cipher AES-128-GCM
ncp-ciphers AES-128-GCM
tls-server
tls-version-min 1.2
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256
client-config-dir /etc/openvpn/ccd
```
- ✏️ `server 10.8.0.0 255.255.255.0`：VPN 內網範圍
- ✏️ `client-config-dir`：進階用戶自定 IP、路由等配置放置處

#### 👥 新增／查詢／刪除用戶
重新執行安裝指令即可進入管理介面：
```sh
sudo ./openvpn-install.sh 
```
```sh
Welcome to OpenVPN-install!
The git repository is available at: https://github.com/angristan/openvpn-install

It looks like OpenVPN is already installed.

What do you want to do?
   1) Add a new user
   2) Revoke existing user
   3) Remove OpenVPN
   4) Exit

```
- `1.Add a new user` : 新增用戶，可創建多用戶
- `2.Revoke existing user` : 選2可察看目前已創建用戶，並再選擇刪除用戶
   - 或是透過 `ls /etc/openvpn/easy-rsa/pki/issued/`查看憑證數量

#### 🔢 指定用戶內網 IP
1. 建立用戶對應設定檔
```sh 
sudo vim /etc/openvpn/ccd/duncan-home
```
2. 在檔案中加入以下設定
```sh
ifconfig-push 10.8.0.100 255.255.255.0
```
3. 
```sh
sudo systemctl restart openvpn@server
```
補充：openvpn vs openvpn@server
| 名稱 | 解釋 | 適用情境 |
| --- | --- | --- |
| `openvpn@server` | ✅ **Systemd 的服務單元（unit）**，表示啟動 `/etc/openvpn/server/server.conf` 的 OpenVPN 伺服器實例 | **Ubuntu 18.04 以後的版本使用 systemd 的標準做法** |
| `openvpn` | ✅ 是 **可執行檔案 binary**，通常位於 `/usr/sbin/openvpn`，是用來手動執行 OpenVPN 的指令 | **用來直接從命令列啟動某個設定檔，例如 openvpn --config xxx.conf** |

#### 建立指定路由配置(未驗證)
##### 🔧 實作建議（使用者等級部署）
假設你在一台主機上，擁有多個 public IP，例如：
- eth0: 203.0.113.10
- eth0:0: 203.0.113.11
- eth0:1: 203.0.113.12

1. 為用戶設靜態 VPN IP（同前面步驟）
| VPN User | VPN IP    | 對外 NAT IP  |
| -------- | --------- | ------------ |
| alice    | 10.8.0.10 | 203.0.113.10 |
| bob      | 10.8.0.20 | 203.0.113.11 |
| charlie  | 10.8.0.30 | 203.0.113.12 |

2. iptables + SNAT 設定 NAT 對外 IP
```sh
# Alice：VPN IP 為 10.8.0.10，對外 NAT 成 203.0.113.10
iptables -t nat -A POSTROUTING -s 10.8.0.10 -o eth0 -j SNAT --to-source 203.0.113.10

# Bob：VPN IP 為 10.8.0.20，對外 NAT 成 203.0.113.11
iptables -t nat -A POSTROUTING -s 10.8.0.20 -o eth0 -j SNAT --to-source 203.0.113.11

# Charlie：VPN IP 為 10.8.0.30，對外 NAT 成 203.0.113.12
iptables -t nat -A POSTROUTING -s 10.8.0.30 -o eth0 -j SNAT --to-source 203.0.113.12
```

3. 儲存規則
```sh
sudo iptables-save > /etc/iptables/rules.v4
```
- 若有使用 netfilter-persistent 套件會自動套用

🔐 搭配 CCD 管理靜態 IP
```sh
/etc/openvpn/ccd/alice
→ ifconfig-push 10.8.0.10 255.255.255.0

/etc/openvpn/ccd/bob
→ ifconfig-push 10.8.0.20 255.255.255.0

/etc/openvpn/ccd/charlie
→ ifconfig-push 10.8.0.30 255.255.255.0
```
⚠️ 注意事項
1. OpenVPN 記得開啟 IP forwarding：
   ```sh
   echo 1 > /proc/sys/net/ipv4/ip_forward
   ```
2. 確保這些 public IP 已被綁定在你的網卡上，否則 SNAT 後無法正常對外通訊。
3. 檢查 VPS 或防火牆商是否允許多 public IP 同時出站。