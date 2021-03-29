# Clickhouse升级操作文档

#### 背景

若clickhouse集群中所有shards都包含>=2的replicas数据副本，并且集群中所有的表均使用了复制表表引擎的话（Replicated*MergeTree），那么数据自动就会备份到shard中的每个replica实例中，若其中一个replica实例因为升级的原因导致了个别异常问题，我们可以通过同步另一个replica的数据来完成数据恢复。

#### 升级步骤

根据配置，每个shard有多个replicas副本，那么每个shard的升级需要逐个replica进行，其中一个replica确保升级成功后，我们才能继续下一个replica的升级操作，就这样逐个的升级确保整个集群的升级成功。（**这样做的前提是clickhouse集群所有的表均使用的是复制表**）

**首先**，我们需要停掉某个replica实例上的clickhouse-server:

```
systemctl stop clickhouse-server
```

**然后**，将clickhouse升级所需的rpm包全部放入独立的文件夹（upgrade）中，进入该（upgrade）文件夹后执行如下命令：

```
yum upgrade *.rpm -y

更新完毕:
clickhouse-client.noarch 0:20.8.7.15-2
clickhouse-common-static.x86_64 0:20.8.7.15-2
clickhouse-server.noarch 0:20.8.7.15-2

完毕！
```

看到如上信息后，证明我们安装包已经安装成功。

**其次**，我们需要来验证安装后的clickhouse是否成功：

```
0. 暂时注释掉clickhouse zookeeper相关配置，这样做的目的是让当前clickhouse实例上的所有复制表均处于只读状态不允许写入新的数据，等测试新版本无问题后，在去除zookeeper相关配置注释
1. 启动新版clickhouse-server：systemctl start clickhouse-server
2. 查看是否启动成功：systemctl status clickhouse-server
3. 查看clickhouse相关日志有无明显报错信息，clickhouse相关日志的位置我们需要查看config.xml文件的配置，默认是
<log>/var/log/clickhouse-server/clickhouse-server.log</log>
<errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
4. 运行clickhouse-client，进入交互终端后确认版本信息，执行：select version()
5. 去除zookeeper配置注释，重启systemctl restart clickhouse-server.
```

#### 降级步骤
若升级过程中出现严重问题，无法规避，那我们需要做降级操作，降级所需的所有rpm包文件我们需要放到单独的（downgrade）文件夹，进入文件夹执行：
```
systemctl stop clickhouse-server

yum downgrade *.rpm -y

systemctl start clickhouse-server (若出现数据损坏无法启动的情况，需要查看日志分析具体原因，分析具体损坏的文件)
```

#### 关于备份

对于没有使用每个shard多副本的集群，并且数据表并非全部都是复制表的情况，我们在做升级的时候就需要考虑自己去做备份了，需要备份的数据有这么几种：

**配置**（建议所有集群情况均备份，因为数据量很小）：升级之前建议备份clickhouse相关的一些配置文件,默认是在/etc/clickhouse目录下的所有文件(不同环境若有不同请自行确认，总之要备份好旧配置) 

**元数据**（建议所有集群情况均备份，因为数据量很小）：默认config.xml配置(具体看真实配置) /var/lib/clickhouse/metadata 下存储了元数据，可以很方便的使用物理复制的方式进行，cp -rf metadata metadata_bk

**详细数据**（视情况而定，数据量大与小的区别）：默认config.xml配置(具体看真实配置) /var/lib/clickhouse/data 下存储了具体的真正数据，该目录的结构是database下是table, table下是更细粒度的partition, 若该数据并不大且使用物理复制的方式系统磁盘容量可以满足复制后的存储大小，那么建议采用物理复制（注意：在做物理复制前请systemctl stop clickhouse-server 防止数据的写入，因为在复制的过程写入数据可能会导致数据损坏）

若数据非常庞大，本地磁盘无法容纳备份后的数据，那么建议采用[clickhouse-copier](https://clickhouse.tech/docs/en/operations/utilities/clickhouse-copier/)工具将本集群的数据复制到其他容灾集群做容灾备份；

或者也可以使用第三方工具[clickhouse-backup](https://github.com/AlexAkulov/clickhouse-backup),该工具可以将本地数据本分到s3云存储上，同时也支持以硬链接（不占用存储空间）的方式备份数据到本地，但硬链接仅可以避免数据删除，但不会避免数据修改，这也是他的不足之处。

#### 参考

https://clickhouse.tech/docs/en/operations/backup/

https://clickhouse.tech/docs/en/operations/utilities/clickhouse-copier/

https://github.com/AlexAkulov/clickhouse-backup
