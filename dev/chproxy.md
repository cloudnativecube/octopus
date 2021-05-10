# chproxy

## ![chproxy](https://upload-images.jianshu.io/upload_images/11631436-e902e900149e28ac.png?imageMogr2/auto-orient/strip|imageView2/2/format/webp)

## chproxy 运行
1. [下载](https://github.com/Vertamedia/chproxy/releases/download/v1.14.0/chproxy-linux-amd64-v1.14.0.tar.gz)

2. 新增config文件

[更多参数详解](https://github.com/Vertamedia/chproxy/tree/master/config)
```
log_debug: true
hack_me_please: true

caches:
  - name: "shortterm"
    dir: "/home/servers/chproxy/data/cache/shortterm"
    max_size: 100Mb
    expire: 10s
    # When multiple requests with identical query simultaneously hit `chproxy`
    # and there is no cached response for the query, then only a single
    # request will be proxied to clickhouse. Other requests will wait
    # for the cached response during this grace duration.
    grace_time: 5s

param_groups:
    # Group name, which may be passed into `params` option on the `user` level.
  - name: "cron-job"
    # List of key-value params to send
    params:
      - key: "max_memory_usage"
        value: "40000000000"

      - key: "max_bytes_before_external_group_by"
        value: "20000000000"

  - name: "web"
    params:
      - key: "max_memory_usage"
        value: "5000000000"

      - key: "max_columns_to_read"
        value: "30"

      - key: "max_execution_time"
        value: "30"

server:
  http:
    listen_addr: ":19090"
    # allowed_networks: ["0.0.0.0/0"]
    # ReadTimeout is the maximum duration for proxy to reading the entire
    # request, including the body.
    # Default value is 1m
    read_timeout: 5m

    # WriteTimeout is the maximum duration for proxy before timing out writes of the response.
    # Default is largest MaxExecutionTime + MaxQueueTime value from Users or Clusters
    write_timeout: 10m

    # IdleTimeout is the maximum amount of time for proxy to wait for the next request.
    # Default is 10m
    idle_timeout: 20m

users:
  - name: "z2"
    password: "1234"
    to_cluster: "ch_cluster"
    to_user: "default"
    requests_per_minute: 5
    cache: "shortterm"
    params: "web"
    # By default all the requests are immediately executed without
    # waiting in the queue.
    max_queue_size: 100

    # The maximum duration the queued requests may wait for their chance
    # to be executed.
    # This option makes sense only if max_queue_size is set.
    # By default requests wait for up to 10 seconds in the queue.
    max_queue_time: 10s



# by default each cluster has `default` user which can be overridden by section `users`
clusters:
  - name: "ch_cluster"
    replicas:
      - name: "replica1"
        nodes: ["centos01:8123", "centos03:8123"]
      - name: "replica2"
        nodes: ["centos02:8123", "centos04:8123"]
    # DEPRECATED: Each cluster node is checked for availability using this interval.
    # By default each node is checked for every 5 seconds.
    # Use `heartbeat.interval`.

    # User configuration for heart beat requests.
    # Credentials of the first user in clusters.users will be used for heart beat requests to clickhouse.
    heartbeat:
      # An interval for checking all cluster nodes for availability
      # By default each node is checked for every 5 seconds.
      interval: 3m

      # A timeout of wait response from cluster nodes
      # By default 3s
      timeout: 10s

      # The parameter to set the URI to request in a health check
      # By default "/?query=SELECT%201"
      request: "/?query=SELECT%201%2B1"

      # Reference response from clickhouse on health check request
      # By default "1\n"
      response: "2\n"

    # Timed out queries are killed using this user.
    # By default `default` user is used.
    kill_query_user:
      name: "default"

    users:
      - name: "default"
        max_concurrent_queries: 4
        max_execution_time: 1m
```
3. 运行

工作目录: `centos01:/home/servers/chproxy`
```
# 启动服务
./chproxy -config=${CONFIG}
```
```
# 清空数据
echo "TRUNCATE TABLE xyz_1_from_xyz ON CLUSTER ck_cluster" | curl -X POST  -u z2:1234 --data-binary @- centos01:19090
# 导入数据
echo "insert into xyz_1_from_xyz_all select * from  xyz_all;" | curl -X POST  -u z2:1234 --data-binary @- centos01:19090
# 查询
echo "select * from xyz_1_from_xyz_all;" | curl -u z2:1234 --data-binary @- centos01:19090

## 查询结果
111222333444555666      123     11
222222333444555666      123     11
333222333444555666      123     11
111222333444555666      123     11

# 重新加载config
kill -1 `ps -ef | grep chproxy | grep  -v grep | awk '{print $2}'`
```

## 配置文件分析
### Users
chproxy 内置了`账户体系`，有自己的一套账户名密码。 chproxy user 与 ck user 可以一一对应， 也可以多个chproxy user 对应一个ck user。

建议：使用一一对应的方式，避免复杂的运维

### Clusters
chproxy 内置了cluster。灵活的配置，带来的就是运维的难度。

### 负载均衡
在 *chproxy cluster* 层面，基于least loaded 和 round robin均衡负载. 即均衡策略与chproxy user， ck user并没有关系

代码分析：
```
func (rp *reverseProxy) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	startTime := time.Now()
	s, status, err := rp.getScope(req)
    // ...
}
func (rp *reverseProxy) getScope(req *http.Request) (*scope, int, error) {
    // 鉴权
	name, password := getAuth(req)
    // ...
    // u chproxy user, c chproxy cluster, cu, clickhouse user
	s := newScope(req, u, c, cu)
	return s, 0, nil
}
func newScope(req *http.Request, u *user, c *cluster, cu *clusterUser) *scope {
    // 一个chproxy cluster 可以有多个 ckproxy user。
    // 这里取 host 时， 并没有考虑 chproxy user 维度
    // 因此，chproxy 负载均衡是`chproxy cluster`级的均衡
	h := c.getHost()
}
// 使用负载均衡策略，先选择replica. 再次使用均衡策略，选择Host(shard/Node)
// least loaded + round robin均衡负载比较简单， 不再赘述
```

### chproxy Post
支持, 在上边运行，已经验证了。

### chproxy param_groups

在config 中可以设置每个chproxy user （本质是clickhouse user）的资源配置。如配置文件中 `param_groups`

作用方式参考https://clickhouse.tech/docs/en/operations/settings/

配置完毕后，观察log中URL。
```
DEBUG: 2021/04/19 07:14:26 proxy.go:113: [ Id: 167730A408247784; User "z2"(1) proxying as "default"(1) to "centos01:8123"(1); RemoteAddr: "10.0.0.107:3866"; LocalAddr: "10.0.0.11:19090"; Duration: 6243 μs]: request success; query: "select * from xyz_1_from_xyz_all;\n"; URL: "http://centos01:8123/?max_columns_to_read=30&max_execution_time=30&max_memory_usage=5000000000&query_id=167730A408247784"
```

### cache
配置上cache查询的两次log
```
# 第一次
DEBUG: 2021/04/19 07:50:24 proxy.go:74: [ Id: 167730A408247787; User "z2"(1) proxying as "default"(1) to "centos02:8123"(1); RemoteAddr: "10.0.0.107:9400"; LocalAddr: "10.0.0.11:19090"; Duration: 41 μs]: request start
DEBUG: 2021/04/19 07:50:24 proxy.go:293: [ Id: 167730A408247787; User "z2"(1) proxying as "default"(1) to "centos02:8123"(1); RemoteAddr: "10.0.0.107:9400"; LocalAddr: "10.0.0.11:19090"; Duration: 189 μs]: cache miss
DEBUG: 2021/04/19 07:50:24 proxy.go:113: [ Id: 167730A408247787; User "z2"(1) proxying as "default"(1) to "centos02:8123"(1); RemoteAddr: "10.0.0.107:9400"; LocalAddr: "10.0.0.11:19090"; Duration: 6454 μs]: request success; query: "select * from xyz_1_from_xyz_all;\n"; URL: "http://centos02:8123/?max_columns_to_read=30&max_execution_time=30&max_memory_usage=5000000000&query_id=167730A408247787"
# 第二次
DEBUG: 2021/04/19 07:50:26 proxy.go:74: [ Id: 167730A408247788; User "z2"(1) proxying as "default"(1) to "centos01:8123"(1); RemoteAddr: "10.0.0.107:9404"; LocalAddr: "10.0.0.11:19090"; Duration: 41 μs]: request start
DEBUG: 2021/04/19 07:50:26 proxy.go:280: [ Id: 167730A408247788; User "z2"(1) proxying as "default"(1) to "centos01:8123"(1); RemoteAddr: "10.0.0.107:9404"; LocalAddr: "10.0.0.11:19090"; Duration: 291 μs]: cache hit
DEBUG: 2021/04/19 07:50:26 proxy.go:113: [ Id: 167730A408247788; User "z2"(1) proxying as "default"(1) to "centos01:8123"(1); RemoteAddr: "10.0.0.107:9404"; LocalAddr: "10.0.0.11:19090"; Duration: 343 μs]: request success; query: "select * from xyz_1_from_xyz_all;\n"; URL: "http://centos01:8123/?max_columns_to_readwo=30&max_execution_time=30&max_memory_usage=5000000000&query_id=167730A408247788"
```
第一次为`cache miss`, 第二次为`cache hit`
查看一下cache 文件
`[hadoop@centos01 chproxy]$ cat data/cache/shortterm/ef9ae03d7a34499b952bdab656221084`
```
(text/tab-separated-values; charset=UTF-8111222333444555666     123     11
222222333444555666      123     11
333222333444555666      123     11
111222333444555666      123     11
```
运行一个执行时间较长的sql

sql: `select max(cs_net_paid) as m1, avg(cs_sales_price) as a1, count() as c1  from ssb.catalog_sales_0224_all group by cs_bill_customer_sk order by a1, m1 desc, c1 limit 10` 

cache miss 花费：497ms

cache hit  花费: 26ms

### [chproxy 必要性](https://github.com/Vertamedia/chproxy#why-it-was-created)
`max_execution_time` may be exceeded due to the current implementation deficiencies.  参考：https://clickhouse.tech/docs/en/operations/settings/query-complexity/#max-execution-time

`max_concurrent_queries` works only on a per-node basis. There is no way to limit the number of concurrent queries on a cluster if queries are spread across cluster nodes.

### heartbeat
定时检查`worker`状态, 健康度影响`Host`选择（负载均衡）

### replica & Node
目前认为区分不大。代码如下
```
func newReplicas(replicasCfg []config.Replica, nodes []string, scheme string, c *cluster) ([]*replica, error) {
	if len(nodes) > 0 {
		// No replicas, just flat nodes. Create default replica
		// containing all the nodes.
		r := &replica{
			cluster: c,
			name:    "default",
		}
		hosts, err := newNodes(nodes, scheme, r)
		if err != nil {
			return nil, err
		}
		r.hosts = hosts
		return []*replica{r}, nil
	}

	replicas := make([]*replica, len(replicasCfg))
	for i, rCfg := range replicasCfg {
		r := &replica{
			cluster: c,
			name:    rCfg.Name,
		}
		hosts, err := newNodes(rCfg.Nodes, scheme, r)
		if err != nil {
			return nil, fmt.Errorf("cannot initialize replica %q: %s", rCfg.Name, err)
		}
		r.hosts = hosts
		replicas[i] = r
	}
	return replicas, nil
}
```

### 连续insert相同数据问题

第一插入shard时， 可以成功。 第二次插入（该shard和第一次的shard互为副本），则插入不成功。
@晓珍解释了 插入相同数据数据会先计算hash，如果在zk中已经存在了，则忽略这次插入。
```
// 计算block_id
{
SipHash hash;
part->checksums.computeTotalChecksumDataOnly(hash);
union
{
    char bytes[16];
    UInt64 words[2];
} hash_value;
hash.get128(hash_value.bytes);

/// We add the hash from the data and partition identifier to deduplication ID.
/// That is, do not insert the same data to the same partition twice.
block_id = part->info.partition_id + "_" + toString(hash_value.words[0]) + "_" + toString(hash_value.words[1]);
}
// 判断节点是否存在
{
bool deduplicate_block = !block_id.empty();
String block_id_path = deduplicate_block ? storage.zookeeper_path + "/blocks/" + block_id : "";
auto block_number_lock = storage.allocateBlockNumber(part->info.partition_id, zookeeper, block_id_path);
}
```


### 可能导致困惑的参数
#### 情景1
```
requests_per_minute: 5
max_queue_time: 10s
```
在1分钟内连续请求5次，均可正常返回。请求第6次时，会等待会等待`10s`,再返回一下错误信息
```
ERROR: 2021/04/19 10:54:08 proxy.go:69: [ Id: 16773CF8513C519C; User "z2"(0) proxying as "default"(0) to "centos01:8123"(0); RemoteAddr: "10.0.0.107:3887"; LocalAddr: "10.0.0.11:19090"; Duration: 1000018
```
看了一[源码](https://github.com/Vertamedia/chproxy/blob/master/scope.go#L153)，定性描述：当超过某个Limit时，会先查询加入队列执行sleep，直到sleep了 max_queue_time，Limit依然存在，则报错；如果Limit不存在了，则正常执行查询。

当然如果，在一分钟内的后10s请求，则会正常查询。

但是，这样会给用户一种查询时`快`时`慢`的错觉。


### BTW
chproxy 代码挺清爽

## 疑问
1. chproxy 会成为网络带宽的瓶颈吗？
2. ck的资源配置是针对单点的。当单点ck达到熔断，则不允许查询，也是合理的吧。
3. 是否能够通过`heartbeat`机制，完成自动下线？ 


## 总结
1. chproxy有自己的user和cluster,使用起来非常灵活。
2. 合理使用cache【cache设定具体问题具体分析】
3. chproxy 负载均衡是在 `chproxy cluster`级别
4. 合理设定chproxy params。


## 参考文献
1. https://github.com/Vertamedia/chproxy
2. https://www.jianshu.com/p/9498fedcfee7