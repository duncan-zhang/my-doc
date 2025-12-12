# ELK Notes

## Elastic

自建index紀錄

```sh
curl -u "user:passwd" \
  -X POST "http://elastic_ip:9200/index_name/_doc?pretty" \
  -H "Content-Type: application/json" \
  -d @<(cat <<EOF
{
  "@timestamp": "$(date --iso-8601=seconds)",
  "time_local": "$(date +'%d/%b/%Y:%H:%M:%S %z')",

  "remote_addr": "8.8.8.8",
  "request_method": "GET",
  "uri": "/api/test",
  "status": "200",
  "request_time": "0.012",
  "upstream_status": "200",
  "message": "test message from EOF"
}
EOF
)
```

- "-u" : 輸入帳密
- "index_name" : 填入模擬的index

## Logstash

## Kibana

## Filebeat

### 檢測方式

🔍 1. 修改 filebeat.yml 之後第一件事就是跑：

```sh
sudo filebeat test config -e
```

作用：
- 檢查語法是否正確
- 檢查 processors 配置
- 檢查 YAML 格式錯誤
- 檢查引用錯誤（像 processors 寫錯鍵名）

如果 OK：

```sh
Config OK
```

如果錯誤（例如你遇到的 tokenizer 問題）會印出：

```sh
unexpected option ... 
cannot override existing key ...
could not find delimiter ...
```

🔎 2. 檢查 Filebeat 連到 Elasticsearch 是否正常

```sh
sudo filebeat test output
```

正常會看到：

```sh
複製程式碼
elasticsearch: http://localhost:9200...
Established connection to Elasticsearch
```

如果憑證或帳密錯誤會看到：

```sh
複製程式碼
Error dialing...
authentication required...
```

🐛 3. 啟動 Filebeat Debug 模式

必須先systemctl stop filebeat才能執行

```sh
sudo filebeat -e -d "publish,processors"
```

建議最常用：

```sh
sudo filebeat -e -d "processors"
```

debug mode 可查看到異常問題原因。

