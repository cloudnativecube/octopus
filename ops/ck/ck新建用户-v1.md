从资源角度，新建业务线（新用户）步骤

# 配置原则

建议, **一个业务对应一个逻辑集群。**

原因是，clickhouse的资源管理没有层级关系。

 

新建业务线包括以下三个步骤：资源规划， 新建逻辑集群， 新建业务用户。其中资源规划属于初始化机器资源，一旦确立了配置参数，原则上不做频繁修改。资源规划完毕，后续新建业务线，进行后续2步即可。

 

# 第零步：资源规划（资源初始化）

这是一个资源利用率和资源超限的平衡问题。

定性分析：

**对于单个用户**

我们可以控制单条查询使用的最大内存（**max_memory_usage**），该用户总的内存使用量（**max_memory_usage_for_user**）和并发量 （**max_concurrent_queries_for_user**）。那么在单条查询不超过**max_memory_usage****，并且max_memory_usage_for_user** >= **max_memory_usage \* max_concurrent_queries_for_user** 的情况下，是一定不会OOM的**。**

 

**下面的例子将描述资源超卖在某些场景下可使资源利用率更大。**

**第一种情况：**

**为某个用户定义一种内存资源不超卖的配置：**

**max_memory_usage=50G**

**max_memory_usage_for_user=100G**

**max_concurrent_queries_for_user=2**

第1秒query1和query2都使用50G，第2秒都使用0G。

两个任务的内存使用量能够达到(50G+50G)\*1秒 = 100G\*秒。

 

**第二种情况：**

**为某个用户定义一种内存资源超卖的配置：**

**max_memory_usage=60G**

**max_memory_usage_for_user=100****G**

**max_concurrent_queries_for_user=2**

**也就是说，使max_memory_usage\*max_concurrent_queries_for_user超过max_memory_usage_for_user**

如果用户执行2个查询，2个查询的内存峰值错开，比如第1秒query1使用0G，query2使用60G,然后第2秒query1使用60G,query1使用0G。两个查询在任意时刻同时占用的内存都不超过100G，但两个任务的内存使用量能够达到60G\*1秒+60G\*1秒 = 120G\*秒。

 

**所以，超卖配置适合错峰调度的任务类型，可使内存利用率更高。如果不是错峰调度的任务类型，不要配置成超卖，否则会导致OOM。**



涉及ck的资源配置包含三个方面，clickhouse-server的资源管理、profile（对应业务用户）的资源管理和quotas（对应业务用户）

## clickhouse-server的资源管理

这部分的参数配置在${clickhouse-server}/config.d/${config}.xml

重点关注以下参数

**max_concurrent_queries**： 对于当前的server最大并发数

**max_server_memory_usage**： 对于当前的server最大使用内存数。默认值为0。如果此值为0， 则 max_server_memory_usage=max_server_memory_usage_to_ram_ratio * physical_RAM 

**max_server_memory_usage_to_ram_ratio**：内存使用比例。 在 max_server_memory_usage=0时生效。

 

## profile资源管理

在这部分关注的参数配置${clickhouse-server}/user.d/${user}.xml

重点关注参数：

**max_threads**：最大使用thread数量

**max_memory_usage**：单个query最大使用内存

**max_memory_usage_for_user**：当前用户使用的最大内存

**max_concurrent_queries_for_user**：当前用户的最大并发量。

Constraints：约束。必须配置，防止用户过度占用资源。

 

根据资源规划，profile 可以设置多个模板，添加用户时直接关联即可。

 

大多数限制还具有“overflow_mode”设置，表示超出限制时该怎么做，通常有以下值：

**throw** – Throw an exception (default).

**break** – Stop executing the query and return the partial result, as if the source data ran out.

**any** (only for group_by_overflow_mode) – Continuing aggregation for the keys that got into the set, but don’t add new keys to the set.

建议使用默认值，业务用户根据自己业务特点修改overflow_mode.

Mode 设置参考：https://clickhouse.tech/docs/en/operations/settings/query-complexity/#restrictions-on-query-complexity

## Quotas（熔断机制）

在这部分关注的参数配置${clickhouse-server}/users.d/${users}.xml

参数配置比较简单，不在这里赘述了。

 



如果在**现有逻辑集群上新建用户**，检查metrika.xml 中的是否非配置secret（确定版本是否支持这个feature）, 如果没有就配置secret。进入‘**第二步：新建业务用户**’

小注：secret 这个新的feature，目前的lts版本还不支持.

v20.10.3.30 加入的该feature, 由于该变更属于new feature所以并没有backport。到目前最新的lts版本v20.8.13.15-lts，包含该feature最新的stable版本是 v20.10.4.1-stable

 

# 第一步：新建逻辑集群

每个物理机器上的逻辑集群信息都会有些差异。我们会新建metrika.xml负责管理逻辑集群。${clickhouse-server}/config.d/${config}.xml 中的include_from控制metrika.xml的具体路径。 

Metrika.xml 包含以下重要参数：

clickhouse_remote_servers：（逻辑）集群信息。

macro：宏，复制表会使用到。每台机器上的值都不一样。

zookeeper-servers：zk 服务器配置。

clickhouse_compression：压缩算法。

 

根据业务用户需要配置集群，例如：2个shard2个replica的集群在clickhouse_remote_servers配置如下：

```xml
   <ck_cluster_${service_name}_2s2r>

      <!—如果配置secret, 那么在查询分布式表时，派发的子查询使用的用户为initial_user。 
       如果不配置secret， 则使用replica中配置的user-->

      <secret>${password}</secret>
      <shard>
        <internal_replication>true</internal_replication>
        <replica>
          <host>${host_name}</host>
          <port>${port}</port>
                <user>${user_name}</user>
                <password>${passwd}</password>
        </replica>
        <replica>
          <host>${host_name}</host>
          <port>${port}</port>
                <user>${user_name}</user>
                <password>${passwd}</password>
        </replica>
      </shard>
      <shard>
        <internal_replication>true</internal_replication>
        <replica>
          <host>${host_name}</host>
          <port>${port}</port>
                <user>${user_name}</user>
                <password>${passwd}</password>
        </replica>
        <replica>
          <host>${host_name}</host>
          <port>${port}</port>
                <user>${user_name}</user>
                <password>${passwd}</password>
        </replica>
      </shard>
    </ ck_cluster_${service_name}_2s2r >
```

 

**注意**此时user还没有真正创建，只是提前配置集群中。

# 第二步：新建业务用户

通过命令行添加用户，相关语法参考：https://clickhouse.tech/docs/en/sql-reference/statements/create/user/

在上一步的逻辑集群中新建用户，并且该用户关联profile， role等信息。

 

# 附录

[ck配置与实验](./ck配置与实验.md)