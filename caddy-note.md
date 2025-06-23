# Caddy Web Server

## 安裝Install
[官方安裝說明](https://caddyserver.com/docs/install)

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf '<https://dl.cloudsmith.io/public/caddy/stable/gpg.key>' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf '<https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt>' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy -y
```

## 基本指令

檢查config

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

自動格式校正

```bash
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
```

模組清單

```bash
sudo caddy list-modules
```

服務重啟

```bash
sudo systemctl restart caddy
```

---
## 套件安裝篇

### 前置作業

1. 安裝Go
    
    ```bash
    sudo apt update
    sudo apt install -y golang
    ```
    
2. 安裝 `xcaddy` 
    
    ```bash
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    ```
    
3. 執行檔位置 `xcaddy` → ./go/bin/xcaddy
4. (選用) 套件執行
    
    請執行以下指令來臨時加上（適用 Bash）
    
    ```bash
    export PATH=$PATH:$HOME/go/bin
    ```
    
    若要永久生效，可將上述加到你的 ~/.bashrc 或 ~/.profile 中：
    
    ```bash
    echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
    source ~/.bashrc
    ```
    
5. 檢查確認
    
    ```bash
    #go套件安裝後
    cd go/bin
    ./xcaddy version
    #有執行第4步
    xcaddy version
    
    ```
    

### 編譯套件

1. 切換進`xcaddy`目錄
    
    ```bash
    cd go/bin
    #確認是否有執行檔 xcaddy
    ```
    
2. 編譯套件
    
    ```bash
    ./xcaddy build --with github.com/ueffel/caddy-brotli \
     --with github.com/corazawaf/coraza-caddy/v2 \
     --with github.com/mholt/caddy-ratelimit
    ```
    
3. 編譯後結果
    
    確認資料夾中是否有`caddy`
    
4. 下載owasp
    
    ```bash
    sudo git clone https://github.com/coreruleset/coreruleset.git /etc/caddy/coreruleset
    ```
    
    ```bash
    # 確認關鍵檔案存在
    ls -1 /etc/caddy/coreruleset/crs-setup.conf.example
    ls -1 /etc/caddy/coreruleset/rules/*.conf | head -5
    ```
    
5. 資料搬移到執行中
    
    ```bash
    sudo mv caddy /usr/bin/
    ```
    
6. 確認套件是否有安裝完成
    
    ```bash
    caddy list-modules |grep -E 'waf|br|rate'
    ```
    
7. 完成

### 套件驗證

1. 先編寫入配置檔 `/etc/caddy/Caddyfile` 
    
    ```bash
    :80 {
    	# Set this path to your site's directory.
    	root * /usr/share/caddy
      
      # waf安裝
    	route {
    		coraza_waf {
    			load_owasp_crs
    			directives `
    			Include /etc/caddy/coreruleset/crs-setup.conf.example
    			Include /etc/caddy/coreruleset/rules/*.conf
    			SecRuleEngine On
    			`
    		}
        
        #Enable rate_limit  10s訪問超過5次 
    		rate_limit {
    			zone ip_zone {
    				key {remote_host}
    				window 10s
    				events 5
    			}
    		}
    		
        #Enable brotli 
    		encode br
    		
    		# Enable the static file server.
    		file_server
    	}
    
    ```
    
2. 驗證服務後重啟
    
    ```bash
    sudo caddy validate --config /etc/caddy/Caddyfile
    sudo systemctl restart caddy
    ```
    
3. 驗證waf
    
    ```bash
    curl -i "http://localhost/?test_param=<script>alert(1)</script>"
    curl -i "http://localhost/?id=1+UNION+SELECT+1,2,3"
    curl -i "http://localhost/?exec=/bin/bash"
    
    #返回結果為 HTTP/1.1 403 Forbidden 成功啟用waf
    ```
    
4. 驗證brotli
    
    ```bash
    curl -H "Accept-Encoding: br" -I http://localhost/
    #Content-Encoding: br -> 啟用返回結果
    ```
    
5. 驗證rate_limit
    
    ```bash
    for i in {1..10}; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost/; done
    
    #預期輸出前面幾個是 200，後面就會開始出現 429 Too Many Requests
    ```
    
6. 完成

#### Rate_limit

##### ✅ 正確寫法範例（新版語法）

```
rate_limit {
    zone ip_zone {
        key {remote_host}
        window 10s
        events 5
    }
}
```

##### 🔑 說明：

- `ip_zone` 是這個限速區的名字（你可以隨便取）
- `key {remote_host}` 代表用「來源 IP」作為辨識 key（即每個 IP 分開計算）
- `window 10s`：時間視窗 10 秒
- `events 5`：最多 5 次請求

##### **Caddy-Maxmind-Geolocation**

編譯套件

```bash
./xcaddy build --with github.com/porech/caddy-maxmind-geolocation
```

Caddyfile 

`vim /etc/caddy/Caddyfile`

```bash
:8080 {
	@allow_tw {
		maxmind_geolocation {
			db_path /etc/caddy/GeoLite2-Country.mmdb
			allow_countries TW #允許TW連入
		}
	}

	handle @allow_tw {
		header X-Debug-Country {geoip.country_code}
		header X-Debug-Result "ALLOWED: TW"
		respond "Hello Taiwan!" 200
	}

	handle {
		header X-Debug-Country {geoip.country_code}
		header X-Debug-Result "DENIED: NON-TW"
		respond "Access denied (only TW allowed)" 403
	}
}
```

驗證方式

```bash
curl -i -H "X-Real-IP: 61.219.100.10" http://localhost:8080 #模擬TW_IP訪問
```