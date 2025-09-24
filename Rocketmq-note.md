# Rocketmq 建置說明

## 環境設置

1. 確認預設 `Java 8`

```sh
#已安裝可略
sudo apt install openjdk-8-jdk -y

java -version
#確認本機Java版本套件
sudo update-java-alternatives -l
#切換Default Java version
sudo update-java-alternatives -s java-1.8.0-openjdk-amd64
```

2.服務檔案配置

執行檔傳入伺服器中

```sh
#將rocketmq-all-4.7.0-bin-release.zip與rocketmq-console-ng-1.0.1.jar傳入本機
mkdir rocketmq
mv rocketmq-all-4.7.0-bin-release.zip rocketmq-console-ng-1.0.1.jar rocketmq
cd rocketmq/
unzip rocketmq-all-4.7.0-bin-release.zip
```

配置`rocketmq/rocketmq-all-4.7.0-bin-release/conf/broker.conf`

```sh
...

brokerClusterName = DefaultCluster
brokerName = broker-a
brokerId = 0
namesrvAddr = 10.0.5.6:9876
brokerIP1 = 10.0.5.6
deleteWhen = 04
fileReservedTime = 48
brokerRole = ASYNC_MASTER
flushDiskType = ASYNC_FLUSH

sendMessageThreadPoolNums=64
useReentrantLockWhenPutMessage=true

```

3.配置環境變數

```sh
export ROCKETMQ_HOME=/home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release
echo $ROCKETMQ_HOME
```

## 服務執行

下列三個服務皆須可執行

0.建立`log folder`

```sh
mkdir -p /home/fiamiadmin/logs/rocketmqlogs
```

1.mqnamesrv

```sh
nohup sh $ROCKETMQ_HOME/bin/mqnamesrv \
  > /home/fiamiadmin/logs/rocketmqlogs/mqnamesrv.console 2>&1 &
```

2.mqbroker.console

```sh
nohup sh $ROCKETMQ_HOME/bin/mqbroker -n 10.0.5.6:9876 -c $ROCKETMQ_HOME/conf/broker.conf \
  > /home/fiamiadmin/logs/rocketmqlogs/mqbroker.console 2>&1 &
```

3.rocketmq-console

```sh
nohup java -jar \
-Drocketmq.config.namesrvAddr=localhost:9876 \
-Drocketmq.config.isVIPChannel=false \
/home/fiamiadmin/rocketmq/rocketmq-console-ng-1.0.1.jar \
> /home/fiamiadmin/logs/rocketmqlogs/console.console 2>&1 &
```

4.檢查服務

```sh
sudo ps aux |grep rocketmq
sudo netstat -tulp
```

5.停止服務

```sh
sh $ROCKETMQ_HOME/bin/mqshutdown namesrv
sh $ROCKETMQ_HOME/bin/mqshutdown broker

#查詢rocketmq-console-ng PID
ps aux |grep Rocketmq
kill <PID>
```

## 配置systemd(可選)

1.建立`sudo vim /etc/systemd/system/rocketmq-namesrv.service`

```sh
[Unit]
Description=RocketMQ NameServer
After=network.target

[Service]
Type=simple
User=fiamiadmin
WorkingDirectory=/home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release
Environment=ROCKETMQ_HOME=/home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release
Environment="JAVA_OPT_EXT=-server -Xms2g -Xmx2g -Xmn1g -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m -XX:+UseConcMarkSweepGC -XX:+UseCMSCompactAtFullCollection -XX:CMSInitiatingOccupancyFraction=70 -XX:+CMSParallelRemarkEnabled -XX:SoftRefLRUPolicyMSPerMB=0 -XX:+CMSClassUnloadingEnabled -XX:SurvivorRatio=8 -XX:-UseParNewGC -verbose:gc -Xloggc:/dev/shm/rmq_srv_gc_%%p_%%t.log -XX:+PrintGCDetails -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=30m -XX:-OmitStackTraceInFastThrow -XX:-UseLargePages"
ExecStart=/home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release/bin/mqnamesrv
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

2.建立`sudo vim /etc/systemd/system/rocketmq-broker.service`

```sh
[Unit]
Description=RocketMQ Broker
After=network.target rocketmq-namesrv.service
Requires=rocketmq-namesrv.service

[Service]
Type=simple
User=fiamiadmin
WorkingDirectory=/home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release
Environment=ROCKETMQ_HOME=/home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release
Environment="JAVA_OPT_EXT=-server -Xms2g -Xmx2g -Xmn1g -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m -XX:+UseG1GC -XX:G1HeapRegionSize=16m -XX:G1ReservePercent=25 -XX:InitiatingHeapOccupancyPercent=30 -XX:SoftRefLRUPolicyMSPerMB=0 -verbose:gc -Xloggc:/dev/shm/rmq_broker_gc_%%p_%%t.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -XX:+PrintAdaptiveSizePolicy -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=30m -XX:-OmitStackTraceInFastThrow -XX:+AlwaysPreTouch -XX:MaxDirectMemorySize=15g -XX:-UseLargePages -XX:-UseBiasedLocking"
ExecStart=/home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release/bin/mqbroker -n 10.0.5.6:9876 -c /home/fiamiadmin/rocketmq/rocketmq-all-4.7.0-bin-release/conf/broker.conf
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

3.建立`sudo cat /etc/systemd/system/rocketmq-console.service`

```sh
[Unit]
Description=RocketMQ Console
After=network.target rocketmq-namesrv.service
Requires=rocketmq-namesrv.service

[Service]
Type=simple
User=fiamiadmin
WorkingDirectory=/home/fiamiadmin
ExecStart=/usr/bin/java -jar -Drocketmq.config.namesrvAddr=localhost:9876 -Drocketmq.config.isVIPChannel=false /home/fiamiadmin/rocketmq/rocketmq-console-ng-1.0.1.jar
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

4.服務執行

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now rocketmq-namesrv
sudo systemctl enable --now rocketmq-broker
sudo systemctl enable --now rocketmq-console

sudo systemctl status rocketmq-namesrv rocketmq-broker rocketmq-console
sudo netstat -tulp
```
