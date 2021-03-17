# Waterdrop v2.x For Spark说明文档

## 1 文档

- 官方文档：https://interestinglab.github.io/waterdrop-docs/#/zh-cn/v2/
- github：https://github.com/InterestingLab/waterdrop
- PPT：
  - http://slides.com/garyelephant/waterdrop/fullscreen?token=GKrQoxJi
  - https://elasticsearch.cn/slides/127#page=1



## 2 功能

Waterdrop 是一个`非常易用`，`高性能`、支持`实时流式`和`离线批处理`的`海量数据`处理产品，架构于`Apache Spark` 和 `Apache Flink`之上。可对接多种数据源，以插件化形式开发方便扩展。理论上来讲，只要是flink和spark能够支持的数据源，waterdrop都可以支持。

其版本分为1.x和2.x，2.x主要特点是：

- 2.x基于flink和spark运行，两种引擎都支持批、流的实现（spark用spark sql、spark streaming，flink用flink dataset、flink stream）。另外，spark流式计算还预留了structure streaming的接口，可以自行开发实现。2.x的代码用maven构建。

waterdrop架构简单，分为source、transform、sink三个模块，分别称为“输入数据源”、“转换”、“输出数据源”，每个模块都支持插件化开发。以下简单列出了目前支持一些插件（不分区1.x和2.x版本，1.x的插件可以移植到2.x上）：

| Source        | Sink          | Transform |
| ------------- | ------------- | --------- |
| Elasticsearch | Clickhouse    | Sql       |
| Fake          | Console       | Split     |
| Hive          | Elasticsearch | Json      |
| Jdbc          | File          | Convert   |
| Kafka         | Hbase         |           |
| Phoenix       | Mysql         |           |
| Socket        | Phoenix       |           |
|               | Hive          |           |
|               | Hdfs          |           |

用户在使用时，可以实际业务需求，将source、transform、sink灵活组合，例如：

- 一个source后面可以对接多个transform或多个sink。
- 一个transform后面可以再对接其他transform，或对接sink。



## 3 程序启动

在**spark集群的客户端**中执行脚本(bin/start-waterdrop-spark.sh)，设置`${CONFIG}`值为**配置文件**名称。

```shell
$ cd waterdrop-dist-2.0.4-2.11.12
$ ./bin/start-waterdrop-spark.sh \
  --master yarn \
  --deploy-mode client \
  --config ${CONFIG}
```

**注**：

1.`start-waterdrop-spark.sh`内部就是调用spark-submit，提交了waterdrop的程序包。

2.客户端在`start-waterdrop-spark.sh`中找不到`SPARK_HOME`时，可在start-waterdrop-spark.sh中执行`${SPARK_HOME}/bin/spark-submit `前一行添加：`SPARK_HOME=/home/servers/spark-2.4.7` 或 其他spark所在路径。



## 4 配置文件

### 4.1 Source插件配置

#### 4.1.1 source通用

##### Option

| name              | type   | required | default value |
| ----------------- | ------ | -------- | ------------- |
| result_table_name | string | yes      | -             |

`result_table_name [string]`

不指定 `result_table_name`时 ，此插件处理后的数据，不会被注册为一个可供其他插件直接访问的数据集(dataset)，或者被称为临时表(table);

指定 `result_table_name` 时，此插件处理后的数据，会被注册为一个可供其他插件直接访问的数据集(dataset)，或者被称为临时表(table)。此处注册的数据集(dataset)，其他插件可通过指定 `source_table_name` 来直接访问。



##### Examples

```
fake {
    result_table_name = "view_table_2"
}
```



#### 4.1.2 Hive

##### Description

从hive中获取数据



##### Options

| name           | type   | required | default value | 备注                                                         |
| -------------- | ------ | -------- | ------------- | ------------------------------------------------------------ |
| pre_sql        | string | yes      | -             | 进行预处理的sql, 如果不需要预处理,可以使用select * from hive_db.hive_table |
| common-options | string | yes      | -             | Source 插件通用参数，详情参照 ”4.1.1 source通用“             |

**注**：使用hive source必须做如下配置：

```
# Waterdrop 配置文件中的spark section中：

env {
  ...
  spark.sql.catalogImplementation = "hive"
  ...
}
```



##### Examples

```
env {
  ...
  spark.sql.catalogImplementation = "hive"
  ...
}

source {
  hive {
    pre_sql = "select * from mydb.mytb"
    result_table_name = "myTable"
  }
}

...
```



#### 4.1.3 JDBC

##### Description

通过JDBC读取外部数据源数据



##### Options

| name           | type   | required | default value | 备注                                                         |
| -------------- | ------ | -------- | ------------- | ------------------------------------------------------------ |
| driver         | string | yes      | -             | 用来连接远端数据源的JDBC类名                                 |
| jdbc.*         | string | no       |               | 除了以上必须指定的参数外，用户还可以指定多个非必须参数，覆盖了Spark JDBC提供的所有[参数](https://spark.apache.org/docs/2.4.0/sql-programming-guide.html#jdbc-to-other-databases)。指定参数的方式是在原参数名称上加上前缀"jdbc."，如指定fetchsize的方式是: jdbc.fetchsize = 50000。如果不指定这些非必须参数，它们将使用Spark JDBC给出的默认值。 |
| password       | string | yes      | -             | 密码                                                         |
| table          | string | yes      | -             | 表名，用于读取单个表的所有字段，相当于select * from table。注意：table与query只需要配置其中之一。 |
| url            | string | yes      | -             | JDBC连接的URL。                                              |
| user           | string | yes      | -             | 用户名                                                       |
| query          | string | yes      | -             | 数据库查询语句，用于读取特定字段，要在语句外层加上小括号。注意：table与query只需要配置其中之一。 |
| common-options | string | yes      | -             | -                                                            |



##### Examples

```
jdbc {
    driver = "com.mysql.jdbc.Driver"
    url = "jdbc:mysql://localhost:3306/info"
    table = "access"
    result_table_name = "access_log"
    user = "username"
    password = "password"
    #query = "(select count(*) from z2_test)"
}
```



### 4.2 Sink插件配置

#### 4.2.1 sink通用

##### Option

| name              | type   | required | default value |
| ----------------- | ------ | -------- | ------------- |
| source_table_name | string | no       | -             |

`source_table_name [string]`

不指定 `source_table_name` 时，当前插件处理的就是配置文件中上一个插件输出的数据集(dataset)；

指定 `source_table_name` 的时候，当前插件处理的就是此参数对应的数据集。



##### Examples

```
console {
    source_table_name = "view_table_2"
}
```



#### 4.2.2 Clickhouse

##### Description

clickhouse插件在waterdrop2.0.4的基础上进行了修改，增加了以下功能：

1.自动建表功能，目前支持自动建分布式表+复制表（新增了建表所需的参数），其他表引擎也可以通过create_clause_local语句指定要执行的建表语句；

2.增加save_mode，防止数据覆盖；

3.数据写入时先通过临时表，校验数据完整性后再attach到结果table，临时表建在waterdrop库，需要事先建好该库，且使用的user有权限写入waterdrop库及读取system库相关表的权限(system.clusters、system.tables、system.parts)。

另需要修改部分clickhouse参数，如配置zookeeper来支持复制表及on cluster功能，大数据量导数时需要修改max_partition_size_to_drop的值(需大于导数的最大数据量，如在config.xml中添加<max_partition_size_to_drop>2000000000000</max_partition_size_to_drop>)



##### Options

| name                   | type   | required                  | default value | 备注                                                         |
| ---------------------- | ------ | ------------------------- | ------------- | ------------------------------------------------------------ |
| host                   | string | yes                       | -             | 多个host配置方式为：host1:port,host2:port...，该方式为clickhouse-jdbc的UrlParser支持的配置，每次获取连接getConnection()时会随机使用一个host； |
| database               | string | yes                       | -             |                                                              |
| table                  | string | yes                       | -             |                                                              |
| username               | string | no                        | -             | 忽略时clickhouse-jdbc会使用default用户                       |
| password               | string | no                        | -             |                                                              |
| bulk_size              | number | no                        | 20000         | 每批写入的数据量                                             |
| retry                  | number | no                        | 1             |                                                              |
| retry_codes            | array  | no                        | []            | 需要重试的clickhouse错误码，注意如果在retry配置的重试次数后依然没有成功，将丢弃该批次数据，不会抛异常；如果不配置该字段，遇到异常会抛出异常，spark会重跑失败的task，注意此时可能有数据重复的问题。 |
| fields                 | array  | no                        | -             | 需要输出到ClickHouse的数据字段，即可以过滤source中不需要的字段，指定该字段时处理逻辑分为几种情况，见下文fields字段详解 |
| cluster                | string | no(required in some case) | -             | 若需要自动建表，当默认自动建分布式表+复制表时，**此时cluster是required**；其他情况若配置了cluster，会自动获取cluster对应的hosts，进行数据分发写入及overwrite模式下的truncate等操作，此时host参数仅用来连接集群获取集群信息； |
| save_mode              | string | no                        | "error"       | 表已存在时的写入模式："error"-报错；"overwrite"-覆盖；"append"-追加 |
| create_clause_local    | string | no                        |               | **自动建表参数**（以下所有自动建表参数均只在table不存在时才会涉及），create_clause_local的值是一条完整的create table sql，该参数主要用来支持用户自定义建表语句，能更灵活的指定字段及适合的引擎，具体用法见下文 |
| order_keys             | array  | no(required in some case) |               | **自动建表参数**，如果用户没有使用create_clause_local建表语句建表，本插件也可自动生成建表语句（目前默认建分布式表+复制表），**此时order_keys为required** |
| nullable_fields        | array  | no                        | []            | **自动建表参数**，指定类型为Nullable的列                     |
| low_cardinality_fields | array  | no                        | []            | **自动建表参数**，指定类型为LowCardinality的列               |
| partition_expr         | array  | no                        |               | **自动建表参数**，指定分区表达式                             |



##### Examples

```
 ClickHouse {
        host = "centos01:8123,centos02:8123"
        username = "xxx"
        password = "xxx"
        database = "ssb"
        fields = ["i_item_sk","i_color"]
        table = "item"
        cluster = "ck_cluster"
        order_keys = ["i_item_sk"]
        bulk_size = 50000
        save_mode = "overwrite"
        nullable_fields = ["i_color"]
        low_cardinality_fields = ["i_color"]
 }
```



#### 4.2.3 Hdfs

##### Description

输出数据到HDFS



##### Options

| name             | type   | required | default value  | 备注                                                         |
| ---------------- | ------ | -------- | -------------- | ------------------------------------------------------------ |
| options          | object | no       | -              | 自定义参数                                                   |
| partition_by     | array  | no       | -              | 根据所选字段对数据进行分区                                   |
| path             | string | yes      | -              | 输出文件路径，以 hdfs://开头                                 |
| path_time_format | string | no       | yyyyMMddHHmmss | 当path参数中的格式为`xxxx-${now}`时，`path_time_format`可以指定路径的时间格式，默认值为 `yyyy.MM.dd`。 |
| save_mode        | string | no       | error          | 存储模式，当前支持overwrite，append，ignore以及error。每个模式具体含义见[save-modes](http://spark.apache.org/docs/2.2.0/sql-programming-guide.html#save-modes) |
| serializer       | string | no       | json           | 序列化方法，当前支持csv、json、parquet、orc和text            |
| common-options   | string | no       | -              | Sink 插件通用参数，详情参照 ”4.2.1 sink通用“                 |

常用的时间格式列举如下：

| Symbol | Description        |
| ------ | ------------------ |
| y      | Year               |
| M      | Month              |
| d      | Day of month       |
| H      | Hour in day (0-23) |
| m      | Minute in hour     |
| s      | Second in minute   |



##### Examples

```
hdfs {
    path = "hdfs:///var/logs-${now}"
    serializer = "json"
    path_time_format = "yyyy.MM.dd"
    save_mode = "overwrite"
}
```



#### 4.2.4 Hive

##### Description

整个代码根据是否配置overwrite_partition分为两大部分:

(1)不配置overwrite_partition，即操作对象是整个表。

(2)配置overwrite_partition，即操作对象是分区文件。

配置overwrite_partition时，根据表达式中的"="号来区分动态还是静态，静态和动静态混合的两种情况要保证表的存在。

执行流程：首先会检测参数配置是否合法，其次指定数据库，最后根据配置执行代码。



##### Option

| name                | default_value | required | type   | 备注                                                         |
| ------------------- | ------------- | -------- | ------ | ------------------------------------------------------------ |
| database            | -             | yes      | String | 数据库名                                                     |
| table_name          | -             | yes      | String | 表名                                                         |
| format              | -             | no       | String | 指定文件存储格式。1.不配置就不执行format()； 2.配置非合法值时，报错提示配置合法值； 3.save_mode配置成"append"并且表存在时：format必须与原表一致 4.overwrite_partition被配置后，format必须与原表一致 |
| save_mode           | error         | no       | String | 数据写入方式 。1.检查配置的值是否合法； 2.partition_by被配置后： 表存在时： （1）error，报错提示配置合法的值； （2）overwrite，会覆盖原表 表不存在时： （1）error和append，报错提示配置"overwrite"； （2）overwrite，会自动建表； 3.overwrite_partition被配置后，save_mode必须为"overwrite" |
| partition_by        | -             | no       | String | 分区字段。1.save_mode="overwrite"且创建新表时：指定分区；     2.save_mode="append"时：partition_by必须原表一致 |
| overwrite_partition | -             | no       | String | 覆盖分区，也就是操作表还是分区的标识（优先级最高）           |

**注**：**overwrite_partition**分为动态覆盖、静态覆盖、动静混合分区覆盖，取决于配置参数；

​        配置此参数，程序即认定为覆盖分区操作，即只操作分区，不再操作整个表。

​        **1.动态**：(year,month) 根据插入的数据去覆盖分区，分区不存在的数据会自动新建分区，插入数据。 

​        **2.静态：**(year=2017,month=11) 将所有的数据覆盖到此分区上。

​        **注意：不能包含不属于此分区的数据，否则会忽略数据中的分区字段，将不属于此分区的数据也写入此分区** 

​        **3.混合：**(year=2017,month) 在静态指定分区下，动态覆盖。

​        **注意：不能包含不属于此静态指定分区的数据，否则会忽略数据中的分区字段，将不属于此静态分区的数据也写入分区**



##### Examples

```
hive {
    database = "dev"
    table_name = "hive_table_source"
    save_mode = "overwrite"   #'overwrite'、'append'、'error'
    format = "parquet"        #'parquet'、'orc'
    partition_by = "year,month"		
    overwrite_partition = "year,month" #动态："year,month"；
                                     #静态："year = 2020,month = 01"；
                                     #动静混合："year = 2020,month"，静态属性必须在前边，且按照分区顺序排列
}
```



## 5 hive-ck配置文件实例

```shell
env {
  #spark.streaming.batchDuration = 5
  spark.app.name = "Waterdrop-hive2ck"
  spark.executor.instances = 4
  spark.executor.cores = 2
  spark.executor.memory = "4g"
  spark.sql.catalogImplementation = "hive"
}

source {
  hive {
     #pre_sql = "select * from mxz_test.ship_mode_12 limit 100"
     pre_sql = "select * from tpcds_bin_partitioned_orc_5.catalog_sales"
     #pre_sql = "select * from tpcds_bin_partitioned_orc_5.customer"
     result_table_name = "hive_dataset"
  }
}
transform {
       # sql{
       # sql = "select bigint(sm_ship_mode_sk),sm_ship_mode_id,sm_type,sm_code,sm_carrier,sm_contract from hive_dataset"
       # result_table_name = "table1"
      #}
 #    Convert{
 #        source_fields = ["sm_ship_mode_id","sm_code"]
 #        new_types = ["long","string"]
 #    }
}

sink{
    ClickHouse {
        host = "10.0.0.11:8123,10.0.0.12:8123,10.0.0.13:8123,10.0.0.14:8123"
        username = "datacube"
        password = "2020cube"
        database = "tpcds_bin_partitioned_orc_5"
        table = "catalog_sales_0301"
        #cluster = "ck_cluster"
        #fields = ["c_customer_sk","c_customer_id"]
        #order_keys = ["cs_ship_date_sk"]
        bulk_size = 100000
        #partition_expr = ["sm_type"]
        #create_clause_local = "CREATE TABLE ship_mode_0219_1 ( %fields ) ENGINE = ReplicatedMergeTree ORDER BY (sm_ship_mode_id) PARTITION BY (sm_type); "
        #source_table_name = hive_dataset
        save_mode = "append"
        #nullable_fields = [sm_type]
        #low_cardinality_fields = []
    }

}

```

