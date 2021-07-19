# CK文本搜索
## 目标
1. 提升CK的文本检索能力；

## 背景以及参考
1. ES的全文检索能力很强，但是CK这方面比较弱，调研下如何优化CK的文本检索性能；
1. 阿里云CK针对CK增加了二级索引，性能大幅提升，并且和ES做了对比：https://mp.weixin.qq.com/s/80qnWq2HOBNPd__WI5k0eg
1. tantivy是rust实现的全文搜索引擎，参考：https://github.com/tantivy-search/tantivy

## 测试数据集
### 1. access_log
```sql
CREATE TABLE access_log_local
(
  `sql` String,
  `schema` String,
  `type` String, 
  `access_ip` String, 
  `conn_id` UInt32, 
  `process_id` String, 
  `logic_ins_id` UInt32, 
  `accept_time` UInt64, 
  `_date` DateTime, 
  `total_time` UInt32, 
  `succeed` String, 
  `inst_name` String
) 
ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(_date)
ORDER BY (logic_ins_id, accept_time);

-- 无公共数据集，造数据，想契合下面的sql比较困难
INSERT INTO access_log_local
SELECT
    randomPrintableASCII(128) as sql,
    base64Encode(randomPrintableASCII(3)) as schema,
    base64Encode(randomPrintableASCII(1)) as type,
    IPv4NumToString(rand32(0)) as access_ip,
    rand32(1) as conn_id,
    randomPrintableASCII(3) as process_id,
    rand(1) as logic_ins_id,
    toDateTime('2020-01-01 00:00:00') + rand(2)%(3600*24*365) as accept_time,
    toDateTime(accept_time) as _date,
    rand(3)%10000 as total_time,
    toString(rand(4)%2) as succeed,
    base64Encode(randomPrintableASCII(3)) as inst_name
FROM numbers(10);

-- query sql
select _date, accept_time, access_ip, type, total_time, concat(toString(total_time),'ms') as total_time_ms, sql,schema,succeed,process_id,inst_name from access_log_local where _date >= '2020-12-27 00:38:31' and _date <= '2020-12-28 00:38:31' and logic_ins_id = 502680264 and accept_time <= 1609087111000 and accept_time >= 16090007311000 and positionCaseInsensitive(sql, 'select') > 0 order by accept_time desc limit 50,50;
```

### 2. ontime
2.1 CK的测试
准备数据集、导数、查询语句可参考[ck文档](https://clickhouse.tech/docs/en/getting-started/example-datasets/ontime/)

2.1 ES的测试：
```bash
curl -X PUT host:port/ontime?pretty -d "@create_es_index_ontime.json"
# create_es_index_ontime.json文件为建索引的语句
```
测试方式参考 test_es_index_ontime.sql

### 3. corpus: AOL query dataset
基于[tantivy bench](https://github.com/tantivy-search/search-benchmark-game)做的多个文本搜索引擎benchmark对比。  
1. 下载项目：`git clone https://github.com/tantivy-search/search-benchmark-game`
1. 由于这里只测试lucence与tantivy，所以修改Makefile里的`ENGINES`变量，只保留这两个；
1. 准备lucence编译环境：经过踩坑，推荐用JDK8和gradle 5.6.4，JDK11有些兼容性问题，具体步不再赘述；
1. 准备tantivy编译环境：安装rust：https://www.rust-lang.org/tools/install
1. 下载数据集:
    ```bash
    #从dropbox下载数据集，需梯子，文件2G，解压后7.7G
    make corpus
    ```
1. 测试：
    ```bash
    #生成索引文件
    make index
    #执行压测
    make bench
    #启动压测结果web服务
    make serve
    #打开浏览器查看结果
    open http://localhost:8080
    ```
1. 上面只是测试了tantivy的引擎，下面基于[社区修改版内嵌tantivy的clickhouse](https://github.com/NeowayLabs/ClickHouse/commits/fulltext-21.3)来测试：
    1. 首先ck编译就不说了；
    1. 上面的corpus数据集每条数据有两列：sting类型的ID，和string类型的text文本，由于tantivy现在的表只支持UInt64类型的两个id和一个String类型的body所以转换下
    ```sql
    CREATE TABLE corpus_origin
    (
      `id` String,
      `text` String,
    ) ENGINE MergeTree();
    tantivy('/var/lib/clickhouse/tantivy');

    --tantivy表：
    CREATE TABLE corpus
    (
        primary_id UInt64,
        secondary_id UInt64,
        body String
    )
    ENGINE = Tantivy('/var/lib/clickhouse/tantivy/corpus')
    ```
    1. 加载数据集
    ```bash
    # load data
    cat corpus.json | clickhouse-client -m -q "INSERT INTO corpus_origin FORMART JSONEachRow"
    ```
    ```sql
    select count() from corpus_origin;
    -- data transform and load into target table
    INSERT INTO corpus SELECT cityHash64(id) as primary_id, rand32(0) as secondary_id, text as body from corpus_origin;
    ```
    1. 测试
    ```
    clickhouse-client -m -q "SELECT count() from corpus WHERE tantivy('\"the\"');"
    ```

1. TODO：自动化benchmark
