## elasticsearch

## 概述

- 下载：https://www.elastic.co/cn/downloads/past-releases#elasticsearch
- 文档：https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html

## 部署

### 1.环境

#### 版本7.9.2

https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.2-linux-x86_64.tar.gz

#### 节点

每个es节点可以有多种role，参考：https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html。

这里只配置master和data两种role，对应的机器是：

```
master centos01
data centos02
data centos03
data centos04
```

### 2.系统配置

#### limits配置

文件/etc/security/limits.conf：

```
hadoop  hard nofile 65535
hadoop  soft nofile 65535
```

#### sysctl配置

文件/etc/sysctl.conf：

```
vm.max_map_count=262144
```

执行以下命令使更改生效：

```
# sysctl -p
```

### 3.安装

1.安装用户

es的启动不能使用root用户，所以我们全程使用hadoop用户安装及启动。

2.解压缩安装包之后的部署目录

```
# pwd
/home/servers/elasticsearch-7.9.2
```

3.JDK

我们的开发环境都是安装的jdk-8，但es从7.2版本之后使用jdk-11。es启动时先选择系统jdk，如果没有配置JAVA_HOME，则使用自带的jdk。所以为了让es使用自带jdk，作以下配置变更：

在文件bin/elasticsearch-env开头设置：

```
JAVA_HOME=""
```

4.es配置

配置文件为config/elasticsearch.yml，以下是master节点的配置。

```
cluster.name: octopus-es
node.name: centos01
node.roles: [ master ]
path.data: /data/elasticsearch
network.host: centos01
http.port: 9200
discovery.seed_hosts: ["centos01"]
cluster.initial_master_nodes: ["centos01"]
```

5.分发文件

将/home/servers/elasticsearch-7.9.2目录分发到其他data节点上，并修改有关的配置（比如centos02）：

```
node.name: centos02
node.roles: [ data ]
network.host: centos02
```

4.启动

分别启动master和data节点：

```
# bin/elasticsearch -d
```

启动之后在当前目录的logs目录中产生日志文件。

5.运维命令

- 检查集群健康状态

```
# curl centos01:9200/_cluster/health?pretty
{
  "cluster_name" : "octopus-es",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 2,
  "active_primary_shards" : 0,
  "active_shards" : 0,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}
```

# Kibana

### 概述

- 从这个页面找到安装包：https://www.elastic.co/guide/en/kibana/current/targz.html
- 文档：https://www.elastic.co/guide/en/kibana/current/index.html

### 部署

1.环境

选择7.9.2版本，下载安装包：https://artifacts.elastic.co/downloads/kibana/kibana-7.9.2-linux-x86_64.tar.gz

部署到centos01节点。

2.配置

```
# pwd
/home/servers/kibana-7.9.2-linux-x86_64
```

配置文件config/kibana.yml：

```
server.port: 5601
server.host: "centos01"
server.name: "octopus-kibana"
elasticsearch.hosts: ["http://centos01:9200"]
```

3.启动

```
nohup bin/kibana 2>&1 > kibana.log &
```

在浏览器上打开UI：http://10.0.0.11:5601/

### 探索es数据

在UI上进入Discover，创建index pattern匹配到es里的index。

再回到discover页面：http://10.0.0.11:5601/app/discover，即可开始查询es中的数据。