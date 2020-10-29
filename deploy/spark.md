# Spark

## 配置

#### spark-env.sh

```
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.222.b03-1.el7.x86_64
export HADOOP_HOME=/home/servers/hadoop-3.1.4
export HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
```

如果这些环境变量已经在系统里配置了，则不用在spark-env.sh里配置。

#### spark-defaults.conf

```
spark.master                     yarn
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://centos01:8020/shared/spark-logs
spark.history.fs.logDirectory    hdfs://centos01:8020/shared/spark-logs
spark.sql.warehouse.dir          hdfs://centos01:8020/user/hive/warehouse
```

#### slaves

```
centos02
centos03
centos04
```

#### 使用hive的metastore：

(1) 把hive的conf/hive-site.xml拷贝到spark的conf目录

(2) 把hive的lib/mysql-connector-java-5.1.49.jar拷贝到spark的jars目录

(3) 修改conf/hive-site.xml，以下参数要与hive的配置区分开：

```
    <property>
        <name>hive.server2.thrift.port</name>
        <value>10003</value>
    </property>
    <property>
        <name>hive.server2.thrift.http.port</name>
        <value>10004</value>
    </property>
    <property>
        <name>hive.server2.webui.host</name>
        <value>centos01</value>
    </property>
    <property>
        <name>hive.server2.webui.port</name>
        <value>10005</value>
    </property>
```

(4) 启动thriftserver：

```
sbin/start-thriftserver.sh
```

#### History Server

在master节点上：

```
sbin/start-history-server.sh
```

