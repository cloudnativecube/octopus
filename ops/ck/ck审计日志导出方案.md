### 日志路径
/home/servers/clickhouse/data/data/system/audit_log/data.JSONEachRow  
（CK的配置不同路径可能也不相同，但相对路径一致,路径配置在/etc/clickhouse-server/config.d/config.xml中查找<path>来获取clickhouse根路径，然后再加上data/system/audit_log/data.JSONEachRow）  


### 配置步骤(每一台clickhouse机器都需要配置)


#### 创建字段和query_log表一致但引擎为File的表
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
    `columns` Array(LowCardinality(String))d,
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

#### 创建物化视图

CREATE MATERIALIZED VIEW system.view_query_log TO system.audit_log AS select * from system.query_log;


#### 配置logrotate
日志按天滚动，保留30天
vim /etc/logrotate.d/clickhouse_audit （注意日志路径篇日志正确）
```
/home/servers/clickhouse/data/data/system/audit_log/data.JSONEachRow {
    missingok
    rotate 30
    notifempty
    maxsize 100M
    daily
}
```

