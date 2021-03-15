# Sink plugin : Hive [Spark]

# 插件介绍

输出数据到hive

整个代码根据是否配置overwrite_partition(优先级最高)分为两大部分:

(1)不配置overwrite_partition，即操作对象是整个表。

(2)配置overwrite_partition，即操作对象是分区文件。

配置overwrite_partition时，根据表达式中的"="号来区分动态还是静态，静态和动静态混合的两种情况要保证表的存在。

**执行流程：**

1.检测参数配置是否合法；

2.指定数据库；

3.根据配置文件参数执行代码。



# 参数配置

## env配置

**注意：使用hive sink必须做如下配置：**

```
# Waterdrop 配置文件中的spark section中：

spark {
  ...
  spark.sql.catalogImplementation = "hive"
  ...
}
```

## Sink配置

|        name         | default_value | required |  type  |
| :-----------------: | :-----------: | :------: | :----: |
|      database       |       -       |   yes    | String |
|     table_name      |       -       |   yes    | String |
|       format        |       -       |    no    | String |
|      save_mode      |     error     |    no    | String |
|    partition_by     |       -       |    no    | String |
| overwrite_partition |       -       |    no    | String |

## 说明

**database [String]**

数据库名。

**table_name [String]**

表名。

**format  [String]  (合法值："orc","parquet")**

指定文件存储格式。

1.配置非合法值时，将报错提示合法值；

2.save_mode="append"并且表存在时：format必须与原表一致，不一致会报错提示

3.overwrite_partition被配置后，format必须与原表一致，不一致会报错提示

**save_mode [String]  (合法值："overwrite","append","error")**

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

**partition_by [String]**

分区字段。

1.save_mode="overwrite"且表不存在需要创建新表时：指定分区；

2.save_mode="append"时：partition_by必须原表一致

**overwrite_partition [String]**

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

## 配置样例

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



# 动态、静态、混合三种方式验证

## 背景介绍：

配置overwrite_partition

partition_overwrite_temp是存放待写入数据的表

partition_overwrite_target是存放已写入数据的目标表

```sql
两表的结构一致如下:
TABLE COLUMNS: (`id` INT, `name` STRING, `year` INT, `month` INT)
PARTITIONED BY: (year, month)
```

过程简介：将partition_overwrite_temp的数据以指定的方式（动态、静态、混合）写入partition_overwrite_target表。

## 动态验证：

**代码：**

```scala
sparkSession.conf.set("spark.sql.sources.partitionOverwriteMode","dynamic")
val tableMeta = env.getSparkSession.sql(String.format("DESCRIBE FORMATTED %s",tableName))
val location : String = tableMeta.where("col_name = 'Location'").select("data_type").first().mkString
// hdfs://centos01:8020/user/hive/warehouse/dev.db/partition_overwrite_target
val dftemp = spark.sql("select * from partition_overwrite_temp")
dftemp.write.partitionBy("year","month").mode("overwrite").format("parquet").save(location)
```

**验证：**

```sql
// 前提:overwrite_partition="year,month"

// 写入前数据：
scala> spark.sql("select * from partition_overwrite_target").show()
+---+--------+----+-----+
| id|    name|year|month|
+---+--------+----+-----+
|  3|xiaohong|2020|   11|
|  3|xiaohong|2020|   11|
|  1|xiaohong|2021|   11|
|  1|xiaohong|2021|   11|
|  2|xiaohong|2021|   12|
|  2|xiaohong|2021|   12|
+---+--------+----+-----+

// 待写入数据：
scala> spark.sql("select * from partition_overwrite_temp").show()
+---+-------+----+-----+
| id|   name|year|month|
+---+-------+----+-----+
| 11|xiaohua|2021|   11|
| 12|xiaohua|2022|   10|
+---+-------+----+-----+

// 写入后数据：
scala>  spark.sql("select * from partition_overwrite_target").show()
+---+--------+----+-----+
| id|    name|year|month|
+---+--------+----+-----+
|  3|xiaohong|2020|   11|
|  3|xiaohong|2020|   11|
|  2|xiaohong|2021|   12|
|  2|xiaohong|2021|   12|
| 11| xiaohua|2021|   11|// id=11的数据覆盖已存在的分区"{hdfs-location}/year=2021/month=11"下的两条id=1的数据
| 12| xiaohua|2022|   10|// id=12的数据写入新的分区"{hdfs-location}/year=2022/month=10"中
+---+--------+----+-----+
```

**结论：**

表存在：删除数据涉及的分区文件，重建分区文件，最后将数据写入所属分区。

表不存在：创建带有指定分区的新表，将数据写入新表的所属分区。



## 静态验证：

**代码：**

```scala
val tableMeta = env.getSparkSession.sql(String.format("DESCRIBE FORMATTED %s",tableName))
val location = tableMeta.where("col_name = 'Location'").select("data_type").first().mkString
// hdfs://centos01:8020/user/hive/warehouse/dev.db/partition_overwrite_target
val partitionKey = "/year=2021/month=11"
val partitionLocation = location + "/" + partitionKey    
// hdfs://centos01:8020/user/hive/warehouse/dev.db/partition_overwrite_target/year=2021/month=11
df.write.mode("overwrite").format("parquet").save(partitionLocation)
```

**验证：**

```sql
// 前提：overwrite_partition="year=2021,month=11"

// 写入前数据：
scala> spark.sql("select * from partition_overwrite_target").show()
+---+--------+----+-----+
| id|    name|year|month|
+---+--------+----+-----+
|  3|xiaohong|2020|   11|
|  3|xiaohong|2020|   11|
|  1|xiaohong|2021|   11|
|  1|xiaohong|2021|   11|
|  2|xiaohong|2021|   12|
|  2|xiaohong|2021|   12|
+---+--------+----+-----+

// 待写入数据：
scala> spark.sql("select * from partition_overwrite_temp").show()
+---+-------+----+-----+
| id|   name|year|month|
+---+-------+----+-----+
| 11|xiaohua|2021|   11|
| 12|xiaohua|2022|   10|
+---+-------+----+-----+

// 写入后数据：
scala>  spark.sql("select * from partition_overwrite_target").show()
+---+--------+----+-----+
| id|    name|year|month|
+---+--------+----+-----+
|  3|xiaohong|2020|   11|
|  3|xiaohong|2020|   11|
|  2|xiaohong|2021|   12|
|  2|xiaohong|2021|   12|
| 11| xiaohua|2021|   11|// id=11的数据覆盖已存在的分区"{hdfs-location}/year=2021/month=11"下的两条id=1的数据
| 12| xiaohua|2021|   11|// id=12的数据中的(year,month)被写为overwrite_partition中配置的"/year=2021/month=11"
+---+--------+----+-----+

```

**结论：**

把待写入数据分区列的值修改为overwrite_partition中配置的分区值，然后将数据覆盖到overwrite_partition中配置的具体分区。

例如：上述案例中待写入id=12 的数据，原始数据中year=2022，month=10，写入后非分区列(id、name)值不变，分区列(year、month)值被写为overwrite_partition中配置的“year=2021,month=11”。



## 混合验证：

**代码：**

```scala
sparkSession.conf.set("spark.sql.sources.partitionOverwriteMode","dynamic")
val tableMeta = env.getSparkSession.sql(String.format("DESCRIBE FORMATTED %s",tableName))
val location : String = tableMeta.where("col_name = 'Location'").select("data_type").first().mkString
// hdfs://centos01:8020/user/hive/warehouse/dev.db/partition_overwrite_target
val partitionKey = "/year=2021"
val partitionLocation = location + "/" + partitionKey    
// hdfs://centos01:8020/user/hive/warehouse/dev.db/partition_overwrite_target/year=2021
val dftemp = spark.sql("select * from partition_overwrite_temp")
dftemp.write.partitionBy("month").mode("overwrite").format("parquet").save(partitionLocation)
```

**验证：**

```sql
// 前提：overwrite_partition="year=2021,month"

// 写入前数据：
scala> spark.sql("select * from partition_overwrite_target").show()
+---+--------+----+-----+
| id|    name|year|month|
+---+--------+----+-----+
|  3|xiaohong|2020|   11|
|  3|xiaohong|2020|   11|
|  1|xiaohong|2021|   11|
|  1|xiaohong|2021|   11|
|  2|xiaohong|2021|   12|
|  2|xiaohong|2021|   12|
+---+--------+----+-----+

// 待写入数据：
scala> spark.sql("select * from partition_overwrite_temp").show()
+---+-------+----+-----+
| id|   name|year|month|
+---+-------+----+-----+
| 11|xiaohua|2021|   11|
| 12|xiaohua|2022|   10|
+---+-------+----+-----+

// 写入后数据：
scala>  spark.sql("select * from partition_overwrite_target").show()
+---+--------+----+-----+
| id|    name|year|month|
+---+--------+----+-----+
|  3|xiaohong|2020|   11|
|  3|xiaohong|2020|   11|
|  2|xiaohong|2021|   12|
|  2|xiaohong|2021|   12|
| 11| xiaohua|2021|   11|// id=11的数据覆盖已存在的分区"{hdfs-location}/year=2021/month=11"下的两条id=1的数据
| 12| xiaohua|2021|   10|// id=12的year被写成overwrite_partition的2021，month被写成原始数据的10
+---+--------+----+-----+
```

**结论：**

将上述的动态和静态的方式结合，先静态，再动态。

静态的部分也会发生静态验证“例如”中的问题。



# 部署与运行

## 编译

```
mvn clean package -D skipTests -D mvn.test.skip=true -Dmaven.javadoc.skip=true
```

## 运行

### 在本地以 local 方式运行

```
./bin/start-waterdrop-spark.sh --master local[4] --deploy-mode client --config ./config/application.conf
```

### 在 Yarn 集群上运行 

```
# client 模式
./bin/start-waterdrop-spark.sh --master yarn --deploy-mode client --config ./config/application.conf

# cluster 模式
./bin/start-waterdrop-spark.sh --master yarn --deploy-mode cluster --config ./config/application.conf
```