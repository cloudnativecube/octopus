# clickhouse jdbc bridge

项目主页：https://github.com/ClickHouse/clickhouse-jdbc-bridge

## hive



## elasticsearch

### 版本

- elasticsearch-7.10.2
- JDK >= 14：编译opendistro-sql的要求
- opendistro-sql-1.13.2.0：它编译时依赖的elasticsearch的版本是7.10.2

### 安装opendistro-sql plugin

opendistro-for-elasticsearch项目：

- sql：https://github.com/opendistro-for-elasticsearch/sql
- sql-jdbc：https://github.com/opendistro-for-elasticsearch/sql/tree/develop/sql-jdbc

获取代码：

```
$ git clone git@github.com:opendistro-for-elasticsearch/sql.git
$ cd sql
$ git branch branch-v1.13.2.0 v1.13.2.0 //选一个合适的分支
$ git checkout branch-v1.13.2.0
```

在编译时执行test有错误，所以为了跳过test，把settings.gradle文件中的test去掉，即把以下两行注释掉：

```
//include 'integ-test'
//include 'doctest'
```

执行编译：

```
$ export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-14.0.2.jdk/Contents/Home
$ ./gradlew build
```

然后就生成了jdbc jar包和plugin zip包，把它们拷贝到elasticsearch机器上：

```
./sql-jdbc/build/libs/opendistro-sql-jdbc-1.13.0.0-SNAPSHOT.jar
./plugin/build/distributions/opendistro-sql-1.13.2.0.zip
```

安装插件（如果es与插件版本不匹配则安装不成功）：

```
$ pwd
/export/elasticsearch-7.10.2
$ bin/elasticsearch-plugin install file:///export/elasticsearch-7.10.2/opendistro-sql-1.13.2.0.zip
```

向elasticsearch中导入官方数据集：

数据集文件所在地址为：https://github.com/elastic/elasticsearch/tree/v7.10.2/docs/src/test/resources ，复制accounts.json文件内容保存到本地。然后加载数据集并查看index：

```
$ curl -H "Content-Type: application/json" -XPOST 'centos0.local:9200/bank/account/_bulk?pretty&refresh' --data-binary "@accounts.json"
$ curl 'centos0.local:9200/_cat/indices?v'
```

### elasticsearch jdbc table engine

在clickhouse上创建表（es中的index对应ck中的table，而database为空），并查询：

```
centos0.local :) create table from_es
(
  account_number Int32,
  balance Int32,
  firstname String,
  lastname String,
  age Int32,
  gender String,
  address String,
  employer String,
  email String,
  city String,
  state String
) engine=JDBC('jdbc:elasticsearch://http://centos0.local:9200', '', 'bank');

centos0.local :) select * from from_es limit 2;
```

### elasticsearch jdbc table function

以下查询都是合法的：

```
SELECT * from jdbc('elasticsearch', '', 'bank') limit 1;
SELECT * from jdbc('elasticsearch', 'bank') limit 1;
SELECT * from jdbc('elasticsearch', 'select account_number, address from bank where match_query(address, \'Holmes\')');
```

第三个语句是执行全文检索，jdbc()函数里用的是opendistro-sql的语法，参考：https://opendistro.github.io/for-elasticsearch-docs/docs/sql/sql-full-text/ 。

问题：

- opendistro-sql和xpack-sql有什么区别？ https://www.elastic.co/guide/en/elasticsearch/reference/7.13/xpack-sql.html

## hbase

### 版本

- hbase-2.2.7
- phoneix-5.1.2对应的hbase-2.2-bin

### phoenix-sql

参考：

- 下载地址：https://phoenix.apache.org/download.html ，注意要和hbase版本匹配。
- faq：http://phoenix.apache.org/faq.html
- sql语法：https://phoenix.apache.org/language/index.html
- phoenix server：https://phoenix.apache.org/server.html
- 参数配置：https://phoenix.apache.org/tuning.html

为了能用phoenix sql创建schema，需要修改${HBASE_HOME}/conf/hbse-site.xml和${PHOENIX_HOME}/bin/hbase-site.xml，添加以下参数，这两个文件分别对应server和client配置。

```
  <property>
    <name>phoenix.schema.isNamespaceMappingEnabled</name>
    <value>true</value>
  </property>
```

使用sqlline.py执行sql语句：

```
$ bin/sqlline.py centos0.local:2181
// 执行以下语句创建schema并插入数据
create schema my_schema;
use my_schema;
create table test (mykey integer not null primary key, mycolumn varchar);
upsert into test values (1,'Hello');
upsert into test values (2,'World!');
select * from test;
```

以上命令创建的schema和table名字都是大写的。如果想使用小写，需要在schema和table名字上加上双引号。**hbase里的schema、table、column都是区分大小写的**。

sqlline的常用命令：

```
!help
!schemas
!tables
!describe <table>
!exit
```

将client配置应用到phoenix-client包里：

```
$ jar uf phoenix-client-hbase-2.2-5.1.2.jar hbase-site.xml
```

然后把phoenix-client-hbase-2.2-5.1.2.jar放到clickhouse jdbc bridge的lib目录下。

### hbase jdbc table engine

```
// schema、table、column名字都是大写
CREATE TABLE from_hbase
(
    MYKEY Int32,
    MYCOLUMN String
)
ENGINE = JDBC('jdbc:phoenix:centos0.local:2181', 'MY_SCHEMA', 'TEST');
```

### hbase jdbc table function

验证以下查询：

```
select * from jdbc('hbase', 'select * from my_schema.test'); //这个语句走的是phoenix sql，不区分大小写
select * from jdbc('hbase', 'MY_SCHEMA', 'TEST'); //查询MY_SCHEMA里的表，注意schema和table名字都是大写
select * from jdbc('hbase', '', 'TEST'); //查询DEFAULT schema里的表
```



