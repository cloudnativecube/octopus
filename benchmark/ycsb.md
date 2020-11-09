# YCSB

## 概述

YCSB用于对多种NoSQL数据库作bechmark测试，参考以下链接：

- 代码仓库：https://github.com/brianfrankcooper/YCSB
- 测试hbase：https://github.com/brianfrankcooper/YCSB/tree/0.17.0/hbase098
- 运行workload详细文档：https://github.com/brianfrankcooper/YCSB/wiki/Running-a-Workload

## 步骤

编译ycsb，只编译hbase模块：

```
 # mvn -pl hbase20 -DskipTests -am package
```

在hbase里创建表：

```
hbase(main):001:0> n_splits = 30
=> 30
hbase(main):002:0> create 'usertable', 'family', {SPLITS => (1..n_splits).map {|i| "user#{1000+i*(9999-1000)/n_splits}"}}
Created table usertable
Took 2.8562 seconds
=> Hbase::Table - usertable
```

运行workload包括load和transaction两个阶段，load就是把数据加载到数据库里，transaction就是执行读/写/更新等操作。

运行workload时仍然需要mvn的某些构建过程，所以这里还是在编译机上执行workload。

```
// 把hbase conf拷到本地
# scp -r hadoop@10.0.0.11:/home/servers/hbase-2.2.6/conf/ ./hbase_home_conf
// 执行load
# bin/ycsb load hbase20 -P workloads/workloada -cp ./hbase_home_conf -p table=usertable -p columnfamily=family
// 执行transaction
# bin/ycsb run hbase20 -P workloads/workloada -cp ./hbase_home_conf -p table=usertable -p columnfamily=family
```





