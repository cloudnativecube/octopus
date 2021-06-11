# Ranger对接ClickHouse

## 支持的clickhouse权限模型

### allow privileges

resouce: database, table

action

```
SELECT
INSERT
ALTER
CREATE
DROP
TRUNCATE
OPTIMIZE
```

### deny privileges

## 支持的clickhouse quota模型

语句：

```
ALTER QUOTA IF EXISTS qB ON CLUSTER cluster1 FOR INTERVAL 30 minute MAX execution_time = 0.5, FOR INTERVAL 5 quarter MAX queries = 321, errors = 10 TO default;
```

chproxy使用的quota policy配置：

```
max_concurrent_queries=10
max_execution_time=120
requests_per_minute=60
```

## Ranger开发

#### 编译命令

```
# mvn clean package -DskipTests -Dmaven.test.skip=true
```

#### 源码文件

关键的源码目录和文件：

```
1. 前端js脚本：security-admin/src/main/webapp/scripts/
2. service定义的json文件：agents-common/src/main/resources/service-defs/
3. 编译之后，service定义的json文件会打进这个jar包里：ranger-plugins-common-2.1.0.jar
```

#### ranger-servicedef-clickhouse.json

ranger-servicedef-clickhouse.json里的关键字段

```
1. "implClass": "",  //clickhouse使用默认的RangerService类，不需要有自己的实现。
2. 当创建policy时，如果resource类型选择quota，表示这是一条quota policy规则；否则就是authorization policy规则。
3. 当创建service时，service名字表示clickhouse的集群名字。
```

#### 表

重要的数据表：

```
x_service_def: service的定义表
x_resource_def: resource的定义表
x_access_type_def: 操作类型的定义表
```

#### 库表初始化

1.库表里的数据的初始化，入口是在`ChangePasswordUtil.java`的这行代码：

```
ChangePasswordUtil loader = (ChangePasswordUtil) CLIUtil.getBean(ChangePasswordUtil.class);
```

然后进入`CLIUtil::init()`，由spring framework触发解析json，加载到表里。

2.对库表的初始化进行调试的方法：

```
在mysql上执行：drop database ranger，然后重新执行setup.sh
```

3.加载库表数据的日志文件：ranger-2.1.0-admin/ews/logs/ranger_db_patch.log

#### 调试配置

如果改了install.properties里的配置，则重新执行setup.sh，重启ranger-admin。

#### ranger-admin日志文件

日志文件：ranger-2.1.0-admin/ews/webapp/WEB-INF/log4j.properties

打开debug：

```
log4j.category.org.apache.ranger=debug,xa_log_appender
```

#### postman调试

文档：http://ranger.incubator.apache.org/apidocs/index.html

重要的接口：

```
获取一个service的所有policy：
http://centos0.local:6080/service/public/v2/api/service/{servicename}/policy
获取一个service的定义：
http://centos0.local:6080/service/public/v2/api/servicedef/{id}
获取一个service的所有policy（该接口不会走认证）：
http://centos0.local:6080/service/plugins/policies/download/{servicename}
```

#### ranger auditlog

1.ranger侧代码

auditlog接口调用的入口：

```
getAccessLogs@AssetREST.java =>
getAccessLogs@AssetMgr.java =>
searchXAccessAudits@ElasticSearchAccessAuditsService.java
```

2.logstash配置

参考：

- logstash最佳实践：https://doc.yonyoucloud.com/doc/logstash-best-practice-cn/index.html
- 官方文档：https://www.elastic.co/guide/en/logstash/7.x/introduction.html

各plugin把auditlog发到elasticsearch，然后ranger从elasticsearch读取日志展示到界面上。

以下是auditlog在es中的index mapping：

```
{
  "mappings": {
    "_doc": {
      "properties": {
        "access": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "action": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "agent": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "agentHost": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "cliIP": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "cluster": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "enforcer": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "event_count": {
          "type": "long"
        },
        "event_dur_ms": {
          "type": "long"
        },
        "evtTime": {
          "type": "date"
        },
        "id": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "logType": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "policy": {
          "type": "long"
        },
        "policyVersion": {
          "type": "long"
        },
        "repo": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "repoType": {
          "type": "long"
        },
        "reqData": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "reqUser": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "resType": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "resource": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "result": {
          "type": "long"
        },
        "seq_num": {
          "type": "long"
        },
        "sess": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        }
      }
    }
  }
}
```

clickhouse的auditlog要兼容ranger的auditlog，需要注意字段类型。ranger的auditlog大部分字段类型都是text，以下几个字段的类型是例外：

```
"event_count": "long"
"event_dur_ms": "long"
"evtTime": "date"
"policy": "long"
"policyVersion": "long"
"repoType": "long"
"result": "long"
"seq_num": "long"
```

#### logstash配置文件

以下是调通的配置文件：

```
input {
  beats {
    port => 5044
    ssl  => false
    codec => json
    add_field => { "branch" => "ranger" }
  }
}

filter {
  if [branch] == "kibana" {
    mutate {
      convert => {"query_duration_ms" =>"integer" }
    }
  }

  if [branch] == "ranger" {
    if [type] == "QueryStart" {
      drop {}
    }
    truncate {
      fields => "event_time_microseconds"
      length_bytes => 23
    }
    date {
      match => [ "event_time_microseconds", "yyyy-MM-dd HH:mm:ss.SSS" ]
      target => "evtTime"
    }
    mutate {
      remove_field => [
        "@timestamp",
        "@version",
        "event_time",
        "event_time_microseconds",
        "query_start_time",
        "query_start_time_microseconds",
        "event_date",
        "query_duration_ms",
        "stack_trace",
        "initial_port",
        "query_id",
        "used_functions",
        "used_table_functions",
        "quota_key",
        "used_data_type_families",
        "used_database_engines",
        "used_formats",
        "os_user",
        "user",
        "ecs",
        "client_version_patch",
        "normalized_query_hash",
        "client_version_major",
        "client_version_minor",
        "log_comment",
        "interface",
        "is_initial_query",
        "agent",
        "log",
        "memory_usage",
        "used_storages",
        "input",
        "Settings.Names", "Settings.Values",
        "read_rows", "written_rows", "result_rows", "read_bytes", "written_bytes", "result_bytes",
        "thread_ids",
        "http_method",
        "forwarded_for",
        "revision",
        "http_referer",
        "port",
        "client_revision",
        "tags",
        "used_dictionaries",
        "used_aggregate_functions",
        "used_aggregate_function_combinators",
        "ProfileEvents.Values", "ProfileEvents.Names",
        "fields"
      ]
    }
    mutate {
      rename => {
        "query_kind" => "access"
        "initial_query_id" => "sess"
        "initial_user" => "reqUser"
        "query" => "reqData"
        "initial_address" => "cliIP"
      }
    }
    mutate {
      add_field => {
        "agent" => "ClickHouse"
        "agentHost" => "%{[host][name]}"
        "logType" => "RangerAudit"
        "cluster" => ""
        "zoneName" => ""
        "reason" => ""
        "policyVersion" => 1
        "policy" => 0
        "seq_num" => 1
        "result" => 1
        "event_count" => 1
        "event_dur_ms" => 0
        "tags" => [ "null" ]
        "action" => "%{access}"
        "id" => "%{sess}"
        "repoType" => 150
        "repo" => "clickhouse"
        "enforcer" => "ranger-acl"
      }
      remove_field => [
        "host"
      ]
    }
    mutate {
      convert => {
        "repoType" => "integer"
        "result" => "integer"
        "policyVersion" => "integer"
        "policy" => integer
        "seq_num" => "integer"
        "event_count" => "integer"
        "event_dur_ms" => "integer"
      }
    }

    if [exception_code] == 497 {
      mutate {
        update => { "result" => 0 }
      }
    }
  }
}

output {
  if [branch] == "kibana" {
    elasticsearch {
      hosts => ["10.0.0.13:19200"]
      index =>  "clickhouse-audit-%{+YYYY.MM.dd}"
    }
  }

  if [branch] == "ranger" {
    elasticsearch {
      hosts => ["10.0.0.11:19200"]
      index =>  "ranger-audit"
    }
  }
}
```

