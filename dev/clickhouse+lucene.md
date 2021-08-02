# clickhouse+hbase

数据集：https://data.world/promptcloud/fashion-products-on-amazon-com



### rocksandra

```
git clone git@github.com:Instagram/cassandra.git
cd cassandra
git checkout rocks_3.0
```

build.properties.default

```
artifact.remoteRepository.central:     https://maven.aliyun.com/repository/public
artifact.remoteRepository.apache:      http://repo.maven.apache.org/maven2
```

```
ant generate-idea-files
```

在idea中打开cassandra目录



# clickhouse+lucene



```
apt install zlib1g-dev
apt install libboost-date-time1.71-dev/focal
apt install libboost-iostreams1.71-dev/focal
```



测试：

```
建表：
create table fulltext
(
    `primary_id` UInt64,
    `secondary_id` UInt64,
    `title` String,
    `content` String
)
ENGINE = Lucene();

插入：
insert into fulltext values(1,10,'nice', 'java'), (2,20,'good', 'cxx'), (3,30,'nice good', 'python');
insert into fulltext values(4,40,'nice good', 'java cxx');
insert into fulltext values(5,50,'good morning', 'good night');
insert into fulltext values(6,60,'abc def ghi', 'abc def ghi jkl');

//基本查询：
select * from fulltext where lucene('title:good +content:python');
select * from fulltext where lucene('title:good content:python');
select * from fulltext where lucene('title:good -content:python');
//表达式分组：
select * from fulltext where lucene('(title:good OR title:nice) AND content:python');
//字段分组：
select * from fulltext where lucene('title:(good nice)');
//短语查询：两个短语之间是OR关系
select * from fulltext where lucene('title:"nice good" content:"java cxx"'); 
//不指定字段名：查所有字段
select * from fulltext where lucene('good'); 
//通配符查询：“?”通配符一个字符，“*”通配多个字符。
select * from fulltext where lucene('py*n'); 
//相似度查询：后边数字表示相似度，默认是5。
select * from fulltext where lucene('pytz~0.2'); 
//距离查询：abc和jkl之间距离2个单词以内。
select * from fulltext where lucene('content:"abc jkl"~2'); 
//范围查询
select * from fulltext where lucene('primary_id:[2 TO 3]'); 
select * from fulltext where lucene('title:{h TO o}');
//权重查询（或叫优先级查询）
select * from fulltext where lucene('title:good^3 OR title:nice');
```





参考：

- CMake Cookbook中文版：https://www.bookstack.cn/read/CMake-Cookbook/README.md
- Poco文档：https://pocoproject.org/docs/
- lucene查询语法：https://lucene.apache.org/core/2_9_4/queryparsersyntax.html

# clickhouse+tantivy



```
安装rust环境：curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
$ cd contrib/tantivysearch && cargo build --release
$ build clickhouse
安装tantivy-cli：cargo install tantivy-cli
```

查询语法：

```
tantivy search -i wikipedia-index -q <query_expression>
query_expression的形式：
1.并集：(1)"Habana OR Causeway" (2)"Habana Causeway"
2.交集：(1)"Habana AND Causeway" (2)"+Habana +Causeway"
3.短语："\"Habana Causeway\""
```





- https://github.com/tantivy-search/tantivy

- https://github.com/tantivy-search/tantivy-cli

- https://docs.rs/tantivy/0.15.3/tantivy/
- https://tantivy-search.github.io/examples/basic_search.html
- tantivy发布包：https://github.com/rust-lang/crates.io-index/tree/master/ta/nt

