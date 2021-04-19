# Star Schema Benchmark

## 参考文档

https://altinity.com/blog/clickhouse-nails-cost-efficiency-challenge-against-druid-rockset

## 测试方法

Original SSB 有四个表：一个事实表 lineorder 和三个维度表 customer、supplier、part。我们使用 SSB 的 dbgen 产生 600M 行测试数据（约 100GB），对 ClickHouse 进行了以下三种不同 schema 测试：

* Original SSB schema
* Flattened schema 
* 使用索引的 Flattened schema 以提高性能

SSB 有 13 个标准 SQL queries 来测试不同的场景。 测试时，首先执行一个 warm-up run，之后将每个 query 执行 3 次记录平均值。

测试脚本 https://github.com/Altinity/ssb

## 创建测试数据

生成数据工具：

https://github.com/cloudnativecube/ssb-dbgen/tree/master

master 分支为 ClickHouse 数据，hive 分支为 hive 数据。

如 lineorder 表产生 600,000,000 行数据：

```
dbgen -s 100 -T l
```

## Original SSB schema

### 创建测试表

1. Schema ddl

```
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS ssb"
```

```
CREATE TABLE ssb.lineorder
(
    `LO_ORDERKEY` UInt32,
    `LO_LINENUMBER` UInt8,
    `LO_CUSTKEY` UInt32 CODEC(T64, LZ4),
    `LO_PARTKEY` UInt32 CODEC(T64, LZ4),
    `LO_SUPPKEY` UInt32 CODEC(T64, LZ4),
    `LO_ORDERDATE` Date CODEC(T64, LZ4),
    `LO_ORDERPRIORITY` LowCardinality(String) CODEC(ZSTD(1)),
    `LO_SHIPPRIORITY` UInt8,
    `LO_QUANTITY` UInt8 CODEC(ZSTD(1)),
    `LO_EXTENDEDPRICE` UInt32 CODEC(T64, LZ4),
    `LO_ORDTOTALPRICE` UInt32 CODEC(T64, LZ4),
    `LO_DISCOUNT` UInt8 CODEC(ZSTD(1)),
    `LO_REVENUE` UInt32 CODEC(T64, LZ4),
    `LO_SUPPLYCOST` UInt32 CODEC(T64, LZ4),
    `LO_TAX` UInt8 CODEC(ZSTD(1)),
    `LO_COMMITDATE` Date CODEC(T64, LZ4),
    `LO_SHIPMODE` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(LO_ORDERDATE)
ORDER BY (LO_SUPPKEY, LO_ORDERDATE)
SETTINGS index_granularity = 8192;
```

```
CREATE TABLE ssb.customer
(
    `C_CUSTKEY` UInt32,
    `C_NAME` String,
    `C_ADDRESS` String,
    `C_CITY` LowCardinality(String),
    `C_NATION` LowCardinality(String),
    `C_REGION` LowCardinality(String),
    `C_PHONE` String,
    `C_MKTSEGMENT` LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY C_CUSTKEY
SETTINGS index_granularity = 8192;
```

```
CREATE TABLE ssb.part
(
    `P_PARTKEY` UInt32,
    `P_NAME` String,
    `P_MFGR` LowCardinality(String),
    `P_CATEGORY` LowCardinality(String),
    `P_BRAND` LowCardinality(String),
    `P_COLOR` LowCardinality(String),
    `P_TYPE` LowCardinality(String),
    `P_SIZE` UInt8,
    `P_CONTAINER` LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY P_PARTKEY
SETTINGS index_granularity = 8192;
```

```
CREATE TABLE ssb.supplier
(
    `S_SUPPKEY` UInt32,
    `S_NAME` String,
    `S_ADDRESS` String,
    `S_CITY` LowCardinality(String),
    `S_NATION` LowCardinality(String),
    `S_REGION` LowCardinality(String),
    `S_PHONE` String
)
ENGINE = MergeTree
ORDER BY S_SUPPKEY
SETTINGS index_granularity = 8192;
```

2. 导入数据

```
clickhouse-client --query "INSERT INTO ssb.customer FORMAT CSV" --format_csv_delimiter="," < customer.tbl
clickhouse-client --query "INSERT INTO ssb.part FORMAT CSV" --format_csv_delimiter="," < part.tbl
clickhouse-client --query "INSERT INTO ssb.supplier FORMAT CSV" --format_csv_delimiter="," < supplier.tbl
clickhouse-client --query "INSERT INTO ssb.lineorder FORMAT CSV" --format_csv_delimiter="," --max_insert_block_size="300000" < lineorder.tbl
```

### 执行测试

```
TRIES=3 CH_CLIENT=clickhouse-client CH_HOST=localhost CH_USER=default CH_PASS= CH_DB=ssb QUERIES_DIR=original/queries ./bench.sh
```

## Flattened (denormalized) schema

将四个表合成一个表 lineorder_wide。

### 创建测试表 lineorder_wide

1. Schema ddl

```
CREATE TABLE ssb.lineorder_wide
(
    `LO_ORDERKEY` UInt32,
    `LO_LINENUMBER` UInt8,
    `LO_CUSTKEY` UInt32,
    `LO_PARTKEY` UInt32,
    `LO_SUPPKEY` UInt32,
    `LO_ORDERDATE` Date,
    `LO_ORDERPRIORITY` LowCardinality(String),
    `LO_SHIPPRIORITY` UInt8,
    `LO_QUANTITY` UInt8,
    `LO_EXTENDEDPRICE` UInt32,
    `LO_ORDTOTALPRICE` UInt32,
    `LO_DISCOUNT` UInt8,
    `LO_REVENUE` UInt32,
    `LO_SUPPLYCOST` UInt32,
    `LO_TAX` UInt8,
    `LO_COMMITDATE` Date,
    `LO_SHIPMODE` LowCardinality(String),
    `C_CUSTKEY` UInt32,
    `C_NAME` String,
    `C_ADDRESS` String,
    `C_CITY` LowCardinality(String),
    `C_NATION` LowCardinality(String),
    `C_REGION` Enum8('ASIA' = 0, 'AMERICA' = 1, 'AFRICA' = 2, 'EUROPE' = 3, 'MIDDLE EAST' = 4),
    `C_PHONE` String,
    `C_MKTSEGMENT` LowCardinality(String),
    `S_SUPPKEY` UInt32,
    `S_NAME` LowCardinality(String),
    `S_ADDRESS` LowCardinality(String),
    `S_CITY` LowCardinality(String),
    `S_NATION` String,
    `S_REGION` Enum8('ASIA' = 0, 'AMERICA' = 1, 'AFRICA' = 2, 'EUROPE' = 3, 'MIDDLE EAST' = 4),
    `S_PHONE` LowCardinality(String),
    `P_PARTKEY` UInt32,
    `P_NAME` LowCardinality(String),
    `P_MFGR` Enum8('MFGR#2' = 0, 'MFGR#4' = 1, 'MFGR#5' = 2, 'MFGR#3' = 3, 'MFGR#1' = 4),
    `P_CATEGORY` String,
    `P_BRAND` LowCardinality(String),
    `P_COLOR` LowCardinality(String),
    `P_TYPE` LowCardinality(String),
    `P_SIZE` UInt8,
    `P_CONTAINER` LowCardinality(String)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(LO_ORDERDATE)
PRIMARY KEY (S_REGION, C_REGION, P_MFGR, S_NATION, C_NATION, P_CATEGORY)
ORDER BY    (S_REGION, C_REGION, P_MFGR, S_NATION, C_NATION, P_CATEGORY, LO_CUSTKEY, LO_SUPPKEY)
SETTINGS index_granularity = 8192
;
```

注意：为了提高性能，建表时 ORDER BY 做了如下调整：

```
ORDER BY (S_REGION, C_REGION, P_MFGR, S_NATION, C_NATION, P_CATEGORY, LO_CUSTKEY, LO_SUPPKEY)
```

2. 导入数据

```
SET min_insert_block_size_bytes = '1G', min_insert_block_size_rows = 1048576, max_insert_threads = 16, max_threads = 16;

INSERT INTO ssb.lineorder_wide
SELECT * 
  FROM ssb.lineorder LO
  LEFT OUTER JOIN ssb.customer C ON (C_CUSTKEY = LO_CUSTKEY)
  LEFT OUTER JOIN ssb.supplier S ON (S_SUPPKEY = LO_SUPPKEY)
  LEFT OUTER JOIN ssb.part P ON (P_PARTKEY = LO_PARTKEY)
;
```

### 执行测试

说明：测试所用的 Queries 中删除了 JOINS，其它未做改动。

```
TRIES=3 CH_CLIENT=clickhouse-client CH_HOST=localhost CH_USER=default CH_PASS= CH_DB=ssb QUERIES_DIR=flattened/queries ./bench.sh
```

Flattened schema 牺牲了存储换取了查询性能的提升。

## Data Skipping Indexes

ClickHouse 的 data skipping indexes 有助于用 WHERE 语句跳过大片不满足条件的数据，从而减少查询从磁盘读取的数据量。

### 创建 index

Q2.2 和 Q2.3 都在 WHERE 语句中使用了 P_BRAND。我们使用 data skipping indexes 来对此提高性能。

```
ALTER TABLE lineorder_wide add INDEX p_brand P_BRAND TYPE minmax GRANULARITY 4; 
ALTER TABLE lineorder_wide MATERIALIZE INDEX p_brand;
```

Q3.3 和 Q3.4 都在 WHERE 语句中使用了 S_CITY 和 C_CITY。同样的，我们也做如下优化。

```
ALTER TABLE lineorder_wide add INDEX s_city S_CITY TYPE set(0) GRANULARITY 35;
ALTER TABLE lineorder_wide MATERIALIZE INDEX s_city;
ALTER TABLE lineorder_wide add INDEX c_city C_CITY TYPE set(0) GRANULARITY 7;
ALTER TABLE lineorder_wide MATERIALIZE INDEX c_city;
```

### 执行测试

```
TRIES=3 CH_CLIENT=clickhouse-client CH_HOST=localhost CH_USER=default CH_PASS= CH_DB=ssb QUERIES_DIR=flattened/queries ./bench.sh
```

测试结果显示以上 queries 查询性能都有大幅提升。

