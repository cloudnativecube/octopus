# clickhouse部署与升级文档

## 获取软件包

从这个地址下载需要的版本：https://repo.yandex.ru/clickhouse/rpm/lts/x86_64/ 。

## 部署

如果是从裸机开始部署，这里描述最简单的部署方式。

准备两台机器，每台机器上分别执行以下安装步骤。

1.下载对应版本的软件包

```
clickhouse-client-20.8.7.15-2.noarch.rpm
clickhouse-common-static-20.8.7.15-2.x86_64.rpm
clickhouse-common-static-dbg-20.8.7.15-2.x86_64.rpm
clickhouse-server-20.8.7.15-2.noarch.rpm
```

2.安装软件包

```
# yum localinstall -y clickhouse-client-20.8.7.15-2.noarch.rpm clickhouse-common-static-20.8.7.15-2.x86_64.rpm clickhouse-common-static-dbg-20.8.7.15-2.x86_64.rpm clickhouse-server-20.8.7.15-2.noarch.rpm
# clickhouse-server --version
ClickHouse server version 20.8.7.15 (official build).
```

3.配置zookeeper地址

打开文件/etc/clickhouse-server/config.xml，修改监听地址，允许接收任意主机的连接请求：

```
<listen_host>::</listen_host>
```

在/etc/clickhouse-server/config.xml的最后添加配置：

```
<yandex>
    ...
    <include_from>/etc/clickhouse-server/metrika.xml</include_from>
</yandex>
```

创建文件/etc/clickhouse-server/metrika.xml：

```
<yandex>
    <zookeeper-servers>
        <node>
            <host>centos1.local</host>
            <port>2181</port>
        </node>
        ...  //后面可以再添加zk集群的其他node
    </zookeeper-servers>
</yandex>
```

这里假设使用的zk是单节点，地址为centos1.local:2181。

4.启动服务程序

```
# systemctl start clickhouse-server
//检查进程及日志是否有异常
# ps -ef | grep clickhouse
# tail -f /var/log/clickhouse-server/clickhouse-server.log
```

5.执行查询

```
# clickhouse-client
ClickHouse client version 20.8.7.15 (official build).
Connecting to localhost:9000 as user default.
Connected to ClickHouse server version 20.8.7 revision 54438.

centos1.local :) show databases;
```

## 升级

本次升级的旧版本是：20.3.8.53-2，新版本是：20.8.7.15-2，下载以下4个rpm包：

```
clickhouse-client-20.8.7.15-2.noarch.rpm
clickhouse-common-static-20.8.7.15-2.x86_64.rpm
clickhouse-common-static-dbg-20.8.7.15-2.x86_64.rpm
clickhouse-server-20.8.7.15-2.noarch.rpm
```

通知用户，停止数据导入和查询请求，**逐个机器执行以下操作**。

1.停止服务程序

```
# systemctl stop clickhouse-server
```

2.备份配置文件

```
# cp /etc/clickhouse-server/config.xml /etc/clickhouse-server/config.xml.bak
```

3.卸载旧版本软件包

```
# rpm -qa | grep clickhouse
clickhouse-common-static-20.3.8.53-2.x86_64
clickhouse-common-static-dbg-20.3.8.53-2.x86_64
clickhouse-client-20.3.8.53-2.noarch
clickhouse-server-20.3.8.53-2.noarch
# rpm -e clickhouse-common-static-20.3.8.53-2.x86_64 clickhouse-common-static-dbg-20.3.8.53-2.x86_64 clickhouse-client-20.3.8.53-2.noarch clickhouse-server-20.3.8.53-2.noarch
```

4.安装新版本软件包

```
# yum localinstall -y clickhouse-client-20.8.7.15-2.noarch.rpm clickhouse-common-static-20.8.7.15-2.x86_64.rpm clickhouse-common-static-dbg-20.8.7.15-2.x86_64.rpm clickhouse-server-20.8.7.15-2.noarch.rpm
# clickhouse-server --version
ClickHouse server version 20.8.7.15 (official build).
```

5.恢复配置文件

```
# cp /etc/clickhouse-server/config.xml.bak /etc/clickhouse-server/config.xml
```

6.启动服务程序

```
# systemctl start clickhouse-server
//检查进程及日志是否有异常
# ps -ef | grep clickhouse
# tail -f /var/log/clickhouse-server/clickhouse-server.log
```

7.验证

升级完一台机器之后，让用户查一下某个分布式表，而且此分布式表的shard包含了当前被升级的机器。目的是让查询请求落到当前机器上，验证数据是否正常返回。

8.回滚

回滚操作即是降版本，与升级操作相同。

