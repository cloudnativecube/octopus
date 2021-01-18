## spark-sql参数

- spark.sql.broadcastTimeout

  该参数被BroadcastExchangeExec使用。这个超时时间包括collectTime、buildTime、broadcastTime。其中collectTime就是执行child算子的RDD的collect()方法的时间，因为collect()是个action算子，所以会产生一个job。

  问题：当application需要的资源不足时，如果BroadcastExchangeExec所在的stage已经被提交，但是没有资源执行其中的task，那么实际上BroadcastExchangeExec已经被触发了（即它的doExecuteBroadcast()方法已经被调用，这时超时时间开始计时），但是child算子的collect过程又得不到执行，就可能会导致超时。解决方法是调大该参数。

## spark-core参数

- spark.locality.wait

  spark.locality.wait.process

  spark.locality.wait.node

  spark.locality.wait.rack

- spark.network.timeout

  spark.core.connection.ack.wait.timeout会控制网络超时时间，包括“从hdfs上读数据”的过程，它的默认值是spark.network.timeout。该参数已经被移除了，见https://issues.apache.org/jira/browse/SPARK-33631。

- spark.shuffle.file.buffer 【32K】

  用于设置shuffle write中使用的文件缓冲区的大小，包括：

  (1)【BypassMergeSortShuffleWriter】中的多个partitionWriter使用的输出缓冲区；

  (2)【UnsafeShuffleWriter】ShuffleExternalSorter中写spill文件时使用的输出缓冲区；UnsafeShuffleWriter在合并spill文件时使用的文件输入缓冲区；

  (4)【SortShuffleWriter】ExternalSorter在写spilled file和写partitined file时使用的输出缓冲区；

  (5)【BlockStoreShuffleReader】ExternalAppendOnlyMap在写spilled file时使用的输出缓冲区。

- spark.reducer.maxSizeInFlight 48M

  reducer在执行shuffle read是，允许从网络上读取的最大数据量。reducer发出的单个请求允许读取的最大数据量限制为该值的1/5，这样可以让多个并发请求同时进行。

- spark.shuffle.io.maxRetries 3

- spark.shuffle.io.retryWait 5s

## spark-history参数

- `spark.history.fs.update.interval 默认值10秒`
  这个参数指定刷新日志的时间，更短的时间可以更快检测到新的任务以及任务执行情况，但过快会加重服务器负载。

- `spark.history.ui.maxApplication 默认值intMaxValue`
  这个参数指定UI上最多显示的作业的数目。

- `spark.history.ui.port 默认值18080`
  这个参数指定history-server的网页UI端口号。

- `spark.history.fs.cleaner.enabled 默认为false`
  这个参数指定history-server的日志是否定时清除，true为定时清除，false为不清除。这个值一定设置成true啊，不然日志文件会越来越大。

- `spark.history.fs.cleaner.interval 默认值为1d`
  这个参数指定history-server的日志检查间隔，默认每一天会检查一下日志文件。

- `spark.history.fs.cleaner.maxAge 默认值为7d`
  这个参数指定history-server日志生命周期，当检查到某个日志文件的生命周期为7d时，则会删除该日志文件。

- `spark.eventLog.compress 默认值为false`
  这个参数设置history-server产生的日志文件是否使用压缩，true为使用，false为不使用。这个参数务可以成压缩哦，不然日志文件岁时间积累会过大。

- `spark.history.retainedApplications 　默认值：50`
  在内存中保存Application历史记录的个数，如果超过这个值，旧的应用程序信息将被删除，当再次访问已被删除的应用信息时需要重新构建页面。

## 异常信息

1.sql解析异常

```
Exception in thread "main" org.apache.spark.sql.catalyst.errors.package$TreeNodeException: makeCopy, tree:
HiveTableRelation `<数据库名>`.`<表名>`, ...
```

这是sql语句解析时报的错。可能原因是建的表有问题。

解决办法：重新建表。

2.insert into ... select ... 插入数据与目标表的列不匹配

```
org.apache.spark.sql.AnalysisException: `default`.`table` requires that the data to be inserted have the same number of columns as the target table: target table has 2 column(s) but the inserted data has 1 column(s), including 0 partition column(s) having constant value(s).; 
```

可能原因是建的表有问题：先创建了表，后用alter table命令修改了列，但未使用cascade。

解决办法：重新建表，或用replace column ... cascade命令。

## 测试

1.在spark-sql中广播视图

```
spark-sql> create table t1(a int, b int); //类似创建t2,t3,t4
spark-sql> create view view_a as (select t1.a as t1a,t2.a as t2a from t1 join t2 on t1.a=t2.a);
spark-sql> create view view_b as (select t3.a as t3a,t4.a as t4a from t3 join t4 on t3.a=t4.a);

测试语句：  explain select * from view_a A join view_b B on A.t1a=B.t3a;

查看执行计划，view_a作了广播：
spark-sql> explain select/*+ BROADCAST(A) */ * from view_a A join view_b B on A.t1a=B.t3a;
== Physical Plan ==
*(4) BroadcastHashJoin [t1a#256], [t3a#264], Inner, BuildLeft
:- BroadcastExchange HashedRelationBroadcastMode(List(cast(input[0, int, true] as bigint))), [id=#730]
:  +- *(2) Project [a#260 AS t1a#256, a#262 AS t2a#257]
:     +- *(2) BroadcastHashJoin [a#260], [a#262], Inner, BuildRight
:        :- *(2) Filter isnotnull(a#260)
:        :  +- Scan hive default.t1 [a#260], HiveTableRelation `default`.`t1`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#260, b#261]
:        +- BroadcastExchange HashedRelationBroadcastMode(List(cast(input[0, int, false] as bigint))), [id=#725]
:           +- *(1) Filter isnotnull(a#262)
:              +- Scan hive default.t2 [a#262], HiveTableRelation `default`.`t2`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#262, b#263]
+- *(4) Project [a#268 AS t3a#264, a#270 AS t4a#265]
   +- *(4) BroadcastHashJoin [a#268], [a#270], Inner, BuildRight
      :- *(4) Filter isnotnull(a#268)
      :  +- Scan hive default.t3 [a#268], HiveTableRelation `default`.`t3`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#268, b#269]
      +- BroadcastExchange HashedRelationBroadcastMode(List(cast(input[0, int, false] as bigint))), [id=#737]
         +- *(3) Filter isnotnull(a#270)
            +- Scan hive default.t4 [a#270], HiveTableRelation `default`.`t4`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#270, b#271]

查看执行计划，view_b作了广播：
spark-sql> explain select/*+ BROADCAST(B) */ * from view_a A join view_b B on A.t1a=B.t3a;
== Physical Plan ==
*(4) BroadcastHashJoin [t1a#277], [t3a#285], Inner, BuildRight
:- *(4) Project [a#281 AS t1a#277, a#283 AS t2a#278]
:  +- *(4) BroadcastHashJoin [a#281], [a#283], Inner, BuildRight
:     :- *(4) Filter isnotnull(a#281)
:     :  +- Scan hive default.t1 [a#281], HiveTableRelation `default`.`t1`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#281, b#282]
:     +- BroadcastExchange HashedRelationBroadcastMode(List(cast(input[0, int, false] as bigint))), [id=#818]
:        +- *(1) Filter isnotnull(a#283)
:           +- Scan hive default.t2 [a#283], HiveTableRelation `default`.`t2`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#283, b#284]
+- BroadcastExchange HashedRelationBroadcastMode(List(cast(input[0, int, true] as bigint))), [id=#832]
   +- *(3) Project [a#289 AS t3a#285, a#291 AS t4a#286]
      +- *(3) BroadcastHashJoin [a#289], [a#291], Inner, BuildRight
         :- *(3) Filter isnotnull(a#289)
         :  +- Scan hive default.t3 [a#289], HiveTableRelation `default`.`t3`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#289, b#290]
         +- BroadcastExchange HashedRelationBroadcastMode(List(cast(input[0, int, false] as bigint))), [id=#827]
            +- *(2) Filter isnotnull(a#291)
               +- Scan hive default.t4 [a#291], HiveTableRelation `default`.`t4`, org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe, [a#291, b#292]

```

