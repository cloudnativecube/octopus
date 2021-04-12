# Trino sql 的"透传"能力
结论：trino 的"透传"很有限。其设计思想是， trino计算 + 外部数据源。 所以trino 的“透传”都是围绕着如何减少读取外部数据源的数据量做的优化。

所谓“透传” 就是把某些特定的操作下推到TableScan（trino 有 TableNode继承自PlanNode）

小注：透传\下推\PushIntoTableScan,三个词的含义相同

以mysql 为例
### Mysql PushIntoTableScan
* Aggregate. [支持的函数](https://trino.io/docs/current/connector/mysql.html#pushdown) PushAggregationIntoTableScan
* Limit PushLimitIntoTableScan
* TOPN 【形如`order by xx limit 10`, 注意 单独使用`order by` 不会下推】 PushTopNIntoTableScan
* Join  【默认关闭】PushJoinIntoTableScan
* DistinctLimit PushDistinctLimitIntoTableScan
* Projection  PushProjectionIntoTableScan
* Predicate  PushPredicateIntoTableScan

其中 JdbcClient 接口为：`Aggregate`, `Limit`, `TopN`, `Join` 

结合mysql，现在我们分析一下 `trino 的“透传”都是围绕着如何减少读取外部数据源的数据量而做的优化`
1. TOPN， 即`order by xx limit num` 支持下推，而`order by` 不支持。原因显而易见，增加了`limit num` 之后会减少源数据的读取量和网络传输量。
2. Join 默认是关闭的。官方给出的解释如下，原因是开启Join后，有可能增加读取源数据的量，所以默认是关闭的。
```
    /*
     * Join pushdown is disabled by default as this is the safer option.
     * Pushing down a join which substantially increases the row count vs
     * sizes of left and right table separately, may incur huge cost both
     * in terms of performance and money due to an increased network traffic.
     */
```
3. 聚合，Limit，谓词等会减少数据量.

### clickhouse PushIntoTableScan
clickhouseclient 继承自 JdbcClient，但是关于 JdbcClient四个优化，均没有实现。
我们修改了一下源码，使之支持`Join`的透传。
在`plugin/trino-clickhouse/src/main/java/io/trino/plugin/clickhouse/ClickHouseClient.java` 增加以下代码。
```
    @Override
    public Optional<PreparedQuery> implementJoin(
            ConnectorSession session,
            JoinType joinType,
            PreparedQuery leftSource,
            PreparedQuery rightSource,
            List<JdbcJoinCondition> joinConditions,
            Map<JdbcColumnHandle, String> rightAssignments,
            Map<JdbcColumnHandle, String> leftAssignments,
            JoinStatistics statistics)
    {
        if (joinType == JoinType.FULL_OUTER) {
            return Optional.empty();
        }
        return super.implementJoin(session, joinType, leftSource, rightSource, joinConditions, rightAssignments, leftAssignments, statistics);
    }

    @Override
    protected boolean isSupportedJoinCondition(JdbcJoinCondition joinCondition)
    {
        if (joinCondition.getOperator() == JoinCondition.Operator.IS_DISTINCT_FROM) {
            // Not supported in Clickhouse
            return false;
        }
        // TODO: which types not support join pushdown
        return true;
    }
```

### cklickhouse join下推
join 下推
```
trino> explain (type distributed)select a.name from clickhouse.default.student  as a join clickhouse.default.xh_test as b on a.name=b.name  where a.id >10;
                                                                                                                                    Query Plan
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Fragment 0 [SINGLE]
     Output layout: [name]
     Output partitioning: SINGLE []
     Stage Execution Strategy: UNGROUPED_EXECUTION
     Output[name]
     │   Layout: [name:varbinary]
     │   Estimates: {rows: ? (?), cpu: ?, memory: 0B, network: ?}
     └─ RemoteSource[1]
            Layout: [name:varbinary]

 Fragment 1 [SOURCE]
     Output layout: [name]
     Output partitioning: SINGLE []
     Stage Execution Strategy: UNGROUPED_EXECUTION
     TableScan[clickhouse:Query[SELECT l."name" AS "name_0", r."name" AS "name_1" FROM (SELECT "name" FROM "default"."student" WHERE "id" > ?) l INNER JOIN (SELECT "name" FROM "default"."xh_test") r ON l."
         Layout: [name:varbinary]
         Estimates: {rows: ? (?), cpu: ?, memory: 0B, network: 0B}
         name := name_0:varbinary:String


(1 row)
```

**vs**

join 没有下推
```
trino:default> explain (type distributed)select a.name from clickhouse.default.student  as a join clickhouse.default.xh_test as b on a.name=b.name  where a.id >10;
                                                                                                    Query Plan                       
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Fragment 0 [SINGLE]                                                                                                                 
     Output layout: [name]                                                                                                           
     Output partitioning: SINGLE []                                                                                                  
     Stage Execution Strategy: UNGROUPED_EXECUTION                                                                                   
     Output[name]                                                                                                                    
     │   Layout: [name:varbinary]                                                                                                    
     │   Estimates: {rows: ? (?), cpu: ?, memory: ?, network: ?}                                                                     
     └─ RemoteSource[1]                                                                                                              
            Layout: [name:varbinary]                                                                                                 
                                                                                                                                     
 Fragment 1 [HASH]                                                                                                                   
     Output layout: [name]                                                                                                           
     Output partitioning: SINGLE []                                                                                                  
     Stage Execution Strategy: UNGROUPED_EXECUTION                                                                                   
     InnerJoin[("name" = "name_0")][$hashvalue, $hashvalue_2]                                                                        
     │   Layout: [name:varbinary]                                                                                                    
     │   Estimates: {rows: ? (?), cpu: ?, memory: ?, network: ?}                                                                     
     │   Distribution: PARTITIONED                                                                                                   
     │   dynamicFilterAssignments = {name_0 -> #df_298}                                                                              
     ├─ RemoteSource[2]                                                                                                              
     │      Layout: [name:varbinary, $hashvalue:bigint]                                                                              
     └─ LocalExchange[HASH][$hashvalue_2] ("name_0")                                                                                 
        │   Layout: [name_0:varbinary, $hashvalue_2:bigint]                                                                          
        │   Estimates: {rows: ? (?), cpu: ?, memory: 0B, network: ?}                                                                 
        └─ RemoteSource[3]                                                                                                           
               Layout: [name_0:varbinary, $hashvalue_3:bigint]                                                                       
                                                                                                                                     
 Fragment 2 [SOURCE]                                                                                                                 
     Output layout: [name, $hashvalue_1]                                                                                             
     Output partitioning: HASH [name][$hashvalue_1]                                                                                  
     Stage Execution Strategy: UNGROUPED_EXECUTION                                                                                   
     ScanFilterProject[table = clickhouse:default.student default.default.student constraint on [id] columns=[name:varbinary:String], grouped = false, filterPredicate = true, dynamicFilter = {"name" = #df_298}
         Layout: [name:varbinary, $hashvalue_1:bigint]                                                                               
         Estimates: {rows: ? (?), cpu: ?, memory: 0B, network: 0B}/{rows: ? (?), cpu: ?, memory: 0B, network: 0B}/{rows: ? (?), cpu: ?, memory: 0B, network: 0B}
         $hashvalue_1 := combine_hash(bigint '0', COALESCE("$operator$hash_code"("name"), 0))                                        
         name := name:varbinary:String                                                                                               
                                                                                                                                     
 Fragment 3 [SOURCE]                                                                                                                 
     Output layout: [name_0, $hashvalue_4]                                                                                           
     Output partitioning: HASH [name_0][$hashvalue_4]                                                                                
     Stage Execution Strategy: UNGROUPED_EXECUTION                                                                                   
     ScanProject[table = clickhouse:default.xh_test default.default.xh_test columns=[name:varbinary:String], grouped = false]        
         Layout: [name_0:varbinary, $hashvalue_4:bigint]                                                                             
         Estimates: {rows: ? (?), cpu: ?, memory: 0B, network: 0B}/{rows: ? (?), cpu: ?, memory: 0B, network: 0B}                    
         $hashvalue_4 := combine_hash(bigint '0', COALESCE("$operator$hash_code"("name_0"), 0))                                      
         name_0 := name:varbinary:String
```

在ClickhouseClient中，我们可以很容易的实现 JdbcClient 接口`Aggregate`, `Limit`, `TopN`, `Join`中定义的四种下推，但是要实现其他的下推，就比较困难了。我们会后续展开

### 小结
* trino的设计思想是：trino作为计算单元 + catalog关联外部源数据。所以它的下推优化都是围绕着减少源数据的量展开的。
----
# Trino sql 编译原理
sql 运行原理图

![](https://user-images.githubusercontent.com/13829695/113957555-05fae100-9852-11eb-83ac-1109d11fea2f.png)

我们对步骤LogicalPlaner.plan展开，如下图

![](https://user-images.githubusercontent.com/13829695/113695392-616a8900-9703-11eb-8b48-299c0c9c2f04.png)

所以想要实现特定的下推，需要增加优化规则，通过Metadata一直遗传到JdbcClient的子类。

我们以增加`Union` 下推为例, 看看我们需要哪些改造吧。

在pushIntoTableScanOptimizer 中添加规则PushUnionIntoTableScan 
实现 PushUnionIntoTableScan 逻辑包括：
1. Metadata 增加 `applyJoin` 接口。MetadataManger 实现 applyJoin逻辑， ... 一直到 ClickhouseClient。
2. 在spi 中新增UnionApplicationResult、UnionCondition、JdbcUnionCondition ......
3. 实现PushUnionIntoTableScan 核心逻辑，一些统计信息等。

所以我们要增加大量的接口和实现，可能开发周期比较长。

接下来，我们了解一下Trino sql如果支持专业引擎的函数和算子有哪些工作吧！

----
# Trino sql 如何支持专业引擎的函数和算子

Trino is an `ANSI SQL` compliant query engine, 但clickhouse 并不是标准的sql。 

[trino select](https://trino.io/docs/current/sql/select.html)
[clickhouse select](https://clickhouse.tech/docs/en/sql-reference/statements/select/)

实现trino 兼容clickhouse sql 要实现，难点：
1. sql 语法差异大。
    1.1 存在ck算子没有出现在trino ， 即antlr 无法把sql语句解析成AST等。
    1.2 算子用法不同
2. 支持特定函数、算子，并且这些特定函数、算子是必须下推至特定的引擎。
3. 下推。`querybody` 中只要一个算子or函数不支持下推，则无法下推

例如, cube 算子用法差异
```
# clickhouse
select  max(cs_sold_date_sk), min( cs_net_profit) from catalog_sales_0224 where cs_sold_date_sk=2452091 and cs_net_profit < -8000 group by  cs_net_profit, cs_sold_date_sk  with CUBE;

# trino
select  max(cs_sold_date_sk), min( cs_net_profit) from clickhouse.default.catalog_sales_0224 where cs_sold_date_sk=2452091 and cs_net_profit < -8000 group by  cube (cs_net_profit, cs_s
old_date_sk) ;
```
### 小结
Trino 兼容 clickhouse sql，需要系统性设计引擎，可能要完全重造一个sql 解析标准。

----
# 总结
1. trino 作为计算模块，通过catalog 关联外部数据。
2. clickhouse 可以比较容易的实现 Aggregate, Limit, TopN, Join 四个下推。
3. 对专业引擎sql支持，可能需要系统性设计sql解析。
### 相关issue
* [Trino sql PushIntoTableScan](https://github.com/cloudnativecube/octopus/issues/56)
* [Trino sql 如何支持专业引擎的函数和算子](https://github.com/cloudnativecube/octopus/issues/60)

# 参考文献
* https://www.infoq.cn/article/vne0a9ykszpcmp32akca
* https://zhuanlan.zhihu.com/p/51917064
* https://zhuanlan.zhihu.com/p/57438825
* 《Presto技术内幕》