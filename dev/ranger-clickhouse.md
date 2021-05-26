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

Quota policy定义：

```
"name": "qB"
"user": "user1"
ckserver: [
  {
    "cluster": "cluster1"
    "forInterval": [
      {
        "interval": "30 minute",
        "max"：[
          {"execution_time": 0.5}
        ]
      },
      {
        "interval": "5 quarter",
        "max"：[
          {"queries": 321},
          {"errors": 10}
        ]
      }
    ]
  },
  {}
]


chproxy:
{ 
  "id":
  "version":
  "quotas": [
		{
     "clusters": [
        {
          "cluster": "ch01", 
          "requests_per_minute": 4,
          "max_concurrent_queries": 4,
          "max_execution_time": 1m
        },
        {}
      ], 
      "user": "user01",
    },
    {}
  ]
}
      
```



## Ranger开发

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

#### postman调试

文档：http://ranger.incubator.apache.org/apidocs/index.html

重要的接口：

```
获取一个service下的所有policy：
http://centos0.local:6080/service/public/v2/api/service/{servicename}/policy
获取一个service的定义：
http://centos0.local:6080/service/public/v2/api/servicedef/{id}
```

注意：postman只能访问/service/public接口，所以ckman也通过public接口获取数据。