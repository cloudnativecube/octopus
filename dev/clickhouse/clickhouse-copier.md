## Clickhouse 数据备份和迁移 之 clickhouse-copier

工作目录为：`/home/zhangzhen361/workspace/clickhouse/clickhouse-copier`

假定有两个CK集群, A(port 9000), B(port 9001)。A为源，B为目标

### 新建一个zookeeper配置
命名为zookeeper.xml,如下
```
<yandex>
    <logger>
        <level>trace</level>
        <size>100M</size>
        <count>3</count>
    </logger>
    <!--  -->
    <zookeeper>
        <node>
            <host>centos01</host>
            <port>2181</port>
        </node>
        <node>
            <host>centos02</host>
            <port>2181</port>
        </node>
        <node>
            <host>centos03</host>
            <port>2181</port>
        </node>
    </zookeeper>
</yandex>
```
### 同步任务配置文件
命名为 copy-job.xml
```
<yandex>
    <!-- Configuration of clusters as in an ordinary server config -->
    <remote_servers>
        <!-- 源集群 -->
        <ck_cluster>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.11</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>10.0.0.13</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.12</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>10.0.0.14</host>
                    <port>9000</port>
                </replica>
            </shard>
        </ck_cluster>
        <!-- 目标集群  -->
        <ck_cluster_copyed>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.11</host>
                    <port>9001</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.12</host>
                    <port>9001</port>
                </replica>
            </shard>
        </ck_cluster_copyed>
    </remote_servers>

    <!-- How many simultaneously active workers are possible. If you run more workers superfluous workers will sleep. -->
    <max_workers>2</max_workers>

    <!-- Setting used to fetch (pull) data from source cluster tables -->
    <settings_pull>
        <readonly>1</readonly>
    </settings_pull>

    <!-- Setting used to insert (push) data to destination cluster tables -->
    <settings_push>
        <readonly>0</readonly>
    </settings_push>

    <!-- Common setting for fetch (pull) and insert (push) operations. Also, copier process context uses it.
         They are overlaid by <settings_pull/> and <settings_push/> respectively. -->
    <settings>
        <connect_timeout>3</connect_timeout>
        <!-- Sync insert is set forcibly, leave it here just in case. -->
        <insert_distributed_sync>1</insert_distributed_sync>
    </settings>

    <!-- Copying tasks description.
         You could specify several table task in the same task description (in the same ZooKeeper node), they will be performed
         sequentially.
    -->
    <tables>
        <!-- A table task, copies one table. -->
        <table_hits>
            <!-- Source cluster name (from <remote_servers/> section) and tables in it that should be copied -->
            <!-- 源表信息 -->
            <cluster_pull>ck_cluster</cluster_pull>
            <database_pull>ssb</database_pull>
            <table_pull>ship_mode_0104_2</table_pull>

            <!-- Destination cluster name and tables in which the data should be inserted -->
            <!-- 目标表信息 -->
            <cluster_push>ck_cluster_copyed</cluster_push>
            <database_push>default</database_push>
            <table_push>ship_mode_0104_2</table_push>

            <!-- Engine of destination tables.
                 If destination tables have not be created, workers create them using columns definition from source tables and engine
                 definition from here.

                 NOTE: If the first worker starts insert data and detects that destination partition is not empty then the partition will
                 be dropped and refilled, take it into account if you already have some data in destination tables. You could directly
                 specify partitions that should be copied in <enabled_partitions/>, they should be in quoted format like partition column of
                 system.parts table.
            -->
            <!-- engine 根据业务需求调整 -->
            <engine>
            ENGINE = MergeTree()
            ORDER BY sm_ship_mode_sk
            SETTINGS index_granularity = 8192
            </engine>

            <!-- Sharding key used to insert data to destination cluster -->
            <!-- sharding_key 根据业务需求调整, 有多种方案 -->
            <sharding_key>rand()</sharding_key>

            <!-- 一些可选的过滤信息 -->
            <!-- Optional expression that filter data while pull them from source servers -->
            <!--
            <where_condition>CounterID != 0</where_condition>
            -->

            <!-- This section specifies partitions that should be copied, other partition will be ignored.
                 Partition names should have the same format as
                 partition column of system.parts table (i.e. a quoted text).
                 Since partition key of source and destination cluster could be different,
                 these partition names specify destination partitions.

                 NOTE: In spite of this section is optional (if it is not specified, all partitions will be copied),
                 it is strictly recommended to specify them explicitly.
                 If you already have some ready partitions on destination cluster they
                 will be removed at the start of the copying since they will be interpeted
                 as unfinished data from the previous copying!!!
            -->

            <!--
            <enabled_partitions>
                <partition>'2018-02-26'</partition>
                <partition>'2018-03-05'</partition>
                ...
            </enabled_partitions>
            -->
        </table_hits>
        <!-- Next table to copy. It is not copied until previous table is copying. -->
        <!-- 支持多表备份 -->

    </tables>
</yandex>
```

### 任务信息提交
```
/home/servers/zookeeper-3.6.2/bin/zkCli.sh -server centos01:2181 create /clickhouse/copytasks_test ""
/home/servers/zookeeper-3.6.2/bin/zkCli.sh -server centos01:2181 create /clickhouse/copytasks_test/task1 ""
/home/servers/zookeeper-3.6.2/bin/zkCli.sh -server centos01:2181 create /clickhouse/copytasks_test/task1/description "`cat copy-job.xml`"
# # update
# /home/servers/zookeeper-3.6.2/bin/zkCli.sh -server centos01:2181 set /clickhouse/copytasks_test/task1/description "`cat copy-job.xml`"
```

### 同步
```
clickhouse-copier  --daemon \
  --config ./zookeeper.xml \
  --task-path /clickhouse/copytasks_test/task1 \
  --base-dir ./clickhouse-copier
```

### 注意事项
1. 两个集群的名字不能一样。(在任务配置文件中显而易见)
2. 同步任务完成后，（如同步失败）需要再次同步，此时应改变task名称（强烈建议），或者修改目标表名。
原因是zk会记录如下信息. 如果task名称和表名不改变，则不会执行同步
```
[zk: localhost:2181(CONNECTED) 10] ls /clickhouse/copytasks_test/task3/tables
[ck_cluster_copyed.default.ship_mode_0104_1]
```



## 参考文档
1. https://xiaoz.co/2020/08/20/clickhouse-backup/
2. https://clickhouse.tech/docs/en/operations/utilities/clickhouse-copier/
3. http://cxy7.com/articles/2019/10/14/1571068670959.html 
4. https://zhuanlan.zhihu.com/p/220172155
