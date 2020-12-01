# Hive-3.1.2 安装与环境简介

##### 下载与解压hive安装包

```
hadoop> wget https://apache.mirror.colo-serv.net/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz
hadoop> tar xvf apache-hive-3.1.2-bin.tar.gz -C /home/servers/
hadoop> mv /home/servers/apache-hive-3.1.2 /home/servers/hive-3.1.2
hadoop> vim ~/.bashrc 
追加如下环境变量
export HIVE_HOME=/home/servers/hive-3.1.2
export PATH=$PATH:$HIVE_HOME/bin
hadoop> source ~/.bashrc
```
##### 配置
创建hdfs目录
```
hadoop> hadoop fs -mkdir       /tmp
hadoop> hadoop fs -mkdir -p    /user/hive/warehouse
hadoop> hadoop fs -chmod g+w   /tmp
hadoop> hadoop fs -chmod g+w   /user/hive/warehouse
```
修改/home/servers/hive-3.1.2/conf/hive-site.xml
```
<configuration>
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>/user/hive/warehouse</value>
    </property>
    <property>
        <name>hive.metastore.uris</name> // hiveserver2连接metastore service，remote部署方式
        <value>thrift://centos01:9083</value> 
    </property>
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:mysql://localhost:3306/hive?autoReconnect=true&amp;autoReconnectForPools=true</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>com.mysql.jdbc.Driver</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>hive</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>2020root</value>
    </property>
    <property>
        <name>hive.server2.thrift.port</name>
        <value>10000</value>
    </property>
    <property>
        <name>hive.server2.thrift.http.port</name>
        <value>10001</value>
    </property>
    <property>
        <name>hive.server2.webui.host</name>
        <value>centos01</value>
    </property>
    <property>
        <name>hive.server2.webui.port</name>
        <value>10002</value>
    </property>
</configuration>
```
修改hadoop core-site.xml
```
<property>
    <name>hadoop.proxyuser.hadoop.hosts</name> // 允许java客户端以hadoop用户连接hadoop集群
    <value>*</value>
</property>
<property>
    <name>hadoop.proxyuser.hadoop.groups</name>
    <value>*</value>
</property>

```

下载mysql驱动到/home/servers/hive-3.1.2/lib/目录下

```
hadoop> wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.49.zip
hadoop> unzip mysql-connector-java-5.1.49.zip
hadoop> mv mysql-connector-java-5.1.49.jar /home/servers/hive-3.1.2/lib/
```

安装mysql, 创建hive数据库实例，以及hive数据库用户，密码为2020root, 初始化mysql数据库。

mysql操作：

```
create user 'hive'@'localhost' identified by '2020root';
grant all privileges on hive.* to 'hive'@'localhost'; 
flush privileges;
```

初始化hive metastore：

```
schematool -initSchema -dbType mysql
```

##### 启动Hive
```
hadoop> cd /home/servers/hive-3.1.2
hadoop> nohup hive --service metastore 2>&1 > metastore.log &    // 需先于hiveserver2启动
hadoop> nohup hive --service hiveserver2 2>&1 > hiveserver2.log &

```

##### 测试Hive
```
beeline -n hadoop  -u jdbc:hive2://localhost:10000
0: jdbc:hive2://localhost:10000> show databases;
0: jdbc:hive2://localhost:10000> create table itstar(id int,name string);
0: jdbc:hive2://localhost:10000> show tables;
0: jdbc:hive2://localhost:10000> insert into table itstar values(1,"zhangsan");
0: jdbc:hive2://localhost:10000> insert into table itstar values(2,"lisi");
0: jdbc:hive2://localhost:10000> select * from itstar;

```

##### WebUI
```
http://centos01:10002/
```

##### 参考

```
https://cwiki.apache.org/confluence/display/Hive/GettingStarted
https://cwiki.apache.org/confluence/display/Hive/Configuration+Properties

```

