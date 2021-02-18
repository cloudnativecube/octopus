# kafka

## zookeeper

由于kafka依赖zookeeper，所以先启动zookeeper（简单起见，只启动一个实例）：

```
[root@centos01 zookeeper-3.6.2]# pwd
/home/servers/zookeeper-3.6.2
[root@centos01 zookeeper-3.6.2]# bin/zkServer.sh --config conf start
ZooKeeper JMX enabled by default
Using config: conf/zoo.cfg
Starting zookeeper ... already running as process 4933.
```

## kafka

### 部署

简单起见，只部署一个kafka server实例。

启动服务：

```
[root@centos01 kafka_2.12-2.7.0]# pwd
/home/servers/kafka_2.12-2.7.0
// 以daemon方式启动
[root@centos01 kafka_2.12-2.7.0]# bin/kafka-server-start.sh -daemon config/server.properties
// 检查进程
[root@centos01 kafka_2.12-2.7.0]# jps
15905 Kafka
// 检查日志
[root@centos01 kafka_2.12-2.7.0]# tail -f logs/server.log
```

创建topic：

```
[root@centos01 kafka_2.12-2.7.0]# bin/kafka-topics.sh --bootstrap-server centos01:9092 --create --topic spark-metrics
Created topic spark-metrics.
```

打开一个终端，消费message：

```
[root@centos01 kafka_2.12-2.7.0]# bin/kafka-console-consumer.sh --bootstrap-server centos01:9092 --topic spark-metrics
```

打开另一个终端，生产message：

```
[root@centos01 kafka_2.12-2.7.0]# bin/kafka-console-producer.sh --bootstrap-server centos01:9092 --topic spark-metrics
>12345
```

输入“12345”，然后在consumer端可以看到有消息输出。

### 常用命令

bin目录下有很多脚本，常用的有以下这些。

- 查看所有topic

```
# bin/kafka-topics.sh --bootstrap-server centos01:9092 --list
```

- 创建topic

```
# bin/kafka-topics.sh --bootstrap-server centos01:9092 --create --topic spark-metrics
```

- 查看topic详情

```
# bin/kafka-topics.sh --bootstrap-server centos01:9092 --describe --topic spark-metrics
  Topic: spark-metrics	PartitionCount: 1	ReplicationFactor: 1	Configs: segment.bytes=1073741824
	Topic: spark-metrics	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
```

