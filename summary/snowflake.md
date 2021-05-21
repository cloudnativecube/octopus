论文《**The Snowflake Elastic Data Warehouse**》

 Snowflflake is a multi-tenant, transactional, secure, highly scalable and elasic system with full SQL support and built-in extensions for semi-structured and schema-less data.

key features of Snowflflake: extreme elasticity and availability, semi-structured and schema-less data, time travel, and end-to-end security.

A pure shared nothing architecture has an important drawback though: it tightly couples compute resources and storage resources, which leads to problems in certain scenarios.

**Heterogeneous Workload** 不一致的负载，有的是任务是io密集型，有的是计算密集型。

**Membership Changes** 节点数量发生变化，如节点故障下线、集群扩缩容，会导致数据重分布。



Compute is provided through Snowflake’s (proprietary) shared-nothing engine. Storage is provided through Amazon S3. To reduce net work traffic between compute nodes and storage nodes, each compute node caches some table data on local disk. Shared-nothing引擎提供计算，Amazon S3提供存储。计算节点把表数据缓存在本地磁盘上。

local disk is used exclusively for temporary data and caches, both of which are hot (suggesting the use of high-performance storage devices such as SSDs). 本地磁盘只用来存储临时数据和缓存，这些都是热数据。一旦缓存预热，性能将超过shared-nothing架构，我们称这种架构为**多集群、共享数据架构（multi-cluster, shared-data architecture）**。



## Architecture

三层架构：

**Data Storage** This layer uses Amazon S3 to store table data and query results.

**Virtual Warehouses** The “muscle” of the system. This layer handles query execution within elastic clusters of virtual machines, called virtual warehouses.

**Cloud Services** The “brain” of the system. This layer is a collection of services that manage virtual warehouses, queries, transactions, and all the metadata that goes around that: database schemas, access control information, encryption keys, usage statistics and so forth.

![image-20210513213423802](/Users/madianjun/Library/Application Support/typora-user-images/image-20210513213423802.png)

### Data Storage

We spent some time experimenting with S3 and found that while its performance could vary, its usability, high availability, and strong durability guarantees were hard to beat.

S3的性能略差，但是它的可用性、高可用性能力和强大的耐用性保证是难以匹敌的。与本地存储相比，S3的延迟更高一些，由于IO请求 CPU overhead也更高一些，特别是使用HTTPS时。但是S3的HTTP(S)是非常简单的。写文件时只能一次性写一个完整的文件，而不能追加；读文件时可以读文件中的一部分。

Tables are horizontally partitioned into large, immutable files which are equivalent to blocks or pages in a traditional database system. Within each file, the values of each attribute or column are grouped together and heavily compressed.  Each table file has a header which, among other metadata, contains the offsets of each column within the file. Because S3 allows GET requests over parts of files, queries only need to download the file headers and those columns they are interested in.

表被水平切分为大的不可变的文件。每个文件中的列是连续存储并压缩的。文件中有header，header里是元数据，元数据包含每个列的offset。请求文件时可以只下载文件的header以及需要的列。

S3上也会存储计算过程中的临时数据，以避免本地盘耗尽。

表的元数据中包含，表对应的S3文件、统计数据、事务日志等。元数据存储在事务性的KV数据库中，即metadata storage。

### Virtual Warehouses

Virtual Warehouse中的worker node就是EC2实例。用户不用关心一个VW中有多少个worker node，只需要指定VM的大小（X-Small to XX-Large）。

弹性与隔离性：

VM是纯粹的计算资源，当用户不需要执行查询时可以关闭所有的VW。

查询只能跑在一个VW内部，不能跨VW执行。当处理一个查询时，每个worker node创建一个woker进程提供服务，当查询结束时，该worker进程也消失。

一个用户可以同时运行多个VW，每个VW可以并发执行多个查询。每个VM可以访问相同的数据。

本地缓存与文件窃取：

每个worker node在本地盘上缓存S3数据，这些数据是文件header的数据，以及部分列的数据。

为了提高命中率，同时避免在一个VW内的多个worker node之间有冗余缓存，query optimizer根据文件名作一致性hash，把文件分散到work node上。一致性hash是lazy的：当worker node数量变化时，不会立即替换cache，而是当LRU替换策略执行时才去替换cache，这样就把cache更新的代价分摊到了多个查询请求上。

数据倾斜问题：有些节点可能执行得比较慢，解决方案是，当worker进程扫描完成它自己的文件集合时，它向其他worker进程请求更多的文件，如果其他worker进程发现自己还有未处理完的文件则向第一个worker进程发送文件的“处理权”（不是发送文件），然后第一个worker进程从S3上下载文件。这个过程叫“file stealing”。

执行引擎：

三个特点：列式、向量化、push-based。

列式：存储和执行都是列式的。

向量化：与MR相比，snowflake不会物化中间结果，而是以pipeline的方式批量计算上千行的列存数据。

push-based：与火山模型相比，上游operator把结果推给下游算子，而不是等下游算子拉数据。

### Cloud Services

包括：

- Authentication and access control
- Infrastructue manager
- Optimizer
- Transaction manager
- Security
- Metadata storage

Query Management and Optimization：

query在真正执行之前，包括这些处理步骤：parsing, object resolution, access control, and plan optimization.

Query optimizer是自顶向下的CBO优化。

最终的执行计划分发给所有的worker node。随着query的执行，Cloud Services持续跟踪query的执行状态，以收集性能指标和检测node故障。所有统计信息被存储起来，用于审计和性能分析。用户可以在UI上查看执行完成或正在执行的query的运行状况。

Concurrency Control：

Like most systems in this workload space, we decided to implement ACID transactions via Snapshot Isolation (SI).

Pruning：

在查询过程中定位数据，传统方式是使用B+树，它适合事务处理，但在snowflake中不适用，其缺点是：1.严重依赖随机访问；2.构建索引会增加存储空间和数据加载时间；3.用户需要显式创建索引，这与snowflake的“pure service”理念不合。

另外的解决方法就是使用pruning。 Unlike traditional indices, this metadata is usually orders of magnitude smaller than the actual data, resulting in a small storage overhead and fast access.

Pruning nicely matches the design principles of Snowflake:

- it does not rely on user input; 

- it scales well; 

- and it is easy to maintain. 

- What is more, it works well for sequential access of large chunks of data,

- and it adds little overhead to loading, query optimization, and query execution times.

Besides this *static* pruning, Snowflflake also performs *dynamic* pruning during execution（类似spark的DPP）.

## 4. FEATURE HIGHLIGHTS

### 4.1 Pure Software-as-a-Service Experience

用户接口：JDBC、ODBC、3rd tools and services、web browser. the UI allows not only SQL operations, but also gives access to the database catalog, user and system management, monitoring, usage information, and so forth. 

### 4.2 Continuous Availability

the expectations on modern SaaS systems, most of which are always-on, customer-facing applications with no (planned) downtime.

Snowflake offers continuous availability that meets these expectations. The two main technical features in this regard are fault resilience and online upgrades.

#### 4.2.1 Fault Resilience

Snowflake使用的S3存储跨越多个数据中心（即AZ）；元数据存储也是跨越多个AZ。Cloud services的其他服务由分散在多个AZ上的无状态节点组成，前端有一个LB在这些节点之间分发请求。

而VW不会跨AZ分布，这是为了避免在查询执行过程中产生的AZ之间的网络传输。

如果整个AZ不可用，那么该AZ中的所有查询将失败，用户需要在不同的AZ中重新创建VM。所有AZ故障是真正灾难性的，并且极为罕见，我们目前允许它发生，希望未来解决它。

#### 4.2.2 Online Upgrade

To perform a software upgrade, Snowflake first deploys the new version of the service alongside the previous version. The load balancer directs incoming calls to the appropriate version of Cloud Services. The Cloud Services of one version only talk to VWs of a matching version. As mentioned previously, both versions of Cloud Services share the same metadata store. What is more, VWs of different versions are able to share the same worker nodes and their respective caches. 

At the time of writing, we upgrade all services once per week. That means we release features and improvements on a weekly basis.

### 4.3 Semi-Structured and Schema-Less Data

#### 4.3.1 Post-relational Operations

#### 4.3.2 Columnar Storage and Processing

#### 4.3.3 Optimistic Conversion

#### 4.3.4 Performance

### 4.4 Time Travel and Cloning

### 4.5 Security

## 5. RELATED WORK

Redshift uses a classic shared-nothing architecture. Thus, while being scalable, adding or removing compute resources requires data redistribution. In contrast, Snowflflake’s multi-cluster, shared data architecture allows users to instantly scale up, scale down, or even pause compute independently from storage without data movement—including the ability to integrate data across isolated compute resources.