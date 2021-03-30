# prometheus部署&监控接入
## prometheus部署
### prometheus访问地址
10.0.0.11:9090
### 下载安装包
wget https://github.com/prometheus/prometheus/releases/download/v2.25.1/prometheus-2.25.1.linux-amd64.tar.gz
### 创建用户和目录并赋权
useradd --no-create-home --shell /bin/false prometheus  
mkdir /etc/prometheus  
mkdir /var/lib/prometheus  
chown prometheus:prometheus /etc/prometheus  
chown prometheus:prometheus /var/lib/prometheus  
### 安装
tar -xvzf prometheus-2.25.1.linux-amd64.tar.gz  
mv prometheus-2.25.1.linux-amd64 prometheuspackage  
cp prometheuspackage/prometheus /usr/local/bin/
cp prometheuspackage/promtool /usr/local/bin/  
chown prometheus:prometheus /usr/local/bin/prometheus  
chown prometheus:prometheus /usr/local/bin/promtool  
cp -r prometheuspackage/consoles /etc/prometheus  
cp -r prometheuspackage/console_libraries /etc/prometheus  
chown -R prometheus:prometheus /etc/prometheus/consoles  
chown -R prometheus:prometheus /etc/prometheus/console_libraries  
### 配置prometheus
vim /etc/prometheus/prometheus.yml
```
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
```
### 配置启动文件
vim /etc/systemd/system/prometheus.service  
```
Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
LimitCORE=infinity
LimitNOFILE=409600
LimitNPROC=409600
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.enable-lifecycle \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--storage.tsdb.retention.time=4w
[Install]
WantedBy=multi-user.target
```
### 启动&reload命令
启动:  
systemctl daemon-reload  
systemctl start prometheus  
systemctl enable prometheus  
reload:  
curl -X POST http://10.0.0.11:9090/-/reload  

## grafana部署
### grafana访问地址
10.0.0.11:3000  
账号密码：admin/2020root
#### 安装部署
wget https://dl.grafana.com/oss/release/grafana-7.4.5-1.x86_64.rpm  
yum install -y grafana-7.4.5-1.x86_64.rpm  
systemctl start grafana-server  
systemctl enable grafana-server  
### grafana添加prometheus数据源
![image](https://user-images.githubusercontent.com/10804016/112923976-de18c880-9141-11eb-971a-f76c210fb8d2.png)

## 接入ClickHouse
### 暴露CK监控接口
vim /etc/clickhouse-server/config.d/config.xml  
```
    <prometheus>
        <endpoint>/metrics</endpoint>
        <port>9363</port>

        <metrics>true</metrics>
        <events>true</events>
        <asynchronous_metrics>true</asynchronous_metrics>
        <status_info>true</status_info>
    </prometheus>
```
重启  
clickhouse restart  
### 接入prometheus
vim /etc/prometheus/prometheus.yml
```
  - job_name: 'clickhouse'
    scrape_interval: 15s
    static_configs:
      - targets: ['10.0.0.11:9363','10.0.0.12:9363','10.0.0.13:9363','10.0.0.14:9363']
```
reload  
curl -X POST http://10.0.0.11:9090/-/reload  

### grafana导入CK监控模板
https://grafana.com/grafana/dashboards/13500  

## 接入spark-3.0

### 暴露spark监控接口

vim /home/servers/spark-3.0.0/conf/metrics.properties

```
*.sink.prometheusServlet.class=org.apache.spark.metrics.sink.PrometheusServlet
*.sink.prometheusServlet.path=/metrics/prometheus
```

### 接入Prometheus

vim /etc/prometheus/prometheus.yml

增加如下配置 

```
 - job_name: 'spark-executors'  
   scrape_interval: 15s  
   metrics_path: '/metrics/executors/prometheus'  
   static_configs:   
     - targets: ['10.0.0.11:4040']
```

reload  
curl -X POST http://10.0.0.11:9090/-/reload  

验证接入成功：curl http://10.0.0.11:4040/metrics/executors/prometheus

### grafana导入CK监控模板

https://grafana.com/grafana/dashboards/7890（模板基于K8S，很多指标采集不到，需调试metrics）

