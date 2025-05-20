# DB備份機制說明

## mysql備份機制說明
執行檔案位置 `/var/backups/mysql/mysql_backup.sh`
1. 針對複數個資料庫逐一備份
2. 資料將存於`/var/backups/mysql/databases`中
3. 檔案命名`${DB_NAME}_${DATE}.tar.gz`
4. 執行logs查閱`/var/log/mysql_backup.log`
5. 執行成功or失敗皆會通知於slack頻道中

## Azure Blob上傳機制說明
執行檔案位置 `/var/backups/mysql/azcopy_upload.sh`
1. 同步資料為`/var/backups/mysql/databases`內所有檔案 
2. 執行logs查閱`/var/log/azcopy_mysql_backup.log`
3. 執行成功or失敗皆會通知於slack頻道中

## Azure Blob安裝及基本操作

### 安裝說明
```sh
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azcopy
```
### 基本指令操作
[azcopy 官方文件](https://learn.microsoft.com/zh-tw/azure/storage/common/storage-use-azcopy-v10?tabs=dnf)

基本資料
- storage name: backupkg444ge5
- container name: dbbackup

Azure Login
```sh
azcopy login #登入azure帳戶

azcopy login --tenant-id "[TenantID]" #組織域名方式登入
INFO: Authentication is required. To sign in, open the webpage https://microsoft.com/devicelogin and enter the code HRPBBN2LB to authenticate.
#使用瀏覽器登入https://microsoft.com/devicelogin輸入code

azcopy login status
INFO: You have successfully refreshed your token. Your login session is still active
#登入成功

azcopy logout
```
Azure list檔案查看
```sh
azcopy list 'https://<storage name>.blob.core.windows.net/"
```

Azure copy檔案複製
```sh
azcopy copy '<檔案路徑>' "https://<storage name>.blob.core.windows.net/<container name>/<folder name>"
```

Azure sync同步檔案
```sh
azcopy sync '<檔案路徑>' "https://<storage name>.blob.core.windows.net/<container name>/<folder name>"

azcopy sync '<檔案路徑>' "https://<storage name>.blob.core.windows.net/<container name>/<folder name> --delete-destination=true"
```
- `--delete-destination=true`鏡像備份

#### Azure SAS(共用存取簽章)

啟用簽章
`Azure網頁 -> 儲存體帳戶(storage name) -> 安全性+網路 -> 共用存取簽章`
開通權限
- 允許的資源類型: 容器、物件
- 開始及到期日/時間: 自訂
- 允許的 IP 位址: IP_list

點擊`產生SAS 與連接字串`

#### 透過SAS Token上傳
```sh
azcopy sync '<檔案路徑>' "https://<storage name>.blob.core.windows.net/<container name>/<folder name>?<SAS_Token> --delete-destination=true"
```
