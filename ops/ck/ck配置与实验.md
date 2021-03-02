# Settings
## 设置方式
1. 配置文件。 配置 user.xml profiles等
2. session settings。 例如：`:) set max_threads=48`
3. query settings. 非交互式查询、HTTP API等。

## memory
#### max_memory_usage
单个查询用于在单个服务器上运行一个查询的最大RAM， 默认10G

#### max_memory_usage_for_user
用于在单个服务器上某个用户的最大RAM， 默认0，（0不受限制）

 #### max_concurrent_queries_for_user

The maximum number of concurrent requests for user

#### max_concurrent_queries_for_all_users
The maximum number of concurrent requests for all users. defalut 0.

#### max_concurrent_queries

系统级别

The maximum number of simultaneously processed requests.

`max_concurrent_queries_for_all_users` 的值必须小于`max_concurrent_queries`, 否则并发打满时， 系统账户（数据库管理员）无法进行查询工作。

query请求会保存在`list` 中，系统并发由`max_concurrent_queries`控制。如果系统并发数大于`max_concurrent_queries_for_all_users or max_concurrent_queries_for_user`, 则会抛出异常。

#### max_connections

系统级别

The maximum number of inbound connections. default 100.

#### max_bytes_before_external_group_by
外部聚合阈值
如果设置了该值，每当聚合计算中间处理结果的字节超过该值时，会将数据flush磁盘，以减少计算时的内存占用，避免内存不足导致内存不足或执行失败，带来的副作用是查询速度出现明显下降。
鉴于聚合计算的2步骤的实现机制，如果设置该值，建议将该值设置为可承受的单次最大内存（max_memory_usage）的一半大小，因为聚合计算对中间结果做处理的第二步同样会占用相当的内存。
#### max_bytes_before_external_sort
外部排序阈值
设定必须小于`max_memory_usage`。例如, if your server has `128 GB` of RAM and you need to run a single query, set `max_memory_usage` to `100 GB`, and max_bytes_before_external_sort to `80 GB`.
注意：如果设置，此值不宜过小

#### overflow_mode
资源溢出时，可以配置的策略
throw – Throw an exception (default).
break – Stop executing the query and return the partial result, as if the source data ran out.
any (only for group_by_overflow_mode) – Continuing aggregation for the keys that got into the set, but don’t add new keys to the set.

例如可以设置`max_rows_to_read = 1`. `read_overflow_mode = 'break'` vs `read_overflow_mode = 'throw'`

## cpu/thread
#### max_threads
This parameter applies to threads that perform the same stages of the query processing pipeline in parallel.
Default value: `the number of physical CPU cores`.

并行度越高，使用的内存越多，执行速度越快。

#### max_insert_threads
The maximum number of threads to execute the INSERT SELECT query.

#### os_thread_priority
Lower values mean higher priority. Default value: 0, range [-20, 19].
耗时较长的**非交互式**任务适合设置一个较大的值。

## 其他重要设置
#### max_columns_to_read
#### max_execution_time
#### max_partitions_per_insert_block
#### use_uncompressed_cache
#### background_pool_size
#### load_balancing
Specifies the algorithm of replicas selection that is used for distributed query processing

* Random (by default)
* Nearest hostname
* In order
* First or random
此算法选择集合中的第一个副本，如果第一个副本不可用，则选择一个随机副本。
* Round robin
轮询机制。i=(i+1) % n
注意： 优先选择错误数小的replica。

## Constraints
用户更改配置时需要`约束`资源大小。
```
<profiles>
  <default>
    <max_memory_usage>10000000000</max_memory_usage>
    <constraints>
      <max_memory_usage>
        <max>20000000000</max>
      </max_memory_usage>
    </constraints>
  </default>
</profiles>
```
如上配置， 如果设置`SET max_memory_usage=20000000001;`, 则会报错`Setting max_memory_usage should not be greater than 20000000000`

## Quotas
如果在时间间隔内超出限制，则会引发异常.

可以触发熔断的指标有
```
queries – The total number of requests.
errors – The number of queries that threw an exception.
result_rows – The total number of rows given as the result.
read_rows – The total number of source rows read from tables for running the query, on all remote servers.
execution_time – The total query execution time, in seconds (wall time).
```
例如配置
```
<statbox>
    <interval>
        <!-- 1 hour -->
        <duration>3600</duration>

        <queries>1000</queries>
        <errors>100</errors>
        <result_rows>1000000000</result_rows>
        <read_rows>100000000000</read_rows>
        <execution_time>900</execution_time>
    </interval>

    <interval>
        <!-- 1 day -->
        <duration>86400</duration>

        <queries>10000</queries>
        <errors>1000</errors>
        <result_rows>5000000000</result_rows>
        <read_rows>500000000000</read_rows>
        <execution_time>7200</execution_time>
    </interval>
</statbox>
```

## 小结
clickhouse query的特点为，peak memory要求高、peak threads要求多、执行时间短. 因而同时在线用户不宜过多,防止OOM。【目前我的理解】
1. clickhouse没有资源队列，因而必须合理设定memory.
2. 严格设定 `Constraints` 和 `Quotas`

-----------
# 实验
小注： 部分实验可能前后结论不一制，以后边的实验结论为主。

## 资源问题

设置资源如下
```
<max_memory_usage>100</max_memory_usage>
<max_threads>2</max_threads>
```

### memory
执行一个查询语句，则会报一下错误，说明memory的设定起了作用。
```
Query id: cebd5734-bb80-40a9-8676-b101b2161ee5 

Received exception from server (version 20.12.3):
Code: 241. DB::Exception: Received from localhost:9001. DB::Exception: Memory limit (for query) exceeded: would use 4.03 MiB (attempt to allocate chunk of 4221116 bytes), maximum: 100.00 B: While executing MergeTreeThread.

0 rows in set. Elapsed: 0.104 sec.

```

### thread
sql
```
select * from lineorder_shard order by LO_COMMITDATA desc limit 10
```
#### 场景一 max_threads=2
执行时间为： 230.284 s， 同时观察cpu利用率几乎不会超过200%
#### 场景二 max_threads=48
执行时间为： 13.767 s， 同时观察cpu利用率，瞬时利用率达4756%

### 小结
1. 租户（用户) 会根据配置设定 memory 和thread 最大使用量
2. 添加配置约束 constraints, 防止用户过度占用资源

## 用户权限问题
问题描述： 用户`app`读取分布式表的时候，在目标shard上的使用`default`读取（此问题与`系统派发的子查询会突破用户的资源规划，所有的子查询都属于default用户`类似，均是系统派发的查询问题）

在1号机器上建立分布式表 `lineorder_all`, 并执行查询语句
```
select count(*) from lineorder_all where LO_COMMITDATE='1992-04-05'
```

在1号机器上查询query_log
```
select memory_usage, length(thread_ids) as thread_nums, user, os_user, initial_user  from system.query_log where query_id='d3af5fc4-49f7-464d-b95a-0da0bfe79694'
```
结果显示为
```
┌─memory_usage─┬─thread_nums─┬─user─┬─os_user─┬─initial_user─┐
│            0 │           0 │ app  │ hadoop  │ app          │
│            0 │          82 │ app  │ hadoop  │ app          │
└──────────────┴─────────────┴──────┴─────────┴──────────────┘
```

在2号机器上查询query_log. 此时应使用`initial_query_id`代替`query_id`
```
select memory_usage, length(thread_ids) as thread_nums, user, os_user, initial_user  from system.query_log where initial_query_id='d3af5fc4-49f7-464d-b95a-0da0bfe79694'
```
结果显示为
```
┌─memory_usage─┬─thread_nums─┬─user─┬─os_user─┬─initial_user─┐
│            0 │           0 │ app  │ hadoop  │ app          │
│            0 │          85 │ app  │ hadoop  │ app          │
└──────────────┴─────────────┴──────┴─────────┴──────────────┘
```
在2号机器上运行的user依然是`app`

------------
补充实验：
继续验证 `系统派发的子查询权限问题`

在1号机器上使用用户`default`登录. 
执行`show tables`, `drop table xxx` 均可以作用用户`app`创建的表。

执行以下语句
```
SELECT avg(a.LO_TAX) FROM lineorder_4_bhj as JOIN lineorder_copier_shard_1v3_1p as b on a.LO_ORDERKEY=b.LO_ORDERKEY WHERE b.LO_QUANTITY GLOBAL IN ( SELECT LO_QUANTITY from lineorder_all ORDER BY LO_SUPPLYVOST DESC LIMIT 10)
```
查看`query_log`, 分别在1，2号机器运行以下语句
```
SELECT memory_usage, query, is_initial_query, user, initial_user from system.query_log WHERE initial_query_id='09d170f0-b6f1-4930-ad87-9cbd7c99a3d1 and type='QueryFinish' \G
```
在1号机器结果
```
memeory_usage:    179337087446 
query:            SELECT avg(a.LO_TAX) FROM lineorder_4_bhj as JOIN lineorder_copier_shard_1v3_1p as b on a.LO_ORDERKEY=b.LO_ORDERKEY WHERE b.LO_QUANTITY GLOBAL IN ( SELECT LO_QUANTITY from lineorder_all ORDER BY LO_SUPPLYVOST DESC LIMIT 10)
is_initial_query: 1 
user:             default 
initial_user:     default
```
在2号机器结果
```
memeory_usage:    110656416
query:            SELECT LO_QUANTITY FROM defalut.lineorder_shard ORDER BY LO_SUPPLYCOST DESC LIMIT 10
is_initial_query: 0
user:             app
initial_user:     default
```
可以看到在2号机器上运行sql(系统派发的sql)的用户为`app`, 并不是`default`.

### 小结
1. 用户创建的表并没有做隔离，不同用户可以直接访问表。
2. 系统派发的查询使用的用户名由config中的`<user>${user_name}</user>`决定（**在没有配置secret的情况下**）。

## 用户权限设置(通过user.xml 建立的用户)
问题: 默认情况下，不同`user`之间的表是可见的。如果是多租户情况下，显然是不满足要求的

解决方法：不用租户限定为不同的databases. 可以设置`allow_databases`
例如, 设定用户`app1`可访问的`database` 

```
<users>
    <app1>
        <!-- 限定可访问的命名空间 -->
        <allow_databases>
            <database>${database_name}</database>
            <!-- 更多database -->
        </allow_databases>
    </app1>
</users>
```
更多`profiles`设置可以参考：https://clickhouse.tech/docs/en/operations/settings/settings-users/#user-settings

更好的方式**通过sql 命令创建的用户，默认没有任何访问权限**

### 小结
1. 应该使用sql命令行创建user, 并设置roles、profiles等信息。
sql 语法：https://clickhouse.tech/docs/en/sql-reference/statements/



## 并发任务时内存竞争问题

对于并发任务超过系统资源限制时，当某个query申请内存失败，则会抛出异常 （不分区query的先后）。
https://github.com/ClickHouse/ClickHouse/blob/master/src/Common/MemoryTracker.cpp#L129

**只要内存申请失败，就会立刻抛出异常。**

## 系统派发的子查询用户问题

配置secure 后即可使用initial_user as current query user。

小注：secret 这个新的feature，目前的lts版本还不支持.

v20.10.3.30 加入的该feature, 由于该变更属于new feature所以并没有backport。到目前最新的lts版本v20.8.13.15-lts，包含该feature最新的stable版本是 v20.10.4.1-stable

参考：https://github.com/ClickHouse/ClickHouse/pull/13156



## 总结
1. clickhouse没有资源队列，因而必须合理设定memory.
2. 严格设定 `Constraints` 和 `Quotas`
3. 通过配置user的`profile`, 限定用户权限
4. ~~系统派发的子查询使用的用户为`集群配置的用户`，因此~~合理配置集群，防止资源越界。 建议标准是：一个业务对应一个逻辑集群。当配置secret时,query user 使用initial_user, 如果没有配置secret，则使用`集群配置的用户`。


## 参考
* https://clickhouse.tech/docs/en/operations/settings/
* https://help.aliyun.com/document_detail/178138.html?spm=a2c4g.11186623.6.603.281b217b3RewSe
* http://www.idataviz.com/doc/best_practices/high_performance/installation_configuration.html
* https://zhuanlan.zhihu.com/p/340012422
* https://www.cnblogs.com/zhoujinyi/p/12613026.html