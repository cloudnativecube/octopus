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