# Elasticsearch-6.2.2

## 概述

- 下载：https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.2.2.tar.gz
- 文档：https://www.elastic.co/guide/en/elasticsearch/reference/6.2/index.html

## 部署

### 1.环境

- 关于jdk版本：https://www.elastic.co/guide/en/elasticsearch/reference/6.2/_early_access_check.html

  这里使用jdk为jdk-8u271-linux-x64.tar.gz。

- 关于节点角色：https://www.elastic.co/guide/en/elasticsearch/reference/6.2/modules-node.html

节点角色：

```
master,data centos01
master,data centos02
master,data centos03
```

### 2.系统配置

1.limits配置

文件/etc/security/limits.conf：

```
hadoop  hard nofile 65536
hadoop  soft nofile 65536
```

其他系统配置请参考：https://www.elastic.co/guide/en/elasticsearch/reference/6.2/bootstrap-checks.html

### 3.安装

1.配置文件config/elasticsearch.yml

```
cluster.name: octopus-es
node.name: centos01
path.data: /var/lib/elasticsearch
network.host: centos01
http.port: 9200
discovery.zen.ping.unicast.hosts: ["centos01", "centos02", "centos03"]
discovery.zen.minimum_master_nodes: 1
```

2.创建数据目录

```
# mkdir /var/lib/elasticsearch
# chown -R hadoop:hadoop /var/lib/elasticsearch
```

3.jdk配置

将jdk-8u271-linux-x64.tar.gz解压之后放到elasticsearch目录：

```
/home/servers/elasticsearch-6.2.2/jdk1.8.0_271
```

在bin/elasticsearch中添加JAVA_HOME：

```
JAVA_HOME=/home/servers/elasticsearch-6.2.2/jdk1.8.0_271
```

4.启动

```
bin/elasticsearch -d
```

### 4.xpack(不需要安装)

文档：https://www.elastic.co/guide/en/elasticsearch/reference/6.2/installing-xpack-es.html

安装：

```
# bin/elasticsearch-plugin install file:///home/servers/elasticsearch-6.2.2/x-pack-6.2.2.zip
-> Downloading file:///home/servers/elasticsearch-6.2.2/x-pack-6.2.2.zip
[=================================================] 100%
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@     WARNING: plugin requires additional permissions     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
* java.io.FilePermission \\.\pipe\* read,write
* java.lang.RuntimePermission accessClassInPackage.com.sun.activation.registries
* java.lang.RuntimePermission getClassLoader
* java.lang.RuntimePermission setContextClassLoader
* java.lang.RuntimePermission setFactory
* java.net.SocketPermission * connect,accept,resolve
* java.security.SecurityPermission createPolicy.JavaPolicy
* java.security.SecurityPermission getPolicy
* java.security.SecurityPermission putProviderProperty.BC
* java.security.SecurityPermission setPolicy
* java.util.PropertyPermission * read,write
See http://docs.oracle.com/javase/8/docs/technotes/guides/security/permissions.html
for descriptions of what these permissions allow and the associated risks.

Continue with installation? [y/N]y
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@        WARNING: plugin forks a native controller        @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
This plugin launches a native controller that is not subject to the Java
security manager nor to system call filters.

Continue with installation? [y/N]y
-> Installed x-pack with: x-pack-core,x-pack-deprecation,x-pack-graph,x-pack-logstash,x-pack-ml,x-pack-monitoring,x-pack-security,x-pack-upgrade,x-pack-watcher
```

卸载：

```
# bin/elasticsearch-plugin remove x-pack --purge
```

# Kibana-6.2.2

## 概述

下载：https://artifacts.elastic.co/downloads/kibana/kibana-6.2.2-linux-x86_64.tar.gz

文档：https://www.elastic.co/guide/en/kibana/6.2/index.html

## 部署

1.配置文件config/kibana.yml

```
server.port: 5601
server.host: "centos01"
server.name: "octopus-kibana"
elasticsearch.url: ["http://centos01:9200"]
```

2.启动

```
nohup bin/kibana 2>&1 > kibana.log &
```

在浏览器上打开UI：http://centos01:5601/ 。

控制台工具：http://centos01:5601/app/kibana#/dev_tools/console?_g=()

kibana是node.js服务，如果要查看进程，需要用`ps -ef | grep node`。

3.加载数据集

按此文档测试一下加载数据集：https://www.elastic.co/guide/en/kibana/6.2/tutorial-load-dataset.html 。

# Elasticsearch-7.9.2

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
hadoop  hard nofile 65536
hadoop  soft nofile 65536
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

- 获取索引：`http://centos01:9200/{index}?pretty`
- 查看索引统计信息：`http://centos01:9200/{index}/_stats?pretty`

# Kibana-7.9.2

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