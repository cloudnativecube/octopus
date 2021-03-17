# Trino(原Presto)安装文档

### 1.环境要求

安装的trino版本为353，其所需的环境如下：

| 组件   | 版本                                                     | 备注                                                         |
| ------ | -------------------------------------------------------- | ------------------------------------------------------------ |
| python | 2.6.x, 2.7.x, or 3.x                                     | 仅用于执行启动脚本bin/launcher                               |
| Java   | Java 11(\>=11.0.7)，推荐11.0.8，11.0.9                   | 更高的Java版本可能可行，但官方并未测试                       |
| Linux  | 64-bit required，测试环境为CentOS Linux release 7.7.1908 | 推荐修改/etc/security/limits.conf的限制，如soft/hard nofile 131072 |

### 2.安装trino

1.下载压缩包：https://repo1.maven.org/maven2/io/trino/trino-server/353/trino-server-353.tar.gz

2.将压缩包解压到安装目录。

```sh
tar xvf trino-server-353.tar.gz    #测试环境安装路径为：/home/servers/trino-server-353
```

3.修改配置文件：配置文件需放置在.trino-server-353/etc路径下，需要自行创建（包括etc目录）。

```
mkdir /home/servers/trino-server-353/etc
touch /home/servers/trino-server-353/etc/node.properties
touch /home/servers/trino-server-353/etc/jvm.config
touch /home/servers/trino-server-353/etc/config.properties
touch /home/servers/trino-server-353/etc/log.properties
```

node.properties文件配置如下：

```sh
node.environment=dev
node.id=centos01                    #每个节点单独配置
node.data-dir=/data/trino/data      #配置单独的数据目录存储日志等信息，方便升级
```

jvm.config文件配置如下：

```
-server
-Xmx16G
-XX:-UseBiasedLocking
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+ExitOnOutOfMemoryError
-XX:+HeapDumpOnOutOfMemoryError
-XX:ReservedCodeCacheSize=512M
-XX:PerMethodRecompilationCutoff=10000
-XX:PerBytecodeRecompilationCutoff=10000
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000
```

config.properties文件配置分如下三种情况：

```
#1.配置for coordinator，负责接收用户请求并管理查询的执行，生产部署时需要在上层配置代理等方式支持多coordinator配置
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.enabled=true
http-server.http.port=8081
query.max-memory=50GB
query.max-memory-per-node=1GB
query.max-total-memory-per-node=2GB
discovery-server.enabled=true
discovery.uri=http://centos01:8081     #均配置为coordinator的url
spill-enabled=true                     #开启磁盘溢写
spiller-spill-path=/data/trino/tmp/    #磁盘溢写路径


#2.配置for worker
coordinator=false
http-server.http.port=8081
query.max-memory=50GB
query.max-memory-per-node=10MB
query.max-total-memory-per-node=2GB
discovery.uri=http://centos01:8081
spill-enabled=true
spiller-spill-path=/data/trino/tmp/


#3.配置for 单节点同时负责coordinator和worker，用于单机测试
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8081
query.max-memory=5GB
query.max-memory-per-node=1GB
query.max-total-memory-per-node=2GB
discovery-server.enabled=true
discovery.uri=http://centos01:8081
spill-enabled=true
spiller-spill-path=/data/trino/tmp/
```

log.properties文件配置如下：

```
io.trino=INFO
```

4.配置catalog，连接器相关配置都放置在etc/catalog路径下，目录和配置文件均需要自行创建，配置文件命名可使用"xxx.properties"，xxx为自定义的文件名，常用的数据源配置示例如下：

mysql.properties：

```
connector.name=mysql
connection-url=jdbc:mysql://centos01:3306
connection-user=xxx
connection-password=xxx
```

myhive.properties：

```
connector.name=hive-hadoop2
hive.metastore.uri=thrift://centos01:9083
hive.config.resources=/home/servers/hadoop-3.1.4/etc/hadoop/hdfs-site.xml,/home/servers/hadoop-3.1.4/etc/hadoop/core-site.xml,/home/servers/hadoop-3.1.4/etc/hadoop/mapred-site.xml
```

myclickhouse.properties：

```
connector.name=clickhouse
connection-url=jdbc:clickhouse://centos01:8123/
connection-user=xxx
connection-password=xxx
```

myes.properties：

```
connector.name=elasticsearch
elasticsearch.host=centos01
elasticsearch.port=9200
elasticsearch.default-schema-name=default
```

myphoenix.properties：

```
#use phoenix5 For HBase 2.x and Phoenix 5.x (5.1.0 or later)
connector.name=phoenix5  
phoenix.connection-url=jdbc:phoenix:centos01,centos02,centos03:2181:/hbase
phoenix.config.resources=/home/servers/hbase-2.2.6/conf/hbase-site.xml
```

将完整的安装目录分发到其他节点上，注意修改node.properties的node.id（每个节点配置唯一的id，只能包含字母数字以及'-'和'_'）以及config.properties（coordinator和worker的配置区分开）。

### 3.启动及查询

```sh
#每个节点均需执行启动命令
/home/servers/trino-server-353/bin/launcher start
#如果部署环境涉及多个Java版本，可修改launcher脚本，添加如下配置：
#export JAVA_HOME=/opt/jdk-11.0.9
#export PATH=$JAVA_HOME/bin:$PATH

#查询启动状态
/home/servers/trino-server-353/bin/launcher status

#关闭trino，需每个节点单独执行
/home/servers/trino-server-353/bin/launcher stop

```

官方提供命令行的客户端以及jdbc的接口用于查询请求，客户端下载链接：https://repo1.maven.org/maven2/io/trino/trino-cli/353/trino-cli-353-executable.jar

```sh
#赋予执行权限
chmod +x trino-cli-353-executable.jar

#启动客户端，设置server为coordinator的地址
./trino-cli-353-executable.jar  --server centos01:8081 

#也可指定默认的catalog和database，如
./trino-cli-353-executable.jar  --server centos01:8081 --catalog hive --schema default
```

示例查询命令如下：

```sh
#查询所有的CATALOGS，即配置的连接器
show CATALOGS;  

#显示某个catalog下的databases，
show schemas from myclickhouse;

#显示catalog.database下的所有表
show tables from myclickhouse.ssb;

#指定catalog.database
use myhive.ssb;
```

