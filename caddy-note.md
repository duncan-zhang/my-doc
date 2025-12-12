# Caddy Web Server

## Install Caddy Web Server
[官方安裝](https://caddyserver.com/docs/install)

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
## Caddyfile範本篇

#### Unity專案示範
- `http3`關閉
- url 路徑配置
- 跨域讀取
- 壓縮配置

```sh
{
    grace_period 5s
    shutdown_delay 1s

    # 關閉預設 HTTP/3
    servers :80 {
        protocols h1 h2
    }
    servers :443 {
        protocols h1 h2
    }
}

domain.com {

    encode gzip br

    # 壓縮檔案 MIME
    # 為Unity專案下的壓縮示範
    # 為所有 .js 檔案設置正確的 Content-Type
    header /.js Content-Type application/javascript
    @jsBr path_regexp \.js\.gz$
    header @jsBr Content-Encoding gzip
    header @jsBr Content-Type application/javascript

    # 為 .wasm 檔案設置正確的 Content-Type
    header /.wasm Content-Type application/wasm
    @wasmBr path_regexp \.wasm\.gz$
    header @wasmBr Content-Encoding gzip
    header @wasmBr Content-Type application/wasm

    # 為 .data 檔案設置正確的 Content-Type
    header /.data Content-Type application/octet-stream
    @dataBr path_regexp \.data\.gz$
    header @dataBr Content-Encoding gzip
    header @dataBr Content-Type application/octet-stream

    # CORS 配置
    header Access-Control-Allow-Origin "https://domain.com"
    header Access-Control-Allow-Methods "GET, OPTIONS"
    header Access-Control-Allow-Headers "Content-Type"
    @options method OPTIONS
    respond @options 204

    # API Proxy反向代理
    handle /swagger* {
        reverse_proxy localhost:16888
    }
    handle /WeatherForecast/* {
        reverse_proxy localhost:16888
    }
    handle /api/* {
        reverse_proxy localhost:16888
    }
    handle /ws {
        reverse_proxy localhost:16888
    }

    #強導`/web02`->`/web02/`
    redir /web02 /web02/

    # web02
    @web02 path /web02/*
    handle @web02 {
        #去掉前綴域名
        uri strip_prefix /web02
        root * /var/www/web02
        try_files {path} /index.html
        file_server
    }


    # 預設主頁
    handle  {
        root * /var/www/web01/
        try_files {path} /index.html
        file_server
    }
        
    handle_errors {
        header -Via
        respond "" {http.error.status_code}
    }
}

domain2.com {
    root * /var/www/Addressable

    file_server

    #CORS 限制：只允許 domain.com 載入
    header Access-Control-Allow-Origin "https://domain.com"
    header Access-Control-Allow-Methods "GET, OPTIONS"
    header Access-Control-Allow-Headers "Content-Type"

    @options method OPTIONS
    respond @options 204

    encode gzip br

    handle_errors {
        respond "{http.error.status_code}" {http.error.status_code}
    }
}
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

## Caddy Log

## 套件transform-encoder

[transform-encoder github](https://github.com/caddyserver/transform-encoder/tree/master)

transform-encoder 是 Caddy 的一個外掛，用來：

- 修改 log 輸出格式
- 將原本的 Caddy 日誌，轉換成自訂文字格式
- 可以輸出 JSON / key-value / 任意你想要的格式
- 特別適合 Filebeat + ELK

| 優點                      | 說明                        |
| ----------------------- | ------------------------- |
| ✔ 可自訂輸出格式               | 你想變成 JSON / key-value 都可以 |
| ✔ 避免 Caddy 預設 log 雜亂的格式 | 原生格式難以解析                  |
| ✔ 適合 Filebeat dissect   | 字串穩定 → dissect 能完美拆解      |
| ✔ 性能比 JSON encoder 還快   | 不用生成完整 JSON 結構            |


### 1. 安裝 transform-encoder

transform-encoder 並非官方內建模組，需要使用 Caddy Builder 建置自訂版本：

```sh
xcaddy build \
    --with github.com/caddyserver/transform-encoder
```

### 2. transform-encoder 範例（實作版本）

Caddyfile — transform encoder 自訂 Log 格式

```sh

(log_format) {
	log {
		output file /var/log/caddy/access.log {
			roll_size 100MiB
			roll_keep 10
			roll_keep_for 168h
			roll_local_time
		}

		format transform `"time_local":"{ts}","remote_addr":"{request>remote_ip}","request_method":"{request>method}","uri":"{request>uri}","server_protocol":"{request>proto}","status":"{status}","request_time":"{duration}","http_referer":"{request>headers>Referer>[0]}","http_user_agent":"{request>headers>User-Agent>[0]}","args":"{request>uri_query}","domain":"{request>host}","body_bytes_sent":"{size}","upstream_addr":"{request>headers>X-Forwarded-For>[0]}","upstream_status":"{status}","upstream_response_time":"{latency}"` {
			time_format "02/Jan/2006:15:04:05 -0700"
		}
	}
}
```

- time_format : 需轉換，標準go寫法。

transform encoder 會輸出 單行 JSON-like 格式（不是真 JSON，但非常適合filebeat的dissect）：

```sh
"time_local":"11/Dec/2025:08:20:30 +0000","remote_addr":"1.1.1.1","request_method":"GET","uri":"/api/Game1001/BetOption","server_protocol":"HTTP/2.0","status":"401","request_time":"0.014","http_referer":"https://test.xxx.com/game.html",...
```

### 3. Filebeat dissect 拆欄位（關鍵）

設定如下：

```sh
processors:
  - dissect:
      field: "message"
      target_prefix: ""
      tokenizer: '"time_local":"%{time_local}","remote_addr":"%{remote_addr}","request_method":"%{request_method}","uri":"%{uri}","server_protocol":"%{server_protocol}","status":"%{status}","request_time":"%{request_time}","http_referer":"%{http_referer}","http_user_agent":"%{http_user_agent}","args":"%{args}","domain":"%{domain}","body_bytes_sent":"%{body_bytes_sent}","upstream_addr":"%{upstream_addr}","upstream_status":"%{upstream_status}","upstream_response_time":"%{upstream_response_time}"'
```

這會把 Log 拆成獨立欄位，例如：

```sh
time_local: 11/Dec/2025:08:20:30 +0000
remote_addr: 118.163.193.223
status: 401
uri: /api/Game1001/BetOption
body_bytes_sent: 0
...
```

### 結合ELK架構

```text
Caddy (transform encoder)
      ↓
Filebeat (dissect)
      ↓
ElasticSearch
      ↓
Kibana Dashboard
```

