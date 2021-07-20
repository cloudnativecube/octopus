## 导出日志到本地文件

创建字段和query_log表一致但引擎为File的表：

```
CREATE TABLE system.audit_log
(
    `type` Enum8('QueryStart' = 1, 'QueryFinish' = 2, 'ExceptionBeforeStart' = 3, 'ExceptionWhileProcessing' = 4),
    `event_date` Date,
    `event_time` DateTime,
    `event_time_microseconds` DateTime64(6),
    `query_start_time` DateTime,
    `query_start_time_microseconds` DateTime64(6),
    `query_duration_ms` UInt64,
    `read_rows` UInt64,
    `read_bytes` UInt64,
    `written_rows` UInt64,
    `written_bytes` UInt64,
    `result_rows` UInt64,
    `result_bytes` UInt64,
    `memory_usage` UInt64,
    `current_database` String,
    `query` String,
    `normalized_query_hash` UInt64,
    `query_kind` LowCardinality(String),
    `databases` Array(LowCardinality(String)),
    `tables` Array(LowCardinality(String)),
    `columns` Array(LowCardinality(String)),
    `exception_code` Int32,
    `exception` String,
    `stack_trace` String,
    `is_initial_query` UInt8,
    `user` String,
    `query_id` String,
    `address` IPv6,
    `port` UInt16,
    `initial_user` String,
    `initial_query_id` String,
    `initial_address` IPv6,
    `initial_port` UInt16,
    `interface` UInt8,
    `os_user` String,
    `client_hostname` String,
    `client_name` String,
    `client_revision` UInt32,
    `client_version_major` UInt32,
    `client_version_minor` UInt32,
    `client_version_patch` UInt32,
    `http_method` UInt8,
    `http_user_agent` String,
    `http_referer` String,
    `forwarded_for` String,
    `quota_key` String,
    `revision` UInt32,
    `log_comment` String,
    `thread_ids` Array(UInt64),
    `ProfileEvents.Names` Array(String),
    `ProfileEvents.Values` Array(UInt64),
    `Settings.Names` Array(String),
    `Settings.Values` Array(String),
    `used_aggregate_functions` Array(String),
    `used_aggregate_function_combinators` Array(String),
    `used_database_engines` Array(String),
    `used_data_type_families` Array(String),
    `used_dictionaries` Array(String),
    `used_formats` Array(String),
    `used_functions` Array(String),
    `used_storages` Array(String),
    `used_table_functions` Array(String)
)
ENGINE = File(JSONEachRow)
```

产生文件的路径为`/{clickhouse_data_path}/data/system/audit_log/data.JSONEachRow ` 。如果CK的配置不同，那么路径可能也不相同，但相对路径一致。`{clickhouse_data_path}`配置在/etc/clickhouse-server/config.d/config.xml中，查找`<path>`来获取clickhouse根路径，默认是`/var/lib/clickhouse`，然后再加上`data/system/audit_log/data.JSONEachRow`。

创建物化视图：

```
CREATE MATERIALIZED VIEW system.audit_log_mv TO system.audit_log AS select * from system.query_log;
```

配置logrotate（日志按天滚动，保留30天），创建文件/etc/logrotate.d/clickhouse_audit （注意日志路径）：

```
/var/lib/clickhouse/data/system/audit_log/data.JSONEachRow {
    missingok
    rotate 30
    notifempty
    maxsize 100M
    daily
}
```

## 导出日志到kafka

创建kafka table：

```
CREATE TABLE system.audit_log
(
    `type` Enum8('QueryStart' = 1, 'QueryFinish' = 2, 'ExceptionBeforeStart' = 3, 'ExceptionWhileProcessing' = 4),
    `event_date` Date,
    `event_time` DateTime,
    `event_time_microseconds` DateTime64(6),
    `query_start_time` DateTime,
    `query_start_time_microseconds` DateTime64(6),
    `query_duration_ms` UInt64,
    `read_rows` UInt64,
    `read_bytes` UInt64,
    `written_rows` UInt64,
    `written_bytes` UInt64,
    `result_rows` UInt64,
    `result_bytes` UInt64,
    `memory_usage` UInt64,
    `current_database` String,
    `query` String,
    `normalized_query_hash` UInt64,
    `query_kind` LowCardinality(String),
    `databases` Array(LowCardinality(String)),
    `tables` Array(LowCardinality(String)),
    `columns` Array(LowCardinality(String)),
    `exception_code` Int32,
    `exception` String,
    `stack_trace` String,
    `is_initial_query` UInt8,
    `user` String,
    `query_id` String,
    `address` IPv6,
    `port` UInt16,
    `initial_user` String,
    `initial_query_id` String,
    `initial_address` IPv6,
    `initial_port` UInt16,
    `interface` UInt8,
    `os_user` String,
    `client_hostname` String,
    `client_name` String,
    `client_revision` UInt32,
    `client_version_major` UInt32,
    `client_version_minor` UInt32,
    `client_version_patch` UInt32,
    `http_method` UInt8,
    `http_user_agent` String,
    `http_referer` String,
    `forwarded_for` String,
    `quota_key` String,
    `revision` UInt32,
    `log_comment` String,
    `thread_ids` Array(UInt64),
    `ProfileEvents.Names` Array(String),
    `ProfileEvents.Values` Array(UInt64),
    `Settings.Names` Array(String),
    `Settings.Values` Array(String),
    `used_aggregate_functions` Array(String),
    `used_aggregate_function_combinators` Array(String),
    `used_database_engines` Array(String),
    `used_data_type_families` Array(String),
    `used_dictionaries` Array(String),
    `used_formats` Array(String),
    `used_functions` Array(String),
    `used_storages` Array(String),
    `used_table_functions` Array(String),
    `agent_host` String
)
ENGINE = Kafka()
SETTINGS
    kafka_broker_list = 'localhost:9092',
    kafka_topic_list = 'clickhouse-audit',
    kafka_group_name = 'clickhouse-audit',
    kafka_format = 'JSONEachRow';
```

创建物化视图：

```
CREATE MATERIALIZED VIEW system.audit_log_mv TO system.audit_log AS select *, hostname() as agent_host from system.query_log;
```

然后消费kafka topic即可看到日志：

```
# bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic clickhouse-audit
```

