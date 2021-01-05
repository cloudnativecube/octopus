
#### `executor规格配置`
executor规格推荐配置:
- spark.executor.cores=4
- spark.executor.memory=12g
- spark.executor.memoryOverhead=3g

如果特殊情况需要调整executor资源规格，参考如下建议：
- spark.executor.memory/spark.executor.cores=3 （比例应趋于线上机器cpu/memory比例）
- spark.executor.cores <= 8 (单个executor同时处理的任务数过多,容易产生热点问题,应将压力分摊开)

#### `shuffle service`
线上默认开启shuffle service，不应关闭shuffle service.
- spark.shuffle.service.enabled=true

不建议用户修改如下配置:
- spark.network.timeout
- spark.shuffle.io.maxRetries 


#### `动态资源`
线上默认开启动态资源，非必要的情况下不应关闭动态资源（必须关闭动态资源的情况，如:使用BigDL时无法开启动态资源）
- spark.dynamicAllocation.enabled=true

为了便于理解，在动态资源的模式下应废弃对spark.executor.instance|num-executors的调整,保持默认配置：
- spark.executor.instance=2

资源参数调整应优先调整executor个数，而非executor规格 (保证executor规格的标准统一) 参考如下建议：
- spark.dynamicAllocation.maxExecutors<=partition个数 / spark.executor.cores
- spark.dynamicAllocation.minExecutors=2
- spark.dynamicAllocation.initialExecutors<500 (过大的初始值，可能对AM有影响)

#### `partition`
SQL任务input partition(split)
- input table为ORC文件,每个task处理的数据量过大,且产生大量spill,应进行拆分优化
    - spark.sql.hive.convertMetastoreOrc=true
    - spark.hadoop.hive.exec.orc.split.strategy=ETL
- input table为ORC文件,每个task处理的数据量较小，且总的task数特别多,应进行合并优化
    - spark.sql.hive.convertMetastoreOrc=true
    - spark.hadoop.hive.exec.orc.split.strategy=BI

shuffle partition：(一般只关注一个application中shuffle数据量最大的stage)
- spark.sql.shuffle.partitions = shuffle数据总量 / 单个task数据量 
    - shuffle数据总量不变
    - 优先增加partition个数，尽量保证单个task数据量在128m~256m之间或无spill产生
    - partition > 5000时，应适当增加单个task数据量，保证task没有或只有少量spill
    - task如果出现大量spill，再考虑增加partition个数
    - 较大partition的任务，为保证任务时效性，应增加executor的个数

  总结起来就是，由“shuffle数据总量”与“单个task数据量”确定partition数量，如果partition数量比较大，再(1)适当增加单个task数据量，(2)若task数据量过大再反过来增加partition数量；如果partition数量仍然比较大，并且task数量也不能再增加了，就横向扩容executor个数。

- AE动态partition的使用以及特别需注意的
    - spark.sql.adaptive.enabled=true
    - spark.sql.adaptive.maxNumPostShufflePartitions=最大的shuffle数据总量 / spark.sql.adaptive.shuffle.targetPostShuffleInputSize
    - spark.sql.adaptive.shuffle.targetPostShuffleInputSize （需评估UDF的效率，决定单个task预期数据量）

#### `SQL任务数据倾斜`
源数据倾斜（即 input阶段有数据倾斜）：
- 如果源表是ORC文件尝试开启Apache ORC Reader的优化
    - spark.sql.hive.convertMetastoreOrc=true

SortMergeJoin产生数据倾斜：
- 小表的数据量较小时(线上配置阈值50M)，优化为BroadcastHashJoin
    - spark.sql.adaptive.join.enabled=true
    - spark.sql.adaptiveBroadcastJoinThreshold <= 500m （线上默认阈值为50M） 

- 小表数据量较大时，拆分发生数据倾斜的partition
    - spark.sql.adaptive.skewedJoin.enabled=true 
    - spark.sql.adaptive.skewedPartitionFactor (partition判断条件：大于中位数多少倍时才算倾斜partition)
    - spark.sql.adaptive.skewedPartitionSizeThreshold (partition判断条件：大于设置的阈值才算倾斜partition)

其他情况的数据倾斜需要用户从业务角度去优化.

#### `SQL任务的stage较多，且shuffle数据量大小不一`
需要动态调整partition数量，开AE的动态partition
- spark.sql.adaptive.enabled=true

#### `executor的“complete tasks”为0`
原因是初始时executor数量较多，而task数量不多，以至于executor空闲，减小初始的executor个数。
- 减小spark.dynamicAllocation.initialExecutors
- 减小spark.executor.instance

#### `gc时间较长，达到task执行时间的10%`
目标就是增大单个task的可用内存，从两个方面考虑：
- 首先尝试增大partition，减小单个task的数据量，参考前面的partition优化
- 其次考虑增大executor的memory，以减小gc次数
    - 适当增大spark.executor.memory

#### `合并小文件耗时较长`
- 首先确认用户使用的是哪种合并小文件方法，建议关闭MR的合并小文件方式，使用spark的方式
    - spark.sql.hive.mergeFiles=true
- 其次考虑减小partition，以减小最后需要合并的小文件个数
    - spark.sql.adaptive.enabled=true (默认开启)
    - 适当减小spark.sql.shuffle.partitions

#### `数据膨胀比例特别大，导致产生大量的spill`
建议增加partition,以减小单个task所处理的数据量,参考partition的优化.

#### `TMM的offheap方式不建议用户自己配置`
- spark.memory.offheap.enabled=false

#### `用户自定义JVM参数`
不建议用户配置JVM参数，应优先使用线上默认的JVM优化参数。
- spark.driver.extraJavaOptions
- spark.executor.extraJavaOptions