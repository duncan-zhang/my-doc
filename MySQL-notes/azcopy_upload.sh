#!/bin/bash

# === 設定區 ===
DATE=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/var/log/azcopy_mysql_backup.log"
DB_SRC="/var/backups/mysql/databases/"
SAS_TOKEN="SAS_TOKEN"
DB_DST="https://<container>.blob.core.windows.net/<folder>?$SAS_TOKEN"
SLACK_WEBHOOK_URL="<SLACK_WEBHOOK_URL>"
SLACK_USER_TAG="<!channel>"

# === 建立 Log 檔案 ===
touch "$LOG_FILE"
echo "==== [$DATE] Azure 備份開始 ====" >> "$LOG_FILE"

# === 備份資料庫檔案 ===
echo " 備份資料庫檔案..." >> "$LOG_FILE"
azcopy copy "$DB_SRC" "$DB_DST" --recursive --overwrite=false >> "$LOG_FILE" 2>&1
AZ_RESULT_DB=$?
if [ $AZ_RESULT_DB -eq 0 ]; then
    echo "✅ 資料庫備份上傳成功" >> "$LOG_FILE"
else
    echo "❌ 資料庫備份上傳失敗" >> "$LOG_FILE"
fi

echo "==== [$DATE] Azure 備份結束 ====" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# === 判斷備份整體狀態 ===
if [ $AZ_RESULT_DB -eq 0 ] ; then
    BACKUP_STATUS="✅ Azcopy Upload 成功：$DATE"
else
    BACKUP_STATUS="❌ Azcopy Upload 失敗：$DATE\n$SLACK_USER_TAG"
fi

# === 傳送至 Slack（簡單通知） ===
curl -X POST -H 'Content-type: application/json' \
  --data "{
    \"text\": \"Azcopy同步任務回報\n$BACKUP_STATUS\"
  }" \
  "$SLACK_WEBHOOK_URL"
