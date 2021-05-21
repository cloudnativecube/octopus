# Rockset Concepts, Design & Architecture

原文链接：https://rockset.com/whitepapers/rockset-concepts-designs-and-architecture/

## Data Model

Rockset stores data in a document data model. 

Rockset differs from typical document-oriented databases in that it indexes and stores data in a way that can support relational queries using SQL.

Collections allow you to manage a set of documents and can be compared to tables in the relational world. A set of collections is a workspace.

## Cloud-Native Architecture

- Use of shared storage rather than shared-nothing storage

- Disaggregated architecture

  tune the consumption of each of these hardware resources independently.

  a software service can be composed from a set of microservices

- Resource scheduling to manage both supply and demand

  根据负载状况实现动态调度

- Separation of durability and performance

  在非云环境中，replica既提高持久性（数据冗余），也提高查询性能，这两个收益是关联在一起的。但在计算存储分离环境下，持久性由对象存储保证，不需要replica；只有当需要提高查询并发量时，才创建更多replica，此时replica仅用于“提高性能”。

- Ability to leverage storage hierarchy

  热数据放在本地SSD，冷数据放在对象存储

### Aggregator-Leaf-Tailer Architecture

- Tailer

  Its job is to fetch new incoming data from a variety of data sources 

- Leaf
这是构建索引的引擎，它将Tailer获取的数据建立索引。索引类型包括：基于数据集字段的倒排索引、基于列索引和基于行索引。

- Aggregator

  aggregations of data coming from the leaves, be it columnar aggregations, joins, relevance sorting, or grouping.

Tailer、Leaf和Aggregator以离散的微服务方式运行，每个微服务都可以根据需要独立地伸缩。当需要摄取更多数据时，系统会扩展Tailers;当数据规模增长时，系统会扩展Leaves；当查询数量或复杂性增加时，系统会扩展aggregator。

![figure5](https://rockset.com/images/whitepapers/rockset-concepts-design-architecture-figure5.png)

### Separation of Storage and Compute

 All of RocksDB's persistent data is stored in a collection of SST (sorted string table) files in cloud storage.

将compaction的计算过程与存储分离，这是通过使用remote compactiaon来实现的。compaction任务在收到compaction请求后就放到无状态的RocksDB-Cloud服务器上。这些remote compaction server可以根据系统的负载自动伸缩。

### Independent Scaling Of Ingest And Query Compute

bulk load将导致动态增加更多的ingest compute，以确保ingest延迟被最小化；而查询激增可以通过分配更多的query compute来处理，以确保低查询延迟。

### Sharding And Replication

### Mutability Of The Index

Rockset is a mutable database. It allows you to update any existing record in your database, including individual fields of an existing deeply nested document.

传统的列存数据库也支持更新。但是，由于来自同一列的数百万个值是按列压缩的，并存储在一个压缩对象中，如果想更新一个压缩对象中间的一条记录，则必须对该对象执行写时复制。对象的大小通常为几百兆字节，如果在紧凑对象的中间更新100字节的记录会触发几百兆字节的写时复制，那么这样的系统只能维持偶尔的少量更新。其他的实现方式是，添加一个新分区来记录更新，然后在查询时将新分区和旧分区合并在一起。而Rockset的更新操作的代价更小。

## Schemaless Ingestion
### Overview Of Data Ingestion Flow

数据导入可以使用API方式或数据源方式。

当数据通过API进入时，被路由到API server。API server接收数据请求，执行权限检查，并将数据顺序写入分布式日志存储。然后，Leaf节点对数据建立索引。叶子是具有本地ssd的EC2机器，它们保存索引数据，这些数据可以提供查询。（写操作是“顺序”的，建立索引是异步的，查询操作作用于索引后的数据上）

繁重的写操作会影响读操作，因为我们想要很好地服务于操作分析查询，所以读操作需要快速。分布式日志存储区充当数据的中间暂存区，它存储的是未建立索引的数据。另一方面，它还提供数据持久性，直到数据被Leaf节点索引并持久化到S3为止。

Ingesters从数据源读取数据，在将数据写入日志存储之前，可以对数据执行转换。数据转换是Ingester的一部分，它允许删除或映射字段。

在bulk ingest的情况下，当大量数据被ingest时，数据被写入S3，而只是header被写入日志存储，这样就不会使日志存储成为内存瓶颈。

### Bulk Load

正常情况下，ingester worker序列化输入数据并将其直接写入log store。但是，如果输入数据集有几十GB，可能会对log store造成压力。在bulk load模式下，Rockset使用S3作为批量数据队列，而不是日志存储。相反，只有元数据被写到日志存储中。Leaf读取log store中的消息，检查消息的header，从消息体中或S3 object上找到document，并将其索引到RocksDB-Cloud中。bulk leaf会将数据作压缩，并将压缩后的数据转移到普通的leaf上。

## Converged Indexing（聚集索引）

###  Indexing Data In Real Time

聚合索引是一个实时的索引，它与多个数据源保持同步，并在不到一秒的时间内反映新数据。

传统上，维护数据库的动态索引是一项昂贵的操作，但Rockset使用了一种现代的云原生方法，采用分层存储和分散系统设计，使其在规模上更高效。倒排索引与其作为键值存储的物理表示分离，这与其他搜索索引机制非常不同。

我们的索引是完全可变的，因为每个键都指向一个文档片段——这意味着用户可以更新文档中的单个字段，而无需触发对整个文档的reindex。传统的搜索索引往往会导致reindex风暴，因为即使在一个20K文档中更新了一个100字节的字段，也会被迫reindex整个文档。

### Time-Series Data Optimizations

For time-series data, Rockset's *rolling window compaction* strategy allows you to set policies to only keep data from last “x” hours, days or weeks actively indexed and available for querying.

## Query Processing

3 main stages in Rockset:

- Planning

- Optimization
- Execution

When a query comes in it hits the Rockset API server and gets routed to an aggregator. The aggregator plans the query and routes various fragments of the plan to appropriate leaves that hold the data to serve this query. The results are routed back to this aggregator which then sends the results back to the API server. We introduce additional levels of aggregators to distribute the processing across multiple aggregators for queries that may make a single aggregator a memory/computation bottleneck.

![figure7](https://rockset.com/images/whitepapers/rockset-concepts-design-architecture-figure7.png)

### Query Planning

In the planning stage, a set of steps that need to be executed to complete the query is produced. This set of steps is called a **query plan**. The final query plan selected for execution is called the **execution plan.**

### Query Optimization

Rockset uses a Cost Based Optimizer (CBO) to pick an optimal execution query plan.

### Distributed Query Execution

The execution plan is simply a DAG of execution operators.

The execution plan is first divided into fragments. Each fragment comprises a chain of execution operators.

There are primarily 2 classes of fragments:

- Leaf fragments: These are fragments of the plan that would typically be associated with retrieving data from the underlying collection. Leaf fragments are dispatched to and executed **on leaf workers where shards of the collection reside**.

  Each of these leaf fragments can be executed in parallel offering shard-level parallelism.

- Aggregator fragments: These are fragments of the plan that would perform operations such as aggregations and joins on the data flowing from leaf fragments, and relay the final results to the API server. They are dispatched to and executed on aggregator workers.

## Application Development

## Security

### Use Of Cloud Infrastructure

Rockset uses cloud-native best practices and exploits the underlying security policies of the public cloud it is hosted on. (利用云厂商提供的安全策略)

### Data Masking

A field mapping allows you to specify transformations to be applied on all documents inserted into a collection. When a particular field is masked using a hashing function like SHA256, only the hashed information is stored in Rockset. 

### Role-based Access Control

### Advanced Encryption With User-controlled Keys

Rockset uses AWS Key Management Service to make it easy for you to create and manage keys and control the use of encryption.

### Data In Flight

Data in flight from customers to Rockset and from Rockset back to customers is encrypted via SSL/TLS certificates, which are created and managed by AWS Certificate Manager. 

Within Rockset’s Virtual Private Cloud (VPC), data is transmitted unencrypted between Rockset’s internal services. Unencrypted data will never be sent outside of Rockset’s VPC.

### Data At Rest

三个地方存储数据：

1.log buffer

2.leaf节点的本地ssd

3.s3

### Access Controls

