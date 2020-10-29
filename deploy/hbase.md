# Hbase-2.2.6 安装与环境简介

##### 下载与编译hbase源码

```
hadoop> wget https://apache.mirror.colo-serv.net/hbase/2.2.6/hbase-2.2.6-src.tar.gz
hadoop> tar xvf hbase-2.2.6-src.tar.gz
hadoop> cd hbase-2.2.6
hadoop> mvn -Dhadoop.profile=3.0 -Dhadoop-three.version=3.1.4 -DskipTests clean install  && mvn -Dhadoop.profile=3.0 -Dhadoop-three.version=3.1.4 -DskipTests package assembly:single
hadoop> cd hbase-assembly/target/
hadoop> tar xvf hbase-2.2.6-bin.tar.gz -C /home/servers/hbase-2.2.6
```
##### 安装Zookeeper
```
hadoop> wget https://apache.claz.org/zookeeper/zookeeper-3.6.2/apache-zookeeper-3.6.2-bin.tar.gz
hadoop> tar xvf apache-zookeeper-3.6.2-bin.tar.gz -C /home/servers/
hadoop> mv /home/servers/apache-zookeeper-3.6.2 /home/servers/zookeeper-3.6.2
hadoop> cd /home/servers/zookeeper-3.6.2/conf

hadoop> vim zoo.cfg

# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just
# example sakes.
dataDir=/home/servers/zookeeper-3.6.2/data
# the port at which the clients will connect
clientPort=2181
# the maximum number of client connections.
# increase this if you need to handle more clients
#maxClientCnxns=60
#
# Be sure to read the maintenance section of the
# administrator guide before turning on autopurge.
#
# http://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir
#autopurge.snapRetainCount=3
# Purge task interval in hours
# Set to "0" to disable auto purge feature
#autopurge.purgeInterval=1

4lw.commands.whitelist=mntr,conf,ruok

## Metrics Providers
#
# https://prometheus.io Metrics Exporter
#metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider
#metricsProvider.httpPort=7000
#metricsProvider.exportJvmInfo=true
server.1=centos01:2888:3888
server.2=centos02:2888:3888
server.3=centos03:2888:3888

hadoop> vim ~/.bashrc
export ZK_HOME=/home/servers/zookeeper-3.6.2
export PATH=$PATH:$ZK_HOME/bin
hadoop> source ~/.bashrc
hadoop> zkServer.sh start //三个节点均执行
```

##### 配置

hbase-site.xml

```
<property>
    <name>hbase.rootdir</name>
    <value>hdfs://centos01:8020/hbase</value>
</property>
<property>
    <name>hbase.cluster.distributed</name> // 分布式部署
    <value>true</value>
</property>
<property>
    <name>hbase.zookeeper.quorum</name>
    <value>centos01,centos02,centos03</value>
</property>
```

vim ~/.bashrc

```
export HBASE_HOME=/home/servers/hbase-2.2.6
export PATH=$PATH:$HBASE_HOME/bin
hadoop> source ~/.bashrc
```

regionservers

```
centos02
centos03
centos04
```
back-masters
```
centos02
```

hbase-env.sh

```
export HBASE_MANAGES_ZK=false // 不启动hbase自身带的zookeeper
export HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP=true // 让hbase不去加载hadoop的lib
```

##### 启动hbase
```
hadoop> start-hbase.sh
```
##### 测试
```
hbase shell
hbase(main):001:0> create 'test', 'cf'
hbase(main):001:0> list 'test'
hbase(main):001:0> describe 'test'
hbase(main):001:0> put 'test', 'row1', 'cf:a', 'value1'
hbase(main):001:0> put 'test', 'row2', 'cf:b', 'value2'
hbase(main):001:0> put 'test', 'row3', 'cf:b', 'value3'
hbase(main):001:0> scan 'test'
hbase(main):001:0> get 'test', 'row1'
```
##### WebUI
```
http://centos01:16010/master-status
http://centos02:16030/rs-status
```

##### 参考

```
http://hbase.apache.org/book.html#confirm
```