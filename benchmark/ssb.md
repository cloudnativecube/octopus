# Star Schema Benchmark

基于**TPC-H**修改而来，用于评测数据库产品对典型的数据仓库应用场景的性能。

![ssb schema](https://github.com/cloudnativecube/reference/raw/master/images/ssb-schema.png?raw=true)

### 1.Query明细

#### Q1.计算如果公司取消部分出货折扣时的收益增长有多少（Query间尽量减少读取数据的重叠部分，以减少系统缓存对测评的影响）

**Q1.1** select **sum**(lo_extendedprice*lo_discount) as revenue from lineorder, date where lo_orderdate = d_datekey and d_year = 1993 and lo_discount between 1 and 3 and lo_quantity < 25;

**Q1.2** select **sum**(lo_extendedprice*lo_discount) as revenue from lineorder, date where lo_orderdate = d_datekey and d_yearmonthnum = 199401 and lo_discount between 4 and 6 and lo_quantity between 26 and 35;

**Q1.3** select **sum**(lo_extendedprice*lo_discount) as revenue from lineorder, date where lo_orderdate = d_datekey and d_weeknuminyear = 6 and d_year = 1994 and lo_discount between 5 and 7 and lo_quantity between 26 and 35;

#### Q2.比较特定地区的供应商间某类产品的收益（四表join+两列聚合）

**Q2.1** select **sum**(lo_revenue), d_year, p_brand1 from lineorder, date, part, supplier where lo_orderdate = d_datekey and lo_partkey = p_partkey and lo_suppkey = s_suppkey and p_category = 'MFGR#12' and s_region = 'AMERICA' **group by** d_year, p_brand1 **order by** d_year, p_brand1;

**Q2.2** select **sum**(lo_revenue), d_year, p_brand1 from lineorder, date, part, supplier where lo_orderdate = d_datekey and lo_partkey = p_partkey and lo_suppkey = s_suppkey and p_brand1 between 'MFGR#2221' and 'MFGR#2228' and s_region = 'ASIA' **group by** d_year, p_brand1 **order by** d_year, p_brand1;

**Q2.3** select **sum**(lo_revenue), d_year, p_brand1 from lineorder, date, part, supplier where lo_orderdate = d_datekey and lo_partkey = p_partkey and lo_suppkey = s_suppkey and p_brand1 = 'MFGR#2221' and s_region = 'EUROPE' **group by** d_year, p_brand1 **order by** d_year, p_brand1;

#### Q3.按客户地区和供应商地区以及年份分组计算订单的收益，地区的粒度及过滤条件逐渐变小（四表join+三列聚合）

**Q3.1** select c_nation, s_nation, d_year, **sum**(lo_revenue) as revenue from customer, lineorder, supplier, date where lo_custkey = c_custkey and lo_suppkey = s_suppkey and lo_orderdate = d_datekey and c_region = 'ASIA' and s_region = 'ASIA' and d_year >= 1992 and d_year <= 1997 **group by** c_nation, s_nation, d_year **order by** d_year asc, revenue desc;

**Q.3.2** select c_city, s_city, d_year, **sum**(lo_revenue) as revenue from customer, lineorder, supplier, date where lo_custkey = c_custkey and lo_suppkey = s_suppkey and lo_orderdate = d_datekey and c_nation = 'UNITED STATES' and s_nation = 'UNITED STATES' and d_year >= 1992 and d_year <= 1997 **group by** c_city, s_city, d_year **order by** d_year asc, revenue desc;

**Q3.3** select c_city, s_city, d_year, **sum**(lo_revenue) as revenue from customer, lineorder, supplier, date where lo_custkey = c_custkey and lo_suppkey = s_suppkey and lo_orderdate = d_datekey and (c_city='UNITED KI1' or c_city='UNITED KI5') and (s_city='UNITED KI1' or s_city=’UNITED KI5') and d_year >= 1992 and d_year <= 1997 **group by** c_city, s_city, d_year **order by** d_year asc, revenue desc;

**Q3.4** select c_city, s_city, d_year, **sum**(lo_revenue) as revenue from customer, lineorder, supplier, date where lo_custkey = c_custkey and lo_suppkey = s_suppkey and lo_orderdate = d_datekey and (c_city='UNITED KI1' or c_city='UNITED KI5') and (s_city='UNITED KI1' or s_city='UNITED KI5') and d_yearmonth = 'Dec1997' **group by** c_city, s_city, d_year **order by** d_year asc, revenue desc;

#### Q4.分组计算总利润（五表join+两列聚合）

**Q4.1** select d_year, c_nation, **sum**(lo_revenue - lo_supplycost) as profit from date, customer, supplier, part, lineorder where lo_custkey = c_custkey and lo_suppkey = s_suppkey and lo_partkey = p_partkey and lo_orderdate = d_datekey and c_region = 'AMERICA' and s_region = 'AMERICA' and (p_mfgr = 'MFGR#1' or p_mfgr = 'MFGR#2') **group by** d_year, c_nation **order by** d_year, c_nation;

**Q4.2** select d_year, s_nation, p_category, **sum**(lo_revenue - lo_supplycost) as profit from date, customer, supplier, part, lineorder where lo_custkey = c_custkey and lo_suppkey = s_suppkey and lo_partkey = p_partkey and lo_orderdate = d_datekey and c_region = 'AMERICA' and s_region = 'AMERICA' and (d_year = 1997 or d_year = 1998) and (p_mfgr = 'MFGR#1' or p_mfgr = 'MFGR#2') **group by** d_year, s_nation, p_category **order by** d_year, s_nation, p_category;

**Q4.3** select d_year, s_city, p_brand1, **sum**(lo_revenue - lo_supplycost) as profit from date, customer, supplier, part, lineorder where lo_custkey = c_custkey and lo_suppkey = s_suppkey and lo_partkey = p_partkey and lo_orderdate = d_datekey and c_region = 'AMERICA' and s_nation = 'UNITED STATES' and (d_year = 1997 or d_year = 1998) and p_category = 'MFGR#14' **group by** d_year, s_city, p_brand1 **order by** d_year, s_city, p_brand1;

#### 2.Query过滤数据量分析（Filter Factors）

![FF Analysis of Queries](https://github.com/cloudnativecube/reference/raw/master/images/ssb-FF%20Analysis%20of%20Queries.png)

#### 3.其他场景扩展

业务实际使用的场景涉及更多复杂的查询，如：

1.多表join时包含多个事实表；

2.left/right [outer] join也比较常见；

3.维度表不都直接与事实表相连的雪花模型;

4.嵌套视图；

5.各种函数及特殊子句的使用（case，exists，or等）；

复杂的SQL数据库优化器也难以选择最优的执行计划，可从数据建模和SQL执行计划两方面优化来减少复杂查询。

**智能数据建模**的目标为提升查询性能和存储效率：

1.可能影响查询性能的因子：数据量，字段类型，减少join，引擎的选取，预计算等；

2.存储效率（需与提升查询性能的目标折中考虑）：减少某些维度数据的重复存储；选取存储引擎及压缩格式；

**SQL执行计划**的优化目标主要为SQL的拆分及多计算引擎混合执行，同时涉及语法转换等功能，多引擎自适应也需考虑引擎的负载，数据量，过滤条件。





