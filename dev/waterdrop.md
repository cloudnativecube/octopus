# waterdrop开发文档

## 规则

- waterdrop自己的参数名都是“小写字母+下划线”的格式，如pre_sql、bulk_size。
- plugin的参数名一般使用plugin名字作为前缀，后面拼接plugin自己的参数名，如clickhouse.socket_timeout，其中socket_timeout是clickhouse自己的参数。但是es自己的参数本来就是以es作为前缀了，如es.batch.size.entries，直接使用即可。

## output plugin hbase

### 配置参数

| name               | type    | required | default value | 备注              |
| ------------------ | ------- | -------- | ------------- | ----------------- |
| load_mode          | string  | no       | bulkload      |                   |
| create_table       | boolean | no       | false         |                   |
| hbase_table_name   | string  | yes      | -             | bulkload方式需要  |
| staging_dir        | string  | yes      | -             | bulkload方式需要  |
| table_catalog_file | string  | yes      | -             | dataframe方式需要 |
| regions            | number  | yes      | -             | dataframe方式需要 |
|                    |         |          |               |                   |
|                    |         |          |               |                   |

##### load_mode

可选值是“bulkload”、“dataframe”。

##### create_table

是否自动创建表。如果是true，则删除原来的表并创建新表；如果是false，当已经存在该表时将报错。

实现方式：

(1) dataframe方式：如果设置regions大于3，则hbase-connector根据HBaseTableCatalog.newTable判断大于3，会自动创建新表。

(2) bulkload方式：

##### hbase_table_name

bulkload方式时，加载数据到hbase的表的名字。

##### staging_dir

bulkload方式时，产生的HFile所在的目录。该目录不能是已经存在的目录。

##### table_catalog_file

dataframe方式时，映射到hbase表的catalog所在的文件。

##### regions

dataframe方式时，指定的region的数量。如果该值大于3，则创建新的HBase表。

### 配置示例

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

