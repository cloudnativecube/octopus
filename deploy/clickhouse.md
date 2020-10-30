# Clickhouse安装与使用

### 1.版本信息：v20.10.2.20

### 2.安装步骤：

按照官网配置安装(https://clickhouse.tech/#quick-start)，具体步骤如下，需要每台机器都执行：

```
sudo yum install yum-utils 
sudo rpm --import https://repo.clickhouse.tech/CLICKHOUSE-KEY.GPG 
sudo yum-config-manager --add-repo https://repo.clickhouse.tech/rpm/clickhouse.repo 
sudo yum install clickhouse-server clickhouse-client
```

如服务器无网络权限，可从github下载后上传到服务器安装：https://github.com/ClickHouse/ClickHouse/releases/tag/v20.10.2.20-stable：

```
需要下载以下三个安装包
clickhouse-client-20.10.2.20-2.noarch.rpm
clickhouse-server-20.10.2.20-2.noarch.rpm
clickhouse-common-static-20.10.2.20-2.x86_64.rpm，
上传到服务器后，yum安装rpm包:
sudo yum install clickhouse-common-static-20.10.2.20-2.x86_64.rpm
sudo yum install clickhouse-server-20.10.2.20-2.noarch.rpm
sudo yum install clickhouse-client-20.10.2.20-2.noarch.rpm
```

### 3.配置：

创建路径并赋权：

```
mkdir -p /home/servers/clickhouse-20.10.2.20/etc/clickhouse-server/
sudo chown -R clickhouse:clickhouse /home/servers/clickhouse-20.10.2.20
```

修改配置文件 /etc/clickhouse-server/config.xml，并分发到所有节点（注释的位置是需要修改的元素，其他可忽略，使用默认配置）：

```xml
<?xml version="1.0"?>
<yandex>
    <logger>
        <level>trace</level>
        <!-- 修改日志路径 -->
        <log>/home/servers/clickhouse-20.10.2.20/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/home/servers/clickhouse-20.10.2.20/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>

    <send_crash_reports>
        <enabled>false</enabled>
        <anonymize>false</anonymize>         <endpoint>https://6f33034cfe684dd7a3ab9875e57b1c8d@o388870.ingest.sentry.io/5226277</endpoint>
    </send_crash_reports>

    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <mysql_port>9004</mysql_port>

    <openSSL>
        <server> 
            <certificateFile>/home/servers/clickhouse-20.10.2.20/etc/clickhouse-server/server.crt</certificateFile>
            <privateKeyFile>/home/servers/clickhouse-20.10.2.20/etc/clickhouse-server/server.key</privateKeyFile>
            <dhParamsFile>/home/servers/clickhouse-20.10.2.20/etc/clickhouse-server/dhparam.pem</dhParamsFile>
            <verificationMode>none</verificationMode>
            <loadDefaultCAFile>true</loadDefaultCAFile>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
        </server>

        <client> 
            <loadDefaultCAFile>true</loadDefaultCAFile>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
            <invalidCertificateHandler>
                <name>RejectCertificateHandler</name>
            </invalidCertificateHandler>
        </client>
    </openSSL>

    <interserver_http_port>9009</interserver_http_port>
    <!-- 修改监听规则，允许其他机器访问 -->
    <listen_host>::</listen_host>
  
    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>
    <max_server_memory_usage>0</max_server_memory_usage>
    <max_thread_pool_size>10000</max_thread_pool_size>
    <max_server_memory_usage_to_ram_ratio>0.9</max_server_memory_usage_to_ram_ratio>
    <total_memory_profiler_step>4194304</total_memory_profiler_step>
    <total_memory_tracker_sample_probability>0</total_memory_tracker_sample_probability>

    <uncompressed_cache_size>8589934592</uncompressed_cache_size>
    <mark_cache_size>5368709120</mark_cache_size>

    <!-- 修改数据存储路径，结尾带斜线 -->
    <path>/home/servers/clickhouse-20.10.2.20/data/</path>

    <!-- 修改临时数据存储路径，Path to temporary data for processing hard queries. -->
    <tmp_path>/home/servers/clickhouse-20.10.2.20/tmp/</tmp_path>

    <!-- 修改file类型table的数据路径，Directory with user provided files that are accessible by 'file' table function. -->
    <user_files_path>/home/servers/clickhouse-20.10.2.20/data/user_files/</user_files_path>

    <user_directories>
        <users_xml>
            <path>users.xml</path>
        </users_xml>
        <local_directory>
            <!-- 修改使用sql创建的用户存储路径，Path to folder where users created by SQL commands are stored. -->
            <path>/home/servers/clickhouse-20.10.2.20/data/access/</path>
        </local_directory>
    </user_directories>

    <ldap_servers></ldap_servers>
    <default_profile>default</default_profile>
    <custom_settings_prefixes></custom_settings_prefixes>
  
    <default_database>default</default_database>

    <mlock_executable>true</mlock_executable>
  
    <remap_executable>false</remap_executable>
    
    <!-- 修改分布式表的集群配置，incl属性表示可以从其他配置文件读取，可在include_from元素下配置，以下带incl属性的元素见metrika.xml -->
    <remote_servers incl="clickhouse_remote_servers" >
        <test_shard_localhost>  
            <shard>
                <replica>
                    <host>localhost</host>
                    <port>9000</port>
                </replica>
            </shard>
        </test_shard_localhost>
        <test_cluster_two_shards_localhost>
             <shard>
                 <replica>
                     <host>localhost</host>
                     <port>9000</port>
                 </replica>
             </shard>
             <shard>
                 <replica>
                     <host>localhost</host>
                     <port>9000</port>
                 </replica>
             </shard>
        </test_cluster_two_shards_localhost>        
        <test_shard_localhost_secure>
            <shard>
                <replica>
                    <host>localhost</host>
                    <port>9440</port>
                    <secure>1</secure>
                </replica>
            </shard>
        </test_shard_localhost_secure>
        <test_unavailable_shard>
            <shard>
                <replica>
                    <host>localhost</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <replica>
                    <host>localhost</host>
                    <port>1</port>
                </replica>
            </shard>
        </test_unavailable_shard>
    </remote_servers>

    <remote_url_allow_hosts></remote_url_allow_hosts>
    
    <!-- 修改zookeeper配置，用于带副本的表间数据同步及DDL同步 -->
    <zookeeper incl="zookeeper-servers" optional="true" />
  
    <!-- 修改宏配置，用于创建副本表时的变量替换，每个节点的标识不同 -->
    <macros incl="macros" optional="true" />
  
    <builtin_dictionaries_reload_interval>3600</builtin_dictionaries_reload_interval>

    <max_session_timeout>3600</max_session_timeout>

    <default_session_timeout>60</default_session_timeout>

    <query_log>
        <database>system</database>
        <table>query_log</table>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_log>
  
    <trace_log>
        <database>system</database>
        <table>trace_log</table>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </trace_log>

    <query_thread_log>
        <database>system</database>
        <table>query_thread_log</table>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_thread_log>

    <metric_log>
        <database>system</database>
        <table>metric_log</table>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
        <collect_interval_milliseconds>1000</collect_interval_milliseconds>
    </metric_log>

    <asynchronous_metric_log>
        <database>system</database>
        <table>asynchronous_metric_log</table>
        <flush_interval_milliseconds>60000</flush_interval_milliseconds>
    </asynchronous_metric_log>
  
    <crash_log>
        <database>system</database>
        <table>crash_log</table>
        <partition_by />
        <flush_interval_milliseconds>1000</flush_interval_milliseconds>
    </crash_log>

    <dictionaries_config>*_dictionary.xml</dictionaries_config>

    <compression incl="clickhouse_compression"></compression>

    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>

    <graphite_rollup_example>
        <pattern>
            <regexp>click_cost</regexp>
            <function>any</function>
            <retention>
                <age>0</age>
                <precision>3600</precision>
            </retention>
            <retention>
                <age>86400</age>
                <precision>60</precision>
            </retention>
        </pattern>
        <default>
            <function>max</function>
            <retention>
                <age>0</age>
                <precision>60</precision>
            </retention>
            <retention>
                <age>3600</age>
                <precision>300</precision>
            </retention>
            <retention>
                <age>86400</age>
                <precision>3600</precision>
            </retention>
        </default>
    </graphite_rollup_example>

    <!-- 修改schema路径 -->
    <format_schema_path>/home/servers/clickhouse-20.10.2.20/data/format_schemas/</format_schema_path>
    
    <!-- 修改子配置文件路径 -->
    <include_from>/home/servers/clickhouse-20.10.2.20/etc/clickhouse-server/metrika.xml</include_from>
  
</yandex>
```

创建文件 sudo vim /home/servers/clickhouse-20.10.2.20/etc/clickhouse-server/metrika.xml

```xml
<yandex>
    <clickhouse_remote_servers>
        <!-- 集群名称-->
        <!-- 配置两个shard，2个副本的集群 -->
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
        <!-- 配置四个shard，无副本的集群(可用于测试四个节点的分布式性能) -->
        <ck_cluster_four_shards>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.11</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.12</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.13</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.0.0.14</host>
                    <port>9000</port>
                </replica>
            </shard>
        </ck_cluster_four_shards>
    </clickhouse_remote_servers>
  
    <!-- 修改宏配置，创建副本表使用以下配置替换对应的变量，用于区分zookeeper里的路径，配合ck_cluster配置 -->
    <macros>
        <!-- shard id，10.0.0.11和10.0.0.13设置为01，12和14设置为02 -->
        <shard>01</shard>
        <!-- replica id，10.0.0.11设置为ck-01-01，13设置为ck-01-02 -->
        <replica>ck-01-01</replica>
    </macros>

    <networks>
        <ip>::/0</ip>
    </networks>
  
    <!-- 修改zookeeper配置，用于带副本的表间数据同步及DDL同步 -->
    <zookeeper-servers>
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
    </zookeeper-servers>
    
    <clickhouse_compression>
        <case>
            <min_part_size>10000000000</min_part_size>
            <min_part_size_ratio>0.01</min_part_size_ratio>
            <method>lz4</method>
        </case>
    </clickhouse_compression>

</yandex>
```

### 4.启动集群

每台机器分别执行如下命令：

```shell
#启动ck
sudo systemctl start clickhouse-server
#关闭ck
sudo systemctl stop clickhouse-server
#查看ck状态
sudo systemctl status clickhouse-server
```

备注：官方文档中用service启动ck的命令会执行失败，参考如下issue：https://github.com/ClickHouse/ClickHouse/issues/14861

为了便于查看日志，可以给日志路径赋权：

```shell
sudo chmod -R +xr /home/servers/clickhouse-20.10.2.20/log
```

