# octopus

### 软件版本
```
hadoop-3.1.4
  https://hadoop.apache.org/docs/r3.1.4/hadoop-project-dist/hadoop-common/ClusterSetup.html
ranger-2.0.0
  http://ranger.apache.org/quick_start_guide.html
knox-1.1.0
  http://knox.apache.org/books/knox-1-1-0/user-guide.html
hive-3.1.2
  https://cwiki.apache.org/confluence/display/Hive/GettingStarted#GettingStarted-InstallingHivefromaStableRelease
  https://cwiki.apache.org/confluence/display/Hive/AdminManual+Configuration
hbase-2.2.6
  https://hbase.apache.org/book.html#quickstart_fully_distributed
zookeeper-3.6.2
  https://zookeeper.apache.org/doc/r3.6.2/zookeeperStarted.html
spark-3.0.0
elasticsearch-7.9.2
  下载页面：https://www.elastic.co/cn/downloads/elasticsearch
es-hadoop-7.9.2
  下载页面：https://www.elastic.co/cn/downloads/hadoop
  文档：https://www.elastic.co/guide/en/elasticsearch/hadoop/current/requirements.html
```

### 机器

```
centos01 192.168.74.133
centos02 192.168.74.26
centos03 192.168.74.196
centos04 192.168.72.189
```

## 各服务地址

### Knox

- HDFS：https://10.0.0.11:8443/gateway/octopus/hdfs

- YARN：https://10.0.0.11:8443/gateway/octopus/yarn

### Ranger Admin

- UI：http://centos01:6080   用户名/密码：admin/2020root

### HDFS

- UI：http://10.0.0.11:9870/
- Namenode：hdfs://centos01:8020
- WebHDFS：http://centos01:9870/webhdfs

### YARN



### Spark

- History Server UI：http://centos01:18080

### Hive

- HiveServer2 UI：http://10.0.0.11:10002
- HiveServer2：http://centos01:10000

### HBase

- WebHBase：http://centos01:60080