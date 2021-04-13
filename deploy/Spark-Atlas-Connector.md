# Spark Atlas Connector

## 介绍

SAC致力于记录Spark SQL客户端的表级操作，为其建立血缘关系。

```
官方说明：
  A connector to track Spark SQL/DataFrame transformations and push metadata changes to Apache Atlas.

  This connector supports tracking:

  1.SQL DDLs like "CREATE/DROP/ALTER DATABASE", "CREATE/DROP/ALTER TABLE".
  2.SQL DMLs like "CREATE TABLE tbl AS SELECT", "INSERT INTO...", "LOAD DATA [LOCAL] INPATH", "INSERT OVERWRITE [LOCAL] DIRECTORY" and so on.
  3.DataFrame transformations which has inputs and outputs
  4.Machine learning pipelines.
  This connector will correlate with other systems like Hive, HDFS to track the life-cycle of data in Atlas.
```

## 版本说明

```
spark-2.4.3
atlas-2.1.0
```

## 项目地址

```
Remote: https://github.com/hortonworks-spark/spark-atlas-connector
Branch: master
```

## 编译

```
mvn package -DskipTests
```

```
值得注意的是

SAC可以编译出两个Jar包，分别是：
jar1:${SAC-HOME}/spark-atlas-connector/target/spark-atlas-connector_2.11-0.1.0-SNAPSHOT.jar
jar2:${SAC-HOME}/spark-atlas-connector-assembly/target/spark-atlas-connector-assembly-0.1.0-SNAPSHOT.jar

jar1比较小，依赖外部jar包，需要逐步验证当前环境缺少哪些包，可去maven查找具体jar包。
jar2相对jar1较大，大约在40MB左右，无需依赖外部jar包。
```

## 配置

1.编译好的jar包拷贝至${SPARK_HOME}/jars

2.${ATLAS_HOME}/conf/atlas-application.properties拷贝至${SPARK_HOME}/conf

## 启动运行

```
bin/spark-sql --master --deploy-mode client \
--conf spark.extraListeners=com.hortonworks.spark.atlas.SparkAtlasEventTracker \
--conf spark.sql.queryExecutionListeners=com.hortonworks.spark.atlas.SparkAtlasEventTracker \
--conf spark.sql.streaming.streamingQueryListeners=com.hortonworks.spark.atlas.SparkAtlasStreamingQueryEventTracker
```