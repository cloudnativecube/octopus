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
spark-2.4.7
elasticsearch-7.9.2
waterdrop-1.5.1
```

### 机器

```
10.0.0.11 centos01
10.0.0.12 centos02
10.0.0.13 centos03
10.0.0.14 centos04
```

## 组件分布

| 组件                | 依赖             | centos01                      | centos02                    | centos03         | Centos04         |
| ------------------- | ---------------- | ----------------------------- | --------------------------- | ---------------- | ---------------- |
| HDFS                |                  | NameNode                      | DataNode、SecondaryNameNode | DataNode         | DataNode         |
| YARN                |                  | ResourceManager               | DataManager                 | DataManager      | DataManager      |
| YARN JobHistory     |                  | JobHistoryServer              | JobHistoryServer            | JobHistoryServer | JobHistoryServer |
| Hive                | MySQL            | metastore、hiveserver2        |                             |                  |                  |
| ZooKeeper           |                  | zk                            | zk                          | zk               |                  |
| HBase               | ZooKeeper        | HMaster                       | HRegionServer               | HRegionServer    | HRegionServer    |
| Spark               | YARN、 metastore | thriftserver                  |                             |                  |                  |
| Spark HistoryServer |                  | HistoryServer                 |                             |                  |                  |
| MySQL               |                  | mysql server                  |                             |                  |                  |
| Solr                | ZooKeeper        | solr                          | solr                        | solr             |                  |
| Knox                |                  | knox                          |                             |                  |                  |
| Ranger              | MySQL、Solr      | ranger-admin、ranger-usersync |                             |                  |                  |
| elasticsearch       |                  | master                        | data                        | data             | data             |

## 各服务地址

### MySQL

- jdbc:mysql://centos01:3306  hive数据库的用户名/密码：hive/2020root

### Knox

gateway登录密码：admin/admin-password

- HDFS：https://10.0.0.11:8443/gateway/octopus/hdfs

- YARN：https://10.0.0.11:8443/gateway/octopus/yarn

### Ranger Admin

- UI：http://centos01:6080   用户名/密码：admin/2020root

### HDFS

- UI：http://10.0.0.11:9870/
- Namenode：hdfs://centos01:8020
- WebHDFS：http://centos01:9870/webhdfs

### YARN

- UI：http://10.0.0.11:8088/cluster
- JobHistory UI：http://10.0.0.11:19888/jobhistory 

### Hive

- metastore：thrift://centos01:9083
- warehouse（在HDFS上）：http://10.0.0.11:8020/user/hive/warehouse
- hiveserver2 thrift：thrift://centos01:10000
- hiveserver2 http（未启用）：http://centos01:10001

- hiveserver2 UI：http://10.0.0.11:10002

### Spark

- History Server UI：http://centos01:18080
- thriftserver：thrift://centos01:10003

### HBase

- WebHBase：http://centos01:60080

### elasticsearch

- http://centos01:9200

