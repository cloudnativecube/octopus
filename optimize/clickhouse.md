# ClickHouse调优

- max_concurrent_queries

最大并发处理的请求数(包含select,insert等)，默认值100，推荐150(不够再加)，在我们的集群中出现过”max concurrent queries”的问题。

- max_bytes_before_external_sort

当order by已使用max_bytes_before_external_sort内存就进行溢写磁盘(基于磁盘排序)，如果不设置该值，那么当内存不够时直接抛错，设置了该值order by可以正常完成，但是速度相对存内存来说肯定要慢点(实测慢的非常多，无法接受)。

- background_pool_size

后台线程池的大小，merge线程就是在该线程池中执行，当然该线程池不仅仅是给merge线程用的，默认值16，推荐32提升merge的速度(CPU允许的前提下)。

- max_memory_usage

单个SQL在单台机器最大内存使用量，该值可以设置的比较大，这样可以提升集群查询的上限。

- max_memory_usage_for_all_queries

单机最大的内存使用量可以设置略小于机器的物理内存(留一点内操作系统)。

- max_bytes_before_external_group_by

在进行group by的时候，内存使用量已经达到了max_bytes_before_external_group_by的时候就进行写磁盘(基于磁盘的group by相对于基于磁盘的order by性能损耗要好很多的)，一般max_bytes_before_external_group_by设置为max_memory_usage / 2，原因是在clickhouse中聚合分两个阶段：

查询并且建立中间数据；

合并中间数据 写磁盘在第一个阶段，如果无须写磁盘，clickhouse在第一个和第二个阶段需要使用相同的内存。

这些内存参数强烈推荐配置上，增强集群的稳定性避免在使用过程中出现莫名其妙的异常。



## 那些年我们遇到过的问题

**case study：**

- Too many parts(304). Merges are processing significantly slower than inserts**

相信很多同学在刚开始使用clickhouse的时候都有遇到过该异常，出现异常的原因是因为MergeTree的merge的速度跟不上目录生成的速度, 数据目录越来越多就会抛出这个异常, 所以一般情况下遇到这个异常，降低一下插入频次就ok了，单纯调整background_pool_size的大小是治标不治本的。

**我们的场景：**

我们的插入速度是严格按照官方文档上面的推荐”每秒不超过1次的insert request”，但是有个插入程序在运行一段时间以后抛出了该异常，很奇怪。

**问题排查：**

排查发现失败的这个表的数据有一个特性，它虽然是实时数据但是数据的eventTime是最近一周内的任何时间点，我们的表又是按照day + hour组合分区的那么在极限情况下，我们的一个插入请求会涉及7*24分区的数据，也就是我们一次插入会在磁盘上生成168个数据目录(文件夹)，文件夹的生成速度太快，merge速度跟不上了，所以官方文档的上每秒不超过1个插入请求，更准确的说是每秒不超过1个数据目录。

**case study：**

分区字段的设置要慎重考虑，如果每次插入涉及的分区太多，那么不仅容易出现上面的异常，同时在插入的时候也比较耗时，原因是每个数据目录都需要和zookeeper进行交互。

- DB::NetException: Connection reset by peer, while reading from socket xxx**

查询过程中clickhouse-server进程挂掉。

**问题排查：**

排查发现在这个异常抛出的时间点有出现clickhouse-server的重启，通过监控系统看到机器的内存使用在该时间点出现高峰，在初期集群"裸奔"的时期，很多内存参数都没有进行限制，导致clickhouse-server内存使用量太高被OS KILL掉。

**case study：**

上面推荐的内存参数强烈推荐全部加上，max_memory_usage_for_all_queries该参数没有正确设置是导致该case触发的主要原因。

- Memory limit (for query) exceeded:would use 9.37 GiB (attempt to allocate chunk of 301989888 bytes), maximum: 9.31 GiB**

该异常很直接，就是我们限制了SQL的查询内存(max_memory_usage)使用的上线，当内存使用量大于该值的时候，查询被强制KILL。

对于常规的如下简单的SQL, 查询的空间复杂度为O(1) 。

select count(1) from table where condition1 and condition2 

select c1, c2 from table where condition1 and condition2

对于group by, order by , count distinct，join这样的复杂的SQL，查询的空间复杂度就不是O(1)了，需要使用大量的内存。

如果是group by内存不够，推荐配置上max_bytes_before_external_group_by参数，当使用内存到达该阈值，进行磁盘group by

如果是order by内存不够，推荐配置上max_bytes_before_external_sort参数，当使用内存到达该阈值，进行磁盘order by

如果是count distinct内存不够，推荐使用一些预估函数(如果业务场景允许)，这样不仅可以减少内存的使用同时还会提示查询速度

对于JOIN场景，我们需要注意的是clickhouse在进行JOIN的时候都是将"右表"进行多节点的传输的(右表广播)，如果你已经遵循了该原则还是无法跑出来，那么好像也没有什么好办法了

zookeeper的snapshot文件太大，follower从leader同步文件时超时

上面有说过clickhouse对zookeeper的依赖非常的重，表的元数据信息，每个数据块的信息，每次插入的时候，数据同步的时候，都需要和zookeeper进行交互，上面存储的数据非常的多。

就拿我们自己的集群举例，我们集群有60台机器30张左右的表，数据一般只存储2天，我们zookeeper集群的压力 已经非常的大了，zookeeper的节点数据已经到达500w左右，一个snapshot文件已经有2G+左右的大小了，zookeeper节点之间的数据同步已经经常性的出现超时。 

**问题解决：**

zookeeper的snapshot文件存储盘不低于1T，注意清理策略，不然磁盘报警报到你怀疑人生，如果磁盘爆了那集群就处于“残废”状态； 

zookeeper集群的znode最好能在400w以下； 

建表的时候添加use_minimalistic_part_header_in_zookeeper参数，对元数据进行压缩存储，对于高版本的clickhouse可以直接在原表上面修改该setting信息，注意修改完了以后无法再回滚的。

- zookeeper压力太大，clickhouse表处于”read only mode”，插入失败

zookeeper机器的snapshot文件和log文件最好分盘存储(推荐SSD)提高ZK的响应；

做好zookeeper集群和clickhouse集群的规划，可以多套zookeeper集群服务一套clickhouse集群。

- 关闭Linux虚拟内存。在一次ClickHouse服务器内存耗尽的情况下，我们Kill掉占用内存最多的Query之后发现，这台ClickHouse服务器并没有如预期的那样恢复正常，所有的查询依然运行的十分缓慢。

  通过查看服务器的各项指标，发现虚拟内存占用量异常。因为存在大量的物理内存和虚拟内存的数据交换，导致查询速度十分缓慢。关闭虚拟内存，并重启服务后，应用恢复正常。

- 为每一个账户添加join_use_nulls配置。ClickHouse的SQL语法是非标准的，默认情况下，以Left Join为例，如果左表中的一条记录在右表中不存在，右表的相应字段会返回该字段相应数据类型的默认值，而不是标准SQL中的Null值。对于习惯了标准SQL的我们来说，这种返回值经常会造成困扰。

- JOIN操作时一定要把数据量小的表放在右边，ClickHouse中无论是Left Join 、Right Join还是Inner Join永远都是拿着右表中的每一条记录到左表中查找该记录是否存在，所以右表必须是小表。

- 通过ClickHouse官方的JDBC向ClickHouse中批量写入数据时，必须控制每个批次的数据中涉及到的分区的数量，在写入之前最好通过Order By语句对需要导入的数据进行排序。无序的数据或者数据中涉及的分区太多，会导致ClickHouse无法及时的对新导入的数据进行合并，从而影响查询性能。

- 尽量减少JOIN时的左右表的数据量，必要时可以提前对某张表进行聚合操作，减少数据条数。有些时候，先GROUP BY再JOIN比先JOIN再GROUP BY查询时间更短。

- ClickHouse版本迭代很快，建议用去年的稳定版，不能太激进，新版本我们在使用过程中遇到过一些bug，内存泄漏，语法不兼容但也不报错，配置文件并发数修改后无法生效等问题。

- 避免使用分布式表，ClickHouse的分布式表性能上性价比不如物理表高，建表分区字段值不宜过多，太多的分区数据导入过程磁盘可能会被打满。

- 服务器CPU一般在50%左右会出现查询波动，CPU达到70%会出现大范围的查询超时，所以ClickHouse最关键的指标CPU要非常关注。我们内部对所有ClickHouse查询都有监控，当出现查询波动的时候会有邮件预警。

- 查询测试Case有：6000W数据关联1000W数据再关联2000W数据sum一个月间夜量返回结果：190ms；2.4亿数据关联2000W的数据group by一个月的数据大概390ms。但ClickHouse并非无所不能，查询语句需要不断的调优，可能与查询条件有关，不同的查询条件表是左join还是右join也是很有讲究的。