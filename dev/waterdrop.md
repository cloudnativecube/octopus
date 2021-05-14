# waterdrop开发文档

[TOC]

## 简介

- 本文档主要包含自研的定制化插件，是基于waterdrop开源2.0.4版本进行开发，完整的配置手册可参考官方文档：https://interestinglab.github.io/waterdrop-docs/#/zh-cn/v2/spark/configuration/
- waterdrop自己的参数名都是“小写字母+下划线”的格式，如pre_sql、bulk_size。
- plugin的参数名一般使用plugin名字作为前缀，后面拼接plugin自己的参数名，如clickhouse.socket_timeout，其中socket_timeout是clickhouse自己的参数。但是es自己的参数本来就是以es作为前缀了，如es.batch.size.entries，直接使用即可。

## source plugin

### 1.hdfs

主要用于支持cknative插件，用于快速的数据写入，该插件只将path下的文件路径封装成Dataframe，无其他处理。

#### 配置参数

| name         | type   | required | default value | 备注                                                         |
| ------------ | ------ | -------- | ------------- | ------------------------------------------------------------ |
| path         | string | yes      | -             | hdfs文件路径                                                 |
| parent_regex | string | no       | -             | 用于过滤文件的正则表达式，会针对path下的具体文件路径的父目录进行过滤，具体用法详见下文 |

**parent_regex**

正则表达式，如果想指定某些年份或者月份的分区路径，可以通过设置该值来批量选择数据，参考配置：

```
path="/user/hive/warehouse/test.db/test_table"
parent_regex="(.*?)dt=2018\\d{2}"
```

#### 配置示例

```
source {
    hdfs {
        result_table_name = "accesslog"
        path = "/user/hive/warehouse/tpcds_bin_partitioned_orc_5.db/catalog_sales/"
        parent_regex="(.*?)dt=2018\\d{2}"
    }
}
```



## sink plugin 

### 1.hbase

#### 配置参数

| name               | type    | required | default value | 备注              |
| ------------------ | ------- | -------- | ------------- | ----------------- |
| load_mode          | string  | no       | bulkload      |                   |
| create_table       | boolean | no       | false         |                   |
| hbase_table_name   | string  | yes      | -             | bulkload方式需要  |
| staging_dir        | string  | yes      | -             | bulkload方式需要  |
| table_catalog_file | string  | yes      | -             | dataframe方式需要 |
| regions            | number  | yes      | -             | dataframe方式需要 |

**load_mode**

可选值是“bulkload”、“dataframe”。

**create_table**

是否自动创建表。如果是true，则删除原来的表并创建新表；如果是false，当已经存在该表时将报错。

实现方式：

(1) dataframe方式：如果设置regions大于3，则hbase-connector根据HBaseTableCatalog.newTable判断大于3，会自动创建新表。

(2) bulkload方式：

**hbase_table_name**

bulkload方式时，加载数据到hbase的表的名字。

**staging_dir**

bulkload方式时，产生的HFile所在的目录。该目录不能是已经存在的目录。

**table_catalog_file**

dataframe方式时，映射到hbase表的catalog所在的文件。

**regions**

dataframe方式时，指定的region的数量。如果该值大于3，则创建新的HBase表。

#### 配置示例

```
output {
  hbase {
    hbase.zookeeper.quorum = "centos01:2181,centos02:2181,centos03:2181"
    load_mode = "bulkload"
    create_table = true
    hbase_table_name = "table1"
    staging_dir = "/tmp/waterdrop/hfiles/20201030_101010"
  }
}
```

### 2.hive

根据是否配置overwrite_partition(优先级最高)分为两大部分:

(1)不配置overwrite_partition，即操作对象是整个表。

(2)配置overwrite_partition，即操作对象是分区文件。

配置overwrite_partition时，根据表达式中的"="号来区分动态还是静态，静态和动静态混合的两种情况要保证表的存在。

#### env配置

**注意：与hive相关的插件须在env中添加如下配置：**

```
env {
  ...
  spark.sql.catalogImplementation = "hive"
  ...
}
```

#### 配置参数

|        name         | type   | required | default_value | 备注 |
| :-----------------: | ------ | -------- | :-----------: | :--: |
|      database       | String | yes      |       -       |      |
|     table_name      | String | yes      |       -       |      |
|       format        | String | no       |       -       |      |
|      save_mode      | String | no       |     error     |      |
|    partition_by     | String | no       |       -       |      |
| overwrite_partition | String | no       |       -       |      |

**database**

数据库名。

**table_name**

表名。

**format (合法值："orc","parquet")**

指定文件存储格式。

1.配置非合法值时，将报错提示合法值；

2.save_mode="append"并且表存在时：format必须与原表一致，不一致会报错提示

3.overwrite_partition被配置后，format必须与原表一致，不一致会报错提示

**save_mode (合法值："overwrite","append","error")**

数据写入方式 。

1.配置非合法值时，将报错提示合法值；

2.partition_by被配置后：

表存在时：

(1)error，报错提示配置合法的值；

(2)overwrite，会覆盖原表

表不存在时：

(1)error和append，报错提示配置"overwrite"；

(2)overwrite，会自动建表；

3.overwrite_partition被配置后，save_mode必须为"overwrite"

**partition_by**

分区字段。

1.save_mode="overwrite"且表不存在需要创建新表时：指定分区；

2.save_mode="append"时：partition_by必须原表一致

**overwrite_partition**

覆盖分区，是操作表或者分区的标识（优先级最高）。

分为动态覆盖、静态覆盖、动静混合分区覆盖，取决于配置参数表达式中的“=”；

配置overwrite_partition ，程序即认定为覆盖分区操作，即只操作分区，不再操作整个表。

配置overwrite_partition 时，需按照分区目录级别排列表达式。

例如：原表分区字段为(year,month)，正确示例：(year,month)，错误示例：(month,year)，即不能篡改分区字段顺序

**1.动态**：(year,month)

根据插入的数据去覆盖分区，分区不存在的数据会自动新建分区，插入数据。

**2.静态：**(year=2020,month=11)

将所有的数据覆盖到此分区上。

**注意：不能包含不属于此分区的数据，否则会忽略数据中的分区字段，将不属于此分区的数据也写入此分区

**3.混合：**(year=2020,month)

在静态指定的分区下，动态覆盖。

静态属性必须靠左，正确示例：（year=2020,month），错误示例：（year,month=11）。

**注意：不能包含不属于此静态指定分区的数据，否则会忽略数据中的分区字段，将不属于此静态分区的数据也写入分区**

#### 配置示例

```
hive {
    database="dev"
    table_name="hive_table_source"
    save_mode="overwrite"   #'overwrite'、'append'、'error'
    format="parquet"        #'parquet'、'orc'
    partition_by="year,month"		
    overwrite_partition="year,month" #三种情况示例见上面描述即可
}
```

### 3.clickhouse

clickhouse插件在waterdrop2.0.4的基础上进行了修改，增加了以下功能：

1.自动建表功能，目前支持自动建分布式表+复制表（新增了建表所需的参数），其他表引擎也可以通过create_clause_local语句指定要执行的建表语句；

2.增加save_mode，防止数据覆盖；

3.数据写入时先通过临时表，校验数据完整性后再attach到结果table，临时表建在waterdrop库，需要事先建好该库，且使用的user有权限写入waterdrop库及读取system库相关表的权限(system.clusters、system.tables、system.parts)。

另需要修改部分clickhouse参数：

1.配置zookeeper集群来支持复制表的数据同步及分布式DDL；

2.由于数据先写入临时表后再迁移至目标表，涉及到分区数据的移动，如果单个分区的数据量较大，需要修改max_partition_size_to_drop的值(大于单个分区的最大数据量，如在config.xml中添加<max_partition_size_to_drop>2000000000000</max_partition_size_to_drop>，表示允许删除的分区size的上限为2T)

#### 配置参数

| name                   | type   | required                  | default value | 备注                                                         |
| ---------------------- | ------ | ------------------------- | ------------- | :----------------------------------------------------------- |
| host                   | string | yes                       | -             | 多个host配置方式为：host1:port,host2:port...，该方式为clickhouse-jdbc的UrlParser支持的配置，每次获取连接getConnection()时会随机使用一个host； |
| database               | string | yes                       | -             |                                                              |
| table                  | string | yes                       | -             |                                                              |
| username               | string | no                        | -             | 忽略时clickhouse-jdbc会使用default用户                       |
| password               | string | no                        | -             |                                                              |
| bulk_size              | number | no                        | 20000         | 每批写入的数据量                                             |
| retry                  | number | no                        | 3             |                                                              |
| retry_codes            | array  | no                        | []            | 需要重试的clickhouse错误码，注意如果在retry配置的重试次数后依然没有成功，将丢弃该批次数据，不会抛异常；如果不配置该字段，遇到异常会抛出异常，spark会重跑失败的task，注意此时可能有数据重复的问题。 |
| fields                 | array  | no                        | -             | 需要输出到ClickHouse的数据字段，即可以过滤source中不需要的字段，指定该字段时处理逻辑分为几种情况，见下文fields字段详解 |
| cluster                | string | no(required in some case) | -             | 若需要自动建表，当默认自动建分布式表+复制表时，**此时cluster是required**；其他情况若配置了cluster，会自动获取cluster对应的hosts，进行数据分发写入及overwrite模式下的truncate等操作，此时host参数仅用来连接集群获取集群的hosts信息； |
| save_mode              | string | no                        | "append"      | 表已存在时的写入模式："error"-报错；"overwrite"-覆盖；"append"-追加 |
| create_clause_local    | string | no                        | -             | **自动建表参数**（以下所有自动建表参数均只在table不存在时才会涉及），create_clause_local的值是一条完整的create table sql，该参数主要用来支持用户自定义建表语句，能更灵活的指定字段及适合的引擎，具体用法见下文 |
| order_keys             | array  | no(required in some case) | -             | **自动建表参数**，如果用户没有使用create_clause_local建表语句建表，本插件也可自动生成建表语句（目前默认建分布式表+复制表），**此时order_keys为required** |
| nullable_fields        | array  | no                        | []            | **自动建表参数**，指定类型为Nullable的列                     |
| low_cardinality_fields | array  | no                        | []            | **自动建表参数**，指定类型为LowCardinality的列               |
| partition_expr         | array  | no                        | -             | **自动建表参数**，指定分区表达式                             |
| settings               | string | no                        | -             | 自动建表参数，指定settings，如storage_policy等               |

**table**

输出的clickhouse表名，分以下两种处理逻辑：

1.表已存在时：

​    a）如table为本地表，且host参数配置为多个host时（也可指定cluster），数据会随机分布在多个host上（推荐此种方式）；

​    b）如为分布式表，会解析分布式表对应的cluster参数获取本地表的host，然后随机写入本地表，**注意此时分布式表配置的分片规则无效，会随机分片**；

2.表不存在时，支持自动建表：

​    a）默认使用ReplicatedMergeTree引擎建表，表名为table的值，结合order_keys、partition_expr等参数生成建表语句，并自动创建一个分布式表（分布式表名添加后缀，格式为：table+"_all"），此时会通过cluster参数获取需要创建table的全部shard的host信息，数据会随机写入多个shard；

​    b）如果需要使用其他引擎或需要指定更丰富的建表参数（除PARTITION BY和ORDER BY之外其他的建表参数），可以使用create_clause_local来指定建表语句，此时不会自动创建分布式表。

**fields**

需要输出到ClickHouse的数据字段，即可以过滤数据中不需要的字段，该字段处理逻辑分为以下几种情况：

1.对于已存在的表：

​    a）需要检查每个field是否在表中存在，如不存在，在checkConfig阶段返回校验失败；

​    b）需要检查每个field在表中对应的数据类型本插件是否支持（详见支持的数据类型表），如不支持，在checkConfig阶段返回校验失败；

​    c）对于clickhouse中存在但数据源中不存在的field，赋给该数据类型的clickhouse默认值；

​    d）如忽略该字段，会自动根据数据源的Schema适配，如果数据源的字段跟已存在的表字段不匹配，是在output阶段直接报错，checkConfig阶段不会检查字段是否符合要求；

2.对于表不存在，需要自动创建时：

​    a）会在数据源中过滤，只保留数据源和fields字段的交集字段来创建新表，其他字段均忽略，如遇数据源的数据格式本插件不支持时，会在output阶段生成建表语句时抛UnsupportedException异常；

​    b）如忽略该字段，会自动根据数据源的Schema适配，其他逻辑同上；

**create_clause_local**

create_clause_local主要用来支持用户自定义建表语句，主要用法如下：

​    1.建表语句里支持通过配置%fields变量来替换字段名称和类型，用法为："CREATE TABLE test_table ( %fields ) ENGINE = ReplicatedMergeTree ......"，此时nullable_fields及low_cardinality_fields参数如有配置，也会转换成相应的格式；

​    2.建表语句若包含on cluster语法，会在指定集群的host上都新建该表，此时用户无需指定cluster参数或者多个host，也会自动创建多个表；

​    3.如果没有使用on cluster语法，仍按解析host和cluster参数的方式（即cluster为主，host为辅），获取具体的host节点，分别执行建表；

​    4.另外此参数一般用来建本地表，且表名与table一致，否则执行到数据写入操作时，仍会报表不存在的错误，查询时如需使用分布式表需要另行创建；

#### 支持的数据类型

| clickhouse数据类型 | 对应的spark-sql数据类型 | 备注                                                         |
| ------------------ | ----------------------- | ------------------------------------------------------------ |
| Int8               | ByteType                |                                                              |
| Int16              | ShortType               |                                                              |
| Int32              | IntegerType             |                                                              |
| Int64              | LongType                |                                                              |
| Float32            | FloatType               |                                                              |
| Float64            | DoubleType              |                                                              |
| UInt8              | BooleanType             | clickhouse支持多种长度无符号数，如UInt16，UInt32等，目前自动建表时普通的数值类型不支持自动转换无符号数，会使用上面列出的(Int.*)这种类型，但手动建表字段类型如使用了无符号数，可以正常写入。 |
| String             | StringType              |                                                              |
| String             | BinaryType              |                                                              |
| Date               | DateType                | yyyy-MM-dd 格式                                              |
| DateTime           | TimestampType           | yyyy-MM-dd HH:mm:ss 格式                                     |
| Decimal            | DecimalType             |                                                              |
| Array(T)           | ArrayType               | Array不可以为NULL，源数据为NULL时会写入默认值，即空数组[]，但Array里的元素T可以为Nullable以及LowCardinality类型。 |
| Nullable(T)        | -                       | clickhouse中普通的类型不可以为NULL，遇到NULL会赋默认值，如果要保留NULL值，需要配置nullable_fields参数指定使用Nullable类型的列，注意T不可为Array和LowCardinality类型。 |
| LowCardinality(T)  | -                       | T不可为Decimal和Array类型，另外UIntX/IntX这样的数值类型是否支持指定LowCardinality取决于clickhouse集群的配置（set allow_suspicious_low_cardinality_types=1，不推荐使用该配置，会影响8字节以内的数据类型的处理效率）。 |

关于Array，Nullable以及LowCardinality类型的封装顺序为：

1.源数据为ArrayType类型=>转换为Clickhouse的Array(T)=>判断low_cardinality_fields参数是否包含该列=>判断nullable参数是否包含该列，最终Array类型生成的嵌套格式有如下几种情况：
```scala
Array(LowCardinality(Nullable(T)))
Array(LowCardinality(T))
Array(Nullable(T))
Array(T)
```

2.源数据为DecimalType类型=>转换为Clickhouse的Decimal=>判断nullable参数是否包含该列，最终生成的格式如下：
```scala
Nullable(Decimal(precision, scale))
Decimal(precision, scale)
```
3.其他数据类型=>转换为Clickhouse对应的类型=>判断low_cardinality_fields参数是否包含该列=>判断nullable参数是否包含该列，最终生成的数据格式有如下几种情况：

```scala
LowCardinality(Nullable(T))
LowCardinality(T)
Nullable(T)
T
```

#### 配置示例

```
sink{
    ClickHouse {
        host = "centos01:8123,centos02:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        fields = ["i_item_sk","i_color"]
        table = "item"
        cluster = "ck_cluster"
        order_keys=["i_item_sk"]
        bulk_size = 50000
        save_mode="overwrite"
        nullable_fields=["i_color"]
        low_cardinality_fields=["i_color"]
    }

}
```
### 4.cknative

cknative插件使用场景是将hdfs文件作为source，clickhouse作为目标数据库以实现高效的数据导入，核心功能是使用clickhouse-jdbc读取FSDataInputStream的方式来加速写入，单任务写入速度比clickhouse插件最高可提升约20倍，但目前社区lts版本的clickhouse写入orc文件时内存膨胀较严重，无法支持大量的并发写入，需要使用优化过的clickhouse自编译版本（基于21.3.6.55，社区已merge）。

#### 配置参数

| name                  | type    | required | default value | 备注                                                         |
| --------------------- | ------- | -------- | ------------- | :----------------------------------------------------------- |
| host                  | string  | yes      | -             | 多个host配置方式为：host1:port,host2:port...，该方式为clickhouse-jdbc的UrlParser支持的配置，每次获取连接getConnection()时会随机使用一个host； |
| database              | string  | yes      | -             |                                                              |
| table                 | string  | yes      | -             |                                                              |
| username              | string  | no       | -             | 忽略时clickhouse-jdbc会使用default用户                       |
| password              | string  | no       | -             |                                                              |
| file_format           | string  | yes      | -             | 读取的文件格式，如ORC，Parquet等，必须为clickhouse支持的文件格式，详见：https://clickhouse.tech/docs/en/interfaces/formats/ |
| cluster               | string  | no       | -             | 若配置了cluster，会自动获取cluster对应的hosts，进行数据分发写入及overwrite模式下的truncate等操作，此时host参数仅用来连接集群获取集群的hosts信息； |
| save_mode             | string  | no       | "append"      | 写入模式："overwrite"-覆盖；"append"-追加                    |
| insert_sql            | string  | no       | -             | 用于hdfs文件和clickhouse表字段数量不匹配时通过SQL转换(分区表也需指定该参数)，sql的格式为：insert into xxx select ... from input('...')，支持%自动赋分区值，详见下文insert_sql示例 |
| write_distributed     | boolean | no       | false         | 是否写分布式表，为false时即使配置的table为分布式表，也会通过本地表写入，如果业务场景需要写分布式表(如使用分布式表的哈希分片功能)，则可以将其设置为true，会直接写分布式表，注意此时任务的并发数不宜设置过高，分布式表写入请求的膨胀问题可能会导致超过clickhouse的用户配额。 |
| socket_timeout        | string  | no       | "3600000"     | 毫秒，60min，clickhouse-jdbc的参数，**一般无需调整**，如果报了SocketTimeoutException，可以增大该值 |
| send_timeout          | string  | no       | "3600"        | 秒，60min，clickhouse-server的参数，**一般无需调整**         |
| receive_timeout       | string  | no       | "3600"        | 秒，60min，clickhouse-server的参数，**一般无需调整**         |
| max_execution_time    | string  | no       | "3600"        | 秒，一个写入请求最大的执行时长，默认60min，**一般无需调整**，如果报了执行时间超时异常，可以调整该参数的值 |
| connect_timeout       | string  | no       | "300000"      | 毫秒，默认值5min，**一般无需调整**                           |
| compression           | string  | no       | "none"        | 备用参数，**可忽略**。目前如果设置了压缩算法，clickhouse-jdbc并不会进行压缩，需要自行将数据使用指定的压缩算法进行压缩，clickhouse服务端才可以正确解压。 |
| parts_to_throw_insert | string  | no       | "1800"        | 备用参数，由于导数过程中会先写一份临时表且该表关闭了merge功能，可能会生成过多的part从而抛too many parts异常，此时可进一步增大该值，但**不建议调整该值**，此异常一般是orc文件stripe粒度不合适或者分区键选取不合理等 |
| parts_to_delay_insert | string  | no       | "1800"        | 备用参数，可与parts_to_throw_insert相同（临时表不merge，延迟写入无意义）， |
| max_parts_in_total    | string  | no       | "500000"      | 备用参数，抛Too many parts (N) exception时可进一步增大该值，**不建议调整该值**，此异常一般是orc文件stripe粒度不合适或者分区键选取不合理 |

**insert_sql**

该参数主要用于hdfs文件和clickhouse表的字段不匹配的情况，此时无法将hdfs文件直接写入clickhouse，如hive表存在分区时，hdfs文件并没有分区列，而clickhouse中分区必须以一个字段为基础，因此clickhouse中的列会多于hdfs中的文件，无法直接导入。另外也可以用于源数据字段类型与clickhouse中的字段类型不一样，需要转换的场景。

1.支持的语法如下（https://clickhouse.tech/docs/en/sql-reference/table-functions/input/）：

insert into table select ... from input('...')

2.使用示例：

如hive中表结构如下：

```sql
CREATE TABLE `demo`(
  `name` string,
  `id` int)
PARTITIONED BY (`dt` string)
STORED AS orc;
```

ck中表结构如下：

```sql
CREATE TABLE demo 
(
    `name` String,
    `id` String, 
    `dt` String
) 
ENGINE = MergeTree 
ORDER BY id
PARTITION BY(dt);
```

则insert_sql配置为：

```sql
--id字段会自动转换成tring
INSERT INTO demo SELECT name,id,'20200311' FROM input('name String,id Int32')

--如果不能自动转换的字段可以使用函数进行转换
INSERT INTO demo SELECT name,toString(id),'20200311' FROM input('name String,id Int32')

--分区字段可以通过使用'%'自动匹配源数据的分区值，注意单引号不可以忽略
INSERT INTO demo SELECT name,id,'%' FROM input('name String,id Int32')

--如果是多级分区，可以配置多个'%'，此时会按源数据的分区顺序替换赋值
INSERT INTO demo SELECT name,id,'%','%' FROM input('name String,id Int32')
```

#### 配置示例

```
sink{
    cknative {
        source_table_name = "accesslog"
        host = "10.0.0.11:8123,10.0.0.12:8123,10.0.0.15:8123"
        username = ""
        password = ""
        database = "default"
        table = "student"
        file_format = "ORC"
        insert_sql = "INSERT INTO demo SELECT name,id,'%' FROM input('name String,id Int32')"
  }
}
```

## transform plugin

### 1.convert

可以对指定字段集合进行类型转换，该插件从waterdrop1.x版本迁移，但对配置参数做了改动，参数类型从string改为array，来支持在一个convert内对多个字段同时修改类型。

#### 配置参数

| name          | type  | required | default value | 备注                                                         |
| ------------- | ----- | -------- | ------------- | ------------------------------------------------------------ |
| source_fields | array | yes      | -             | 需要类型转换的字段名                                         |
| new_types     | array | yes      | -             | 需要转换的目标类型，与字段名一一对应，当前支持的类型：string，integer，long，float，double，boolean |

#### 配置示例

```
transform {
   Convert {
       source_fields=["inv_date_sk","inv_item_sk"]
       new_types=["integer","double"]
   }
}   
```

## 参考案例

### 1.HiveToClickhouse

#### 1）单表配置

```yaml
env {
  spark.app.name = "Waterdrop-hive2ck"
  spark.executor.instances = 4  #并发数可根据数据量适当增大，加快导数速度
  spark.executor.cores = 2
  spark.executor.memory = "5g"
  spark.sql.catalogImplementation = "hive"
  spark.yarn.queue = "xxx"
}

source {
  hive {
     pre_sql = "select * from test.test_table limit 100"
     result_table_name = "hive_dataset"   #内存中的临时表
  }
}

transform {
     sql{
         sql = "select bigint(ss_sold_date_sk), bigint(ss_sold_time_sk), bigint(ss_item_sk), ss_sales_price,ss_quantity，sm_ship_mode_id，sm_type from hive_dataset"
      }
     convert{  #以下类型转换功能也可以在sql插件里一并配置，此处用法仅表示支持同时配置多个转化插件
         source_fields=["ss_quantity","ss_sales_price"]
         new_types=["integer","double"]
     }
}

sink{
    ClickHouse {
        host = "centos01:8123,centos02:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        table = "test_table"
        cluster = "ck_cluster" 
        bulk_size = 100000
        order_keys=["ss_sold_date_sk"]
        partition_expr=["sm_type"]
        #自己定义建表语句，可以满足更灵活的建表需求
        #create_clause_local="CREATE TABLE test_table ( %fields ) ENGINE = ReplicatedMergeTree ORDER BY (sm_ship_mode_id)PARTITION BY (sm_type)" 
        save_mode="overwrite"
        nullable_fields=[]
        low_cardinality_fields=[]
    }

}
```

#### 2）多表配置

```yaml
env {
  spark.app.name = "Waterdrop-hive2ck"
  spark.executor.instances = 4
  spark.executor.cores = 2
  spark.executor.memory = "5g"
  spark.sql.catalogImplementation = "hive"
  spark.yarn.queue = "xxx"
}

source {
    hive {
       result_table_name = "view_lineorder"
       pre_sql = "select * from ssb.lineorder"
    }
    hive {
        result_table_name = "view_customer"
        pre_sql = "select * from ssb.customer"
    }
    hive {
        result_table_name = "view_date"
        pre_sql = "select * from ssb.date"
    }
    hive{
        result_table_name = "view_supplier"
        pre_sql = "select * from ssb.supplier"
    }
    hive{
        result_table_name = "view_part"
        pre_sql = "select * from ssb.part"
    }
}

transform {
      
}

sink {
    ClickHouse {
        host = "centos01:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        table = "lineorder"
        cluster = "ck_cluster_test"
        fields = ["ss_sold_date_sk", "ss_sold_time_sk", "ss_item_sk", "ss_sales_price", "ss_quantity"]
        order_keys=["lo_orderdate", "lo_orderkey"]
        bulk_size = 20000
        source_table_name=view_lineorder
        save_mode="overwrite"
    }
    ClickHouse {
        host = "centos01:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        table = "customer"
        cluster = "ck_cluster_test"
        order_keys=["c_custkey"]
        bulk_size = 20000
        source_table_name=view_customer
        save_mode="overwrite"
    }
    ClickHouse {
        host = "centos01:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        table = "date"
        cluster = "ck_cluster_test"
        order_keys=["d_datekey"]
        bulk_size = 20000
        source_table_name=view_date
        save_mode="overwrite"
    }
    ClickHouse {
        host = "centos01:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        table = "supplier"
        cluster = "ck_cluster_test"
        order_keys=["s_suppkey"]
        bulk_size = 20000
        source_table_name=view_supplier
        save_mode="overwrite"
    }
    ClickHouse {
        host = "centos01:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        table = "part"
        cluster = "ck_cluster_test"
        order_keys=["p_partkey"]
        bulk_size = 20000
        source_table_name=view_part
        save_mode="overwrite"
    }

}
```

#### 3）使用cknative

```yaml
env {
  spark.app.name = "xxx"
  spark.executor.instances = 4
  spark.executor.cores = 2
  spark.executor.memory = "4g"
  spark.yarn.queue = "xxx" 
}

source {
    hdfs {
        path = "/user/hive/warehouse/test.db/catalog_sales/"
        parent_regex="(.*?)dt=2018\\d{2}"  #源数据按月分区，该正则表示导入2018年全年的数据
    }
}
transform {    
}

sink{
cknative {
    host = "centos01:8123"
    username = "xxx"
    password = "xxx"
    database = "default"
    table = "catalog_sales"
    file_format = "ORC"
    insert_sql = "INSERT INTO catalog_sales SELECT order_no,order_time,'%' FROM input('order_no String,order_time String')"
  }
}
```

