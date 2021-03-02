# 流程

### 配置文件

```
<yandex>
    <!-- Configuration of clusters as in an ordinary server config -->
    <remote_servers>
        <source_cluster>
            <shard>
                <internal_replication>false</internal_replication>
                    <replica>
                        <host>127.0.0.1</host>
                        <port>9000</port>
                        <!--
                        <user>default</user>
                        <password>default</password>
                        <secure>1</secure>
                        -->
                    </replica>
            </shard>
            ...
        </source_cluster>

        <destination_cluster>
        ...
        </destination_cluster>
    </remote_servers>
    
    <tables>
        <table_hits>
            <cluster_rebalance>source_cluster</cluster_rebalance>
            <database_rebalance>test</database_rebalance>
            <table_rebalance>hits</table_rebalance>
            <shard_new>
              <host>127.0.0.1</host>
              <port>9000</port>
            </shard_new>
        </table_hits>
    </tables>
</yandex>
```

### 流程

源shard：扩容之前的所有shard。

目标shard：新扩容的shard。

1.遍历每个源shard，从它们的system.parts中查出所有源part的信息（包括part name、所在shard、大小）

2.汇总所有part，运行rabalance算法，计算出哪些part需要移动到目标shard

3.遍历每个需要移动的part，向其源shard发出“MOVE PART”指令。执行以下语句：

```
ALTER TABLE t MOVE PART x TO SHARD shard_id
```

### rebalance算法

#### part大小的度量指标

part的文件信息：

```
# ll /var/lib/clickhouse/data/default/hits/all_1_8_2
总用量 8004
-rw-r----- 1 clickhouse clickhouse     260 2月  23 13:53 checksums.txt
-rw-r----- 1 clickhouse clickhouse      59 2月  23 13:53 columns.txt
-rw-r----- 1 clickhouse clickhouse       7 2月  23 13:53 count.txt
-rw-r----- 1 clickhouse clickhouse 4017273 2月  23 13:53 id.bin
-rw-r----- 1 clickhouse clickhouse    2976 2月  23 13:53 id.mrk2
-rw-r----- 1 clickhouse clickhouse     496 2月  23 13:53 primary.idx
-rw-r----- 1 clickhouse clickhouse 4152462 2月  23 13:53 v.bin
-rw-r----- 1 clickhouse clickhouse    2976 2月  23 13:53 v.mrk2
```

part在元数据表中的字段：

```
centos1.local :) select * from system.parts where table = 'hits' and name='all_1_8_2' \G
bytes_on_disk:                         8176190
data_compressed_bytes:                 8169735
data_uncompressed_bytes:               10889672
marks_bytes:                           5952
primary_key_bytes_in_memory:           496
```

可以看出其含义如下：

```
bytes_on_disk: part的整个目录大小
data_compressed_bytes: 所有列的bin文件大小之和
marks_bytes: 所有列的mark文件大小之和
primary_key_bytes_in_memory: primary.idx文件大小
```

所以，取bytes_on_disk作为计算part数据量大小的度量指标。

#### 简易算法流程

1.计算源shard上所有part的大小之和，除以（源shard数+目标shard数），即为rebalance之后期望的平均值（设为e）。

2.取出源shard里负载最大的一个，将其中的part按从大到小排序，从其中选择一个最优part满足以下条件：

```
设：
  源shard移走part之后的数据量为：x = src_shard - part
  目标shard添加part之后的数据量为：y = dst_shard + part
  移动part之前与平均值的差：diff1 = abs(src_shard - e) + abs(dst_shard - e)
  移动part之后与平均值的差：diff2 = abs(x - e) + abs(y - e)
使：
  (1)diff2 < diff1：目的是让移动之后减小
  (2)diff2在所有part中最小：目的是让源shard和目标shard最接近平均值
```

3.经过第2步之后每个shard都对应一个最优part，将所有shard的“最优part”再比较，得到一个“最终part”



