## 版本

- clickhouse v21.4.4.30-stable
- minio RELEASE.2021-04-06T23-11-00Z

## minio

安装文档：https://docs.min.io/minio/baremetal/tutorials/minio-installation.html

启动minio server：

```
# pwd
/export/minio
# cat minio-server.sh
nohup ./minio server --address ":9999" ./data > minio-server.log 2>&1 &
# ./minio-server.sh
```

配置minio client：

```
# cat ~/.mc/config.json
{
	"version": "10",
	"aliases": {
		"local": {
			"url": "http://localhost:9999",
			"accessKey": "minioadmin",
			"secretKey": "minioadmin",
			"api": "S3v4",
			"path": "auto"
		}
}
```

上传一个文件到minio：

```
# cat localdata/data.csv
1,2,3
3,2,1
6,6,6
0,0,0
# mc cp localdata/data.csv local/bucket1
# mc ls local/bucket1
[2021-04-19 16:52:35 CST]    24B data.csv
```

## clickhouse s3

### remote_url_allow_hosts

如果使用s3 table function和table engine，需要在clickhouse-server上配置`remote_url_allow_hosts`：

```
<remote_url_allow_hosts>
    <host>ubuntu0</host>
    <!--<host_regexp></host_regexp>-->
</remote_url_allow_hosts>
```

### table function

在clickhouse-client上查询数据：

```
ubuntu0 :) SELECT * FROM s3('http://ubuntu0:9999/bucket1/data.csv', 'minioadmin', 'minioadmin', 'CSV', 'column1 UInt32, column2 UInt32, column3 UInt32');
┌─column1─┬─column2─┬─column3─┐
│       1 │       2 │       3 │
│       3 │       2 │       1 │
│       6 │       6 │       6 │
│       0 │       0 │       0 │
└─────────┴─────────┴─────────┘

4 rows in set. Elapsed: 0.004 sec.
```

注意，如果不配置上面那个`remote_url_allow_hosts`，就会报：

```
Code: 491. DB::Exception: Received from localhost:9000. DB::Exception: URL "http://ubuntu0:9999/bucket1/data.csv" is not allowed in config.xml.
```

### table engine

先在minio上创建一个文件：

```
# mc cp local/bucket1/data.csv local/bucket1/data2.csv
```

创建table engine，并查询：

```
ubuntu0 :) CREATE TABLE s3_engine_table (column1 UInt32, column2 UInt32, column3 UInt32) ENGINE=S3('http://ubuntu0:9999/bucket1/data2.csv', 'minioadmin', 'minioadmin', 'CSV', 'none');
ubuntu0 :) select * from s3_engine_table;
┌─column1─┬─column2─┬─column3─┐
│       1 │       2 │       3 │
│       3 │       2 │       1 │
│       6 │       6 │       6 │
│       0 │       0 │       0 │
└─────────┴─────────┴─────────┘

4 rows in set. Elapsed: 0.003 sec.
```

注意，如果不事先创建文件，则报以下错误：

```
Code: 499. DB::Exception: Received from localhost:9000. DB::Exception: <?xml version="1.0" encoding="UTF-8"?>
<Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message><Key>key1/</Key><BucketName>bucket1</BucketName><Resource>/bucket1/data2.csv</Resource><RequestId>16776D095F0BE185</RequestId><HostId>062bce5a-789d-498a-8147-8e68dff75f99</HostId></Error>: While executing S3.
```

### storage policy

配置s3 storage policy：

```
<yandex>
    <storage_configuration>
        <disks>
            <s3>
                <type>s3</type>
                <endpoint>http://localhost:9999/bucket1/key1/</endpoint>
                <access_key_id>minioadmin</access_key_id>
                <secret_access_key>minioadmin</secret_access_key>
            </s3>
        </disks>
        <policies>
            <s3poc>
                <volumes>
                    <main>
                        <disk>s3</disk>
                    </main>
                </volumes>
            </s3poc>
        </policies>
    </storage_configuration>
</yandex>
```

注意：endpoint的格式为：`${address}/${bucket}/${key}/`，最后的`/`一定要加。

创建表时使用以上policy，并执行插入和查询操作：

```
ubuntu0 :) CREATE TABLE demo
(
    `name` String,
    `id` Int32,
    `dt` String
)
ENGINE = MergeTree
PARTITION BY dt
ORDER BY id
SETTINGS storage_policy = 's3poc';
ubuntu0 :) insert into demo values('a', 1, '20200202');
ubuntu0 :) select * from demo;
┌─name─┬─id─┬─dt───────┐
│ a    │  1 │ 20200202 │
└──────┴────┴──────────┘

1 rows in set. Elapsed: 0.005 sec.
```

