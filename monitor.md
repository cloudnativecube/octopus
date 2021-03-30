# prometheus部署&监控接入
## prometheus部署
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
wget https://dl.grafana.com/oss/release/grafana-7.4.5-1.x86_64.rpm
yum install -y grafana-7.4.5-1.x86_64.rpm
systemctl start grafana-server
systemctl enable grafana-server

## 接入ClickHouse
