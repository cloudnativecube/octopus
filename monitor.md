# prometheus部署
### 下载安装包
wget https://github.com/prometheus/prometheus/releases/download/v2.15.2/prometheus-2.15.2.linux-amd64.tar.gz
### 创建用户和目录并赋权
useradd --no-create-home --shell /bin/false prometheus  
mkdir /etc/prometheus  
mkdir /var/lib/prometheus  
chown prometheus:prometheus /etc/prometheus  
chown prometheus:prometheus /var/lib/prometheus  
### 安装
tar -xvzf prometheus-2.15.2.linux-amd64.tar.gz  
mv prometheus-2.15.2.linux-amd64 prometheuspackage  
cp prometheuspackage/prometheus /usr/local/bin/
cp prometheuspackage/promtool /usr/local/bin/  
chown prometheus:prometheus /usr/local/bin/prometheus  
chown prometheus:prometheus /usr/local/bin/promtool  
cp -r prometheuspackage/consoles /etc/prometheus  
cp -r prometheuspackage/console_libraries /etc/prometheus  
chown -R prometheus:prometheus /etc/prometheus/consoles  
chown -R prometheus:prometheus /etc/prometheus/console_libraries  
### 配置
vim /etc/prometheus/prometheus.yml
```
global:
  scrape_interval: 10s
 
scrape_configs:
  - job_name: 'prometheus_master'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
```
