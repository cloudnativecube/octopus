CREATE VIEW system.view_parts ON CLUSTER all_node_cluster AS (select *,hostname() as hostname from system.parts);  
create table system.distributed_view_parts ON CLUSTER all_node_cluster as system.view_parts  
ENGINE = Distributed(all_node_cluster, system, view_parts, rand());  

grafana-cli plugins install vertamedia-clickhouse-datasource. 

CREATE USER grafana on cluster all_node_cluster HOST IP '0.0.0.0/0' IDENTIFIED WITH sha256_password BY '2020root';  
GRANT ON CLUSTER all_node_cluster ALL ON *.* TO grafana;  

```
  - name: "all_node_cluster"
    scheme: "http"
    replicas:
      - name: "replica1"
        nodes: ["centos01:8123", "centos02:8123", "centos03:8123", "centos04:8123"]
    heartbeat_interval: 1m
    kill_query_user:
      name: "default"
    users:
      - name: "default"
        password: ""
        max_concurrent_queries: 4
        max_execution_time: 1m
        max_queue_size: 25
        max_queue_time: 1s
        deny_http: false
        allow_cors: true
        requests_per_minute: 100
        cache: "shortterm"
        params: "web"
```
http://10.0.0.11:3000/d/sAj3LyjGz/ck-sql?orgId=1  
