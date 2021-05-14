
# ck审计日志收集&查询（filebeat、logstash、es、kibana、grafana ）
## 注意事项
- 时间同步，不然kibana查询日志会有延迟
## 部署filebeat
### 下载安装filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.8.0-x86_64.rpm  
yum install filebeat-7.8.0-x86_64.rpm  
### 配置filebeat
vim /etc/filebeat/filebeat.yml
```
- type: log
  enabled: true
  paths:
    - /home/servers/clickhouse/data/data/system/audit_log/data.JSONEachRow

setup.kibana:
  host: 10.0.0.13:5601

output.logstash:
  # The Logstash hosts
  hosts: ["localhost:5044"]
```
### 启动filebeat
systemctl start filebeat.service
## 部署logstash
### 下载安装logstash
wget https://artifacts.elastic.co/downloads/logstash/logstash-7.8.0.rpm  
rpm -ivh logstash-7.8.0.rpm  
### 配置logstash
vim /etc/logstash/conf.d/logstash-es.conf
```
input {
  beats {
    port => 5044
    ssl  => false
    codec => json
  }
}

output {
     elasticsearch {
        #action => "index"
        hosts => ["10.0.0.13:19200"]
        index =>  "clickhouse-audit-%{+YYYY.MM.dd}"
        #template => "/home/elasticsearch-6.3.1/config/templates/logstash.json"
        #manage_template => false
        #template_name => "crawl"
        #template_overwrite => true
     }
}
```
### 启动logstash
service logstash start
## 部署es、kibana
### 启动es
docker run -d --name elasticsearch -p 19200:9200 -p 9300:9300 -e "discovery.type=single-node" elasticsearch:7.8.0  
### 检查es
curl 10.0.0.13:19200
```
{
  "name" : "2edf9663e531",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "bva2NMNfQ9GBitsM3yu8-g",
  "version" : {
    "number" : "7.8.0",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "757314695644ea9a1dc2fecd26d1a43856725e65",
    "build_date" : "2020-06-14T19:35:50.234439Z",
    "build_snapshot" : false,
    "lucene_version" : "8.5.1",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```
### 启动kibana
docker run -d --name kibana --link elasticsearch:elasticsearch -p 5601:5601 kibana:7.8.0  
### 访问kibana
http://10.0.0.13:5601/
## 添加grafana dashboard
TODO
