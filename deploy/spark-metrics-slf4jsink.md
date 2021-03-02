# spark metrics slf4jsink验证

## 描述

spark的metrics中包含cpu、memory等指标信息，spark的度量系统支持将metrics导出到多种sink里，例如console、csv、jmx、slf4j等。

本文档是把metrics导出到slf4j，进而通过log4j输出到文件和kafka里。

## 配置

### metrics配置

配置文件：${SPARK_HOME}/conf/metrics.properties

```Java
# Enable Slf4jSink for all instances by class name
*.sink.slf4j.class=org.apache.spark.metrics.sink.Slf4jSink
# Polling period for the Slf4JSink
*.sink.slf4j.period=10
# Unit of the polling period for the Slf4jSink
*.sink.slf4j.unit=seconds
```

### 日志配置

配置文件：${SPARK_HOME}/conf/log4j.properties

```Java
# 自定义appender
log4j.rootCategory=INFO,console,PaicAuditLog,KAFKA

# 日志输出到控制台
log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.Threshold=WARN
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{yy/MM/dd HH:mm:ss} %p [%c] - %m%n

# 日志输出到文件
log4j.appender.PaicAuditLog=org.apache.log4j.RollingFileAppender
log4j.appender.PaicAuditLog.File=/home/servers/spark-2.4.7/logs/Audit/sparkAudit.log
log4j.appender.PaicAuditLog.Threshold=INFO
log4j.appender.PaicAuditLog.Append=true
log4j.appender.PaicAuditLog.MaxFileSize=16MB
log4j.appender.PaicAuditLog.MaxBackupIndex=10
log4j.appender.PaicAuditLog.layout=org.apache.log4j.PatternLayout 
log4j.appender.PaicAuditLog.layout.ConversionPattern=%d{yy/MM/dd HH:mm:ss} %p [%c] - %m%n

# 日志输出到kafka
log4j.appender.KAFKA=org.apache.kafka.log4jappender.KafkaLog4jAppender
log4j.appender.KAFKA.topic=spark-metrics
log4j.appender.KAFKA.brokerList=centos01:9092

```

### kafka appender依赖包

将以下文件拷到目录${SPARK_HOME}/jars里：

```
kafka_2.11-0.10.2.0.jar
kafka-clients-0.10.2.0.jar
kafka-log4j-appender-0.10.2.0.jar
```

## 测试

1.重启thriftserver

2.用beeline执行查询语句

3.在日志文件`/home/servers/spark-2.4.7/logs/Audit/sparkAudit.log`以及kafka topic里可以看到日志输出，其中kafka topic里的metrics信息如下：

```
[root@centos01 kafka_2.12-2.7.0]# bin/kafka-console-consumer.sh --bootstrap-server centos01:9092 --topic spark-metrics
type=GAUGE, name=application_1606911904573_0318.2.NettyBlockTransfer.shuffle-client.usedDirectMemory, value=0
type=GAUGE, name=application_1606911904573_0318.2.NettyBlockTransfer.shuffle-client.usedHeapMemory, value=0
type=GAUGE, name=application_1606911904573_0318.2.NettyBlockTransfer.shuffle-server.usedDirectMemory, value=0
type=GAUGE, name=application_1606911904573_0318.2.NettyBlockTransfer.shuffle-server.usedHeapMemory, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.file.largeRead_ops, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.file.read_bytes, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.file.read_ops, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.file.write_bytes, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.file.write_ops, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.hdfs.largeRead_ops, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.hdfs.read_bytes, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.hdfs.read_ops, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.hdfs.write_bytes, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.filesystem.hdfs.write_ops, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.jvmCpuTime, value=6740000000
type=GAUGE, name=application_1606911904573_0318.2.executor.threadpool.activeTasks, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.threadpool.completeTasks, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.threadpool.currentPool_size, value=0
type=GAUGE, name=application_1606911904573_0318.2.executor.threadpool.maxPool_size, value=2147483647
type=COUNTER, name=application_1606911904573_0318.2.HiveExternalCatalog.fileCacheHits, count=0
type=COUNTER, name=application_1606911904573_0318.2.HiveExternalCatalog.filesDiscovered, count=0
type=COUNTER, name=application_1606911904573_0318.2.HiveExternalCatalog.hiveClientCalls, count=0
type=COUNTER, name=application_1606911904573_0318.2.HiveExternalCatalog.parallelListingJobCount, count=0
type=COUNTER, name=application_1606911904573_0318.2.HiveExternalCatalog.partitionsFetched, count=0
type=COUNTER, name=application_1606911904573_0318.2.executor.bytesRead, count=0
type=COUNTER, name=application_1606911904573_0318.2.executor.bytesWritten, count=0
type=COUNTER, name=application_1606911904573_0318.2.executor.cpuTime, count=0
type=COUNTER, name=application_1606911904573_0318.2.executor.deserializeCpuTime, count=0
type=COUNTER, name=application_1606911904573_0318.2.executor.deserializeTime, count=0
```

