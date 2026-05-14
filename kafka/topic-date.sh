#!/bin/bash

# 設定參數
TOPIC="test-topic"
NAMESPACE="kafka"
BROKER_POD="kafka-broker-0" # 根據之前的排查，這是你的 Pod 名字

echo "開始定期打資料到 $TOPIC... (按 Ctrl+C 停止)"

while true; do
  # 產生一筆包含時間戳記的資料
  DATA="{\"message\": \"Test Data\", \"timestamp\": \"$(date +'%Y-%m-%d %H:%M:%S')\"}"
  
  # 透過管道將資料送入 Pod 內的生產者
  echo "$DATA" | kubectl exec -i $BROKER_POD -n $NAMESPACE -- \
    bin/kafka-console-producer.sh \
    --bootstrap-server localhost:9092 \
    --topic $TOPIC
  
  echo "已送出: $DATA"
  
  # 每隔 1 秒打一筆
  sleep 1
done