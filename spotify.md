# Spotify install on Ubuntu

## 官方Gitub
[spotifyd](https://github.com/Spotifyd/spotifyd)

## Spotifyd 安裝指令詳解
```sh
sudo apt update

# 安裝 PulseAudio 動態連結庫（spotifyd 需要 libpulse）
sudo apt install libpulse0
# 下載 spotifyd 最新版（這裡以 v0.4.1 為例）
wget https://github.com/Spotifyd/spotifyd/releases/download/v0.4.1/spotifyd-linux-x86_64-full.tar.gz

tar -zxvf spotifyd-linux-x86_64-full.tar.gz

sudo chmod +x spotifyd

# 將 spotifyd 移到 /usr/local/bin/（系統全域執行路徑）
sudo mv spotifyd /usr/local/bin/

# 驗證 spotifyd 是否安裝成功（會顯示版本號即為安裝成功）
spotifyd --version
```

## 建立設定檔
```sh
mkdir -p ~/.config/spotifyd
vim .config/spotifyd/spotifyd.conf
```
內容範例：
```ini
[global]
username = "你的Spotify帳號"
password = "你的Spotify密碼"
device_name = "ubuntu_cli_spotify"
backend = "alsa"  # ← Linux原生音效架構
device = "default" # ← ALSA音效輸出裝置名稱
volume_controller = "softvol"
no_audio_cache = true # ← 不在本地快取音樂檔
use_mpris = false
```
啟動Spotifyd:
```sh
spotifyd --no-daemon
```

## 設定成 systemd 服務
建立 `sudo /etc/systemd/system/spotifyd.service`:
```sh
[Unit]
Description=Spotifyd
After=network.target

[Service]
User=sysadmin   # ←改成你登入的帳號
ExecStart=/usr/local/bin/spotifyd --no-daemon
Restart=always

[Install]
WantedBy=default.target
```
啟動與設定開機自動：
```sh
sudo systemctl daemon-reload
sudo systemctl enable spotifyd
sudo systemctl start spotifyd
sudo systemctl status spotifyd
```

## 藍芽連線設定
```sh
# 進入藍芽連線設定
bluetoothctl

# [bluetoothctl] mode
# 掃描裝置
scan on
# 配對 連線 信任
pair AC:B1:EE:25:D4:7E
connect AC:B1:EE:25:D4:7E
trust AC:B1:EE:25:D4:7E
# 移除
remove AC:B1:EE:25:D4:7E
# 資訊確認
info AC:B1:EE:25:D4:7E