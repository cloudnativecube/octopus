# Phoenix 安装文档

##### 下载phoenix安装包

```
hadoop> wget http://www.apache.org/dyn/closer.lua/phoenix/apache-phoenix-5.0.0-HBase-2.0/bin/apache-phoenix-5.0.0-HBase-2.0-bin.tar.gz
hadoop> tar -xvf apache-phoenix-5.0.0-HBase-2.0-bin.tar.gz
hadoop> mv apache-phoenix-5.0.0-HBase-2.0-bin /home/servers/phoenix-5.0.0
hadoop> vim ~/.bashrc
export PHOENIX_HOME=/home/servers/phoenix-5.0.0
export CLASSPATH=$CLASSPATH:$PHOENIX_HOME
export PATH=$PATH:$PHOENIX_HOME/bin
hadoop> source ~/.bashrc
```

##### 分发phoenix jar包

```
hadoop> scp /home/servers/phoenix-5.0.0/phoenix-5.0.0-HBase-2.0-server.jar hadoop@centos02:/home/servers/hbase-2.2.6/lib/
hadoop> scp /home/servers/phoenix-5.0.0/phoenix-5.0.0-HBase-2.0-server.jar hadoop@centos03:/home/servers/hbase-2.2.6/lib/
hadoop> scp /home/servers/phoenix-5.0.0/phoenix-5.0.0-HBase-2.0-server.jar hadoop@centos04:/home/servers/hbase-2.2.6/lib/
```

##### **注意：这里还需要下载htrace-core-3.1.0-incubating.jar，然后分发到hbase的lib目录下。

##### 重启hbase

```
stop-hbase.sh
start-hbase.sh
```

##### 测试phoenix基本功能

```
sqlline.py localhost /home/servers/phoenix-5.0.0/examples/STOCK_SYMBOL.sql
```
