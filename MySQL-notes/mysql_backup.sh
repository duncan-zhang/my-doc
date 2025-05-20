#!/bin/bash

# === 設定區 ===
EXCLUDED_DBS=("information_schema" "performance_schema" "mysql" "sys" "Tertinggi")  # 排除名單
DB_NAMES=("DB1" "DB2" "DB3" "DB4")
DB_BACKUP_DIR="/var/backups/mysql/databases"
LOG_FILE="/var/log/mysql_backup.log"
DATE=$(date +"%Y%m%d_%H%M%S")
SLACK_WEBHOOK_URL="<SLACK_WEBHOOK_URL>"  # 請替換為你實際的 Webhook
SLACK_USER_TAG="<!channel>"

# === 建立備份目錄與 log 檔 ===
mkdir -p "$DB_BACKUP_DIR"
touch "$LOG_FILE"

echo "====  備份開始 $DATE ====" >> "$LOG_FILE"

# === 取得所有資料庫清單，排除不需備份的 ===
ALL_DBS=$(mysql -u admin -N -e "SHOW DATABASES;")
BACKUP_DBS=()

for db in $ALL_DBS; do
    skip=false
    for excluded in "${EXCLUDED_DBS[@]}"; do
        if [ "$db" == "$excluded" ]; then
            skip=true
            break
        fi
    done
    if [ "$skip" = false ]; then
        BACKUP_DBS+=("$db")
    fi
done

# === 備份每個資料庫 ===
for DB_NAME in "${BACKUP_DBS[@]}";do
    SQL_FILE="${DB_NAME}_${DATE}.sql"
    TAR_FILE="${DB_NAME}_${DATE}.tar.gz"

    echo " 備份資料庫：$DB_NAME" >> "$LOG_FILE"
    mysqldump -u admin "$DB_NAME" --no-tablespaces > "$DB_BACKUP_DIR/$SQL_FILE" 2>> "$LOG_FILE"

    if [ $? -eq 0 ]; then
        tar -zcvf "$DB_BACKUP_DIR/$TAR_FILE" -C "$DB_BACKUP_DIR" "$SQL_FILE" >> "$LOG_FILE" 2>&1
        rm -f "$DB_BACKUP_DIR/$SQL_FILE"
        echo "? 成功：$TAR_FILE" >> "$LOG_FILE"
    else
        echo "? 備份失敗：$DB_NAME" >> "$LOG_FILE"
    fi
done

# === 清除超過 30 天的備份檔 ===
find "$DB_BACKUP_DIR" -name "*.tar.gz" -type f -mtime +30 -exec rm -f {} \; -exec echo " 刪除資料庫備份：{}" >> "$LOG_FILE" \;

echo "==== ? 備份完成 $DATE ====" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# === 備份完成後，傳送簡訊通知到 Slack ===
# 擷取本次備份區段
BACKUP_SUMMARY=$(awk "/====  備份開始 $DATE ====/, /==== ? 備份完成 $DATE ====/" "$LOG_FILE")

# 判斷是否有失敗
if echo "$BACKUP_SUMMARY" | grep -q "?"; then
    ALERT_TEXT="?? MySQL 備份失敗：$DATE\n$SLACK_USER_TAG"
else
    ALERT_TEXT="? MySQL 備份成功：$DATE"
fi

# 傳送到 Slack
curl -X POST -H 'Content-type: application/json' \
  --data "{
    \"text\": \"Layerstack-DB備份任務回報\n$ALERT_TEXT\"
  }" \
  "$SLACK_WEBHOOK_URL"