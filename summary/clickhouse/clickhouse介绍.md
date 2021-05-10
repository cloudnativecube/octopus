



# 架构

![image-20210225143301655](/Users/madianjun/Library/Application Support/typora-user-images/image-20210225143301655.png)

## 表引擎

### MergeTree

适用于高负载任务的最通用和功能最强大的表引擎。这些引擎的共同特点是可以快速插入数据并进行后续的后台数据处理。 MergeTree系列引擎支持数据复制（使用`Replicated*`的引擎版本）、分区和其他功能。

该类型的引擎：
\- MergeTree：按key作排序，底层文件定期合并
\- ReplacingMergeTree：对具有相同key的记录只保留最后一个
\- SummingMergeTree：对metric字段求和
\- AggregatingMergeTree：对metric字段作聚合
\- CollapsingMergeTree：对指定key的记录执行删除或更新操作
\- 其他

![image-20210225141820832](/Users/madianjun/Library/Application Support/typora-user-images/image-20210225141820832.png)

### 日志

具有最小功能的轻量级引擎。当您需要快速写入许多小表（最多约100万行）并在以后整体读取它们时，该类型的引擎是最有效的。

该类型的引擎：

- TinyLog
- StripeLog
- Log

### 集成引擎

用于与其他的数据存储与处理系统集成的引擎。
该类型的引擎：

- Kafka
- MySQL
- ODBC
- JDBC
- HDFS

### 用于其他特定功能的引擎

- Distributed
- 其他

# 用户接口

1. command line client
2. tcp、http、mysql
3. jdbc、odbc（clickhouse-jdbc）
4. 3rd-party library

# 用户管理

### 权限管理

支持RBAC权限控制。

### 资源管理

- Profile：作用类似于用户角色，可以为每组profile定义不同的配置项，限制资源的使用。

- Quota：限制该用户一段时间内的资源使用，即对一段时间内运行的一组查询施加限制，而不是限制单个查询。

- User：一个新用户必须包含以下几项属性：用户名、密码、访问ip、数据库、表等等。它还可以应用上面的profile、quota。

# 优缺点

## 优点

1. 完备的DBMS功能

- DDL
- DML
- 权限控制
- 数据备份与恢复
- 分布式管理

2. 列式存储与数据压缩

3. 向量化引擎关系模型与SQL查询

4. 多样化的表引擎

5. 多线程与分布式

6. 多主架构

7. 在线查询

8. 数据分片与分布式查询

## 缺点

1. 事务

   适合OLAP场景，不支持事务（社区已经有相关roadmap）。

2. 数据更新

   缺少高频率，低延迟的修改或删除已存在数据的能力。仅能用于批量删除或修改数据。

3. 点查询

   稀疏索引使得ClickHouse不适合通过其键检索单行的点查询

4. 分布式管控

   没有统一的协调服务，运维成本较高，如配置的变更、扩缩节点时数据无法自动rebalance。（社区目前正在开发相关功能）

5. 计算引擎

   适合宽表模型，不合适星型模型、雪花模型。虽然 ClickHouse 在单表性能方面表现非常出色，但是在复杂场景仍有不足，缺乏成熟的 MPP 计算引擎和执行优化器，例如：多表关联查询、复杂嵌套子查询等场景下查询性能一般，需要人工优化；缺乏 UDF 等能力，在复杂需求下扩展能力较弱等。

6. 高并发

   Clickhouse快是因为采用了并行处理机制，即使一个查询，也会用服务器一半的cpu去执行，所以ClickHouse不能支持高并发的使用场景，默认单查询使用cpu核数为服务器核数的一半。

7. 实时写入

   不适合实时写入。尽量做1000条以上批量的写入，避免逐行insert或小批量的insert，update，delete操作，因为ClickHouse底层会不断的做异步的数据合并，会影响查询性能，这个在做实时数据写入的时候要尽量避开。

# 适用场景

### 用户行为分析系统

行为分析系统的表可以打成一个大的宽表形式，join 的形式相对少一点，可以实现路径分析、漏斗分析、路径转化等功能

### BI报表

结合clickhouse的实时查询功能，可以实时的做一些需要及时产出的灵活BI报表需求，包括并成功应用于留存分析、用户增长、广告营销等

### 监控系统

视频播放质量、CDN质量，系统服务报错信息等指标，也可以接入ClickHouse，结合Kibana实现监控大盘功能

### ABtest

其高效的存储性能以及丰富的数据聚合函数成为实验效果分析的不二选择。离线和实时整合后的用户命中的实验分组对应的行为日志数据最终都导入了clickhouse，用于计算用户对应实验的一些埋点指标数据（主要包括pv、uv）。

业界可以参考：https://www.jianshu.com/p/79d31a72978f（Athena-贝壳流量实验平台设计与实践）

### 特征分析

使用Clickhouse针对大数据量的数据进行聚合计算来提取特征

# 导数工具

waterdrop

# 备份工具

clickhouse-copier

