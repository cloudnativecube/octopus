# Clickhouse使用经验

[TOC]

## 配置进阶

### Server端参数

server端参数只能通过配置文件（config.xml）配置，无法在session或query层修改。

#### 1.compression

clickhouse默认的压缩算法是lz4，在config.xml里可以配置压缩参数compression，但该参数并不能修改默认的压缩算法，而是通过配置条件来支持其他压缩算法（目前只支持lz4和zstd），具体用法如下：

```xml
<compression incl="clickhouse_compression">
    <case>
        <min_part_size>10000000000</min_part_size>
        <min_part_size_ratio>0.01</min_part_size_ratio>
        <method>zstd</method>
    </case>
</compression>
```

其中case节点可以指定min_part_size和min_part_size_ratio两个条件的值，条件满足后会使用method指定的压缩算法进行压缩，且支持配置多个case。如上述配置表示如果一个part的size大于10G且占整个表的占比超过0.01后改用zstd压缩该part。此时可以观察到数据的压缩比会进一步降低，节省了磁盘空间。

注意：

1.单个case里的条件需要全部满足才会触发重新压缩part；

2.若配置了多个case且同时有多个case满足条件，按照第一个case指定的压缩格式进行压缩。

#### 2.merge_tree

merge_tree相关配置可在config.xml里通过如下方式指定，支持的参数可在system.merge_tree_settings表里查询，且所有merge_tree内部的参数均支持在表级别进行设置，可在建表时通过指定settings配置。

```xml
<merge_tree>
    <max_suspicious_broken_parts>5</max_suspicious_broken_parts>
    <parts_to_throw_insert>600</parts_to_throw_insert>
</merge_tree>
```

如果想要修改已经建好的表的settings，可以通过alter命令进行修改：

```sql
ALTER TABLE foo MODIFY SETTING max_parts_in_total = 1000000;
```

目前导数方案需要关注其中几个参数：

1.**max_parts_in_total**

单表允许的最大active parts数量，超过会报Too many parts (N) exception。值太大会降低查询性能，增加clickhouse启动时间，太多的分区可能是分区键设置不合理。默认值100000。

2.**parts_to_throw_insert**

单个分区允许的最大active parts数量，超过会报Too many parts (N). Parts cleaning are processing significantly slower than inserts。太大的值会影响select的性能。默认值300。

3.**parts_to_delay_insert**

单个分区active parts数量超过该值后，插入速度会变慢（增加了睡眠时间），以防止merge速度跟不上写入的速度而抛Too many parts异常。默认值150。

由于导数时先写临时表，临时表关闭了merge功能，此时part的数量取决于数据源orc文件个数*每个文件的stripe数量，有可能会超过默认的限制，因此建临时表时调整了以上三个值的配置，且每个分区建一个临时表，以减少触发异常的可能。另外以上三个参数均只在写操作开始时检查，因此写入过程中可能会超过配置的限制，但不影响本次写入，下一个写入请求会抛too many parts异常。

### Query层配置

支持多种方式配置，一般配置在user.xml profiles节点里，也可以在session和query里修改，详细描述及优先级见https://clickhouse.tech/docs/en/operations/settings/

#### 1.max_threads

一个查询请求处理的最大线程数（但不包括从远端取数据的线程，见max_distributed_connections），如读取一个表时，涉及到函数的计算，数据过滤和group by等操作可以多线程并行，则最多可以使用max_threads个线程，实际用到的并发线程数为min(block数量，max_threads)。

默认值：为物理CPU核数

注意：

1.如果一些查询可以在一个block内获取到结果（如limit操作），尽量设置小的max_threads，不然如果有多个满足条件的block，min(block数量，max_threads)个block都会读取，造成资源浪费。

2.max_threads配置小的值会节省内存，但计算效率也会降低。

#### 2.max_distributed_connections

对于一个分布式表，可以同时连接到远程服务器的最大连接数量，该值至少要大于分片数。

默认值：1024

#### 3.insert_distributed_sync

写分布式表默认是异步的，本地表数据写入会有延迟，如果业务场景需要写分布式表（如哈希分片），需要设置insert_distributed_sync=1，此时会等待所有shard都保存完毕后再返回success（根据internal_replication的配置来决定写入副本的个数）。

默认值：0

写分布式表有如下注意事项：

1.哈希分片写分布式表的性能和写本地表无明显差异（同步写入时），但分区数会随shard的数量翻倍（如测试集群共3个分片， 测试表的part数量从844变成2532），sharding key配置成rand()随机分片时也会有parts翻倍的问题，另外有两种配置方式可以避免part翻倍，见后文配置参数4，5。

2.写分布式表时请求并发数不能设置太多，容易抛异常：too many simultaneous queries ，即超过了max_concurrent_queries_for_user配额，原因为分布式表写入时的并发请求数会放大，如集群共6个节点同时写，每个shard的第一个副本都会收到6个节点的写入请求（集群配置的load_balancing为first_or_random），若每个节点30个并发写入，那单节点最高并发数可达30*6=180）

#### 4.insert_distributed_one_random_shard

该参数表示当分布式表未指定sharding规则时是否允许随机写到一个分片上。

设置为0时，如果建分布式表时忽略了sharding key参数，分布式表写入时会抛如下异常：

```
Code: 55, e.displayText() = DB::Exception: Method write is not supported by storage Distributed with more than one shard and no sharding key provided
```

此时可以通过修改insert_distributed_one_random_shard的值支持随机写一个分片。

默认值：0

注意：

此时写入分布式表的一批数据不会再做分片，而是仅随机选取一个节点写入，因此没有parts膨胀的问题，与指定sharding key=rand()这种情况不一致。

#### 5.insert_shard_id

通过分布式表insert时只写到指定的某一个分片上，可以通过配置该参数屏蔽分布式表的分片规则，也支持在insert语句后通过setting指定，如：

```sql
INSERT INTO x_dist_all SELECT * FROM xxx SETTINGS insert_shard_id = 1;
--此时分布式表x_dist_all不会将写请求分别发送到多个shard上，仅写到分片1上
```

默认值：0，表示禁用

注意：

配置该值时分布式写入是同步的。

## 数据建模

### 字段效率对比

1.IntX，Date等类型效率明显高于String，初步测试同样的查询使用Int64代替String速度提升1.6倍，详细的对比还需进一步量化评估。

建模时如果数据可以安全的转换成更高效的类型，尽量进行转换。

2.Nullable类型的字段有存储膨胀的问题，clickhouse会为Nullable字段另外创建xxx.null.bin和xxx.null.mrk2文件，字段内NULL值的行数越多，xxx.null.bin文件所占空间越大，进一步影响计算效率。

建模时尽量使用非Nullable的类型，如果数据源有NULL值，在数据导入时可做数据类型转换，如使用if(isNull(a),'',a), if(isNull(b),0,b)等对每个字段指定一个对业务安全的默认值（避免影响查询结果）。

### 存储介质对比

SSD磁盘对查询性能的提升场景相对局限：

1.适用于IO密集型的查询，第一次从磁盘读取数据时有明显的提升效果；

2.大数据量高并发下的查询场景，系统缓存无法缓存全部数据，内存命中降低，从磁盘读取的情况增多，此时SSD能提升部分IO密集型查询的性能；

3.对于计算密集型的查询，瓶颈主要在CPU，此时SSD磁盘的性能收益很低，通过增大max_threads将瓶颈转移至磁盘IO时，会有部分性能收益；

## 数据导入

数据导入借助临时表时，需要结合导数逻辑判断是否需要关闭后台merge和副本间同步机制，merge操作会加锁，阻塞move partition等需要删除数据的操作（使用attach partition xxx from这种copy的操作不会阻塞）。而临时表的副本同步并无意义，且影响了多个副本同时写入不同数据时的数据迁移。

关闭merge文档：https://clickhouse.tech/docs/en/sql-reference/statements/system/#query_language-system-stop-merges

禁用同步文档：https://clickhouse.tech/docs/en/sql-reference/statements/system/#query-language-system-replicated

目前的导数方案是临时表全部shard的每个副本都写入不同的数据，临时表写入完毕要校验数据完整性，校验通过后每个节点分别move partition到目标表，需要针对临时表执行以下操作：

```sql
--关闭merge
SYSTEM STOP MERGES xxx.xxx  
--关闭副本间数据同步
SYSTEM STOP FETCHES xxx.xxx   
SYSTEM STOP REPLICATED SENDS xxx.xxx
SYSTEM STOP REPLICATION QUEUES xxx.xxx
```



## 未完待续..

