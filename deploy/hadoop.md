# Hadoop 3.1.4 安装与环境简介

##### 环境信息

```
10.0.0.11 centos01  4.4.237-1.el7.elrepo.x86_64 centos7 Cpu: (6*2) Mem: 16GB Disk: 256GB ssd
10.0.0.12 centos02  4.4.237-1.el7.elrepo.x86_64 centos7 Cpu: (6*2) Mem: 16GB Disk: 256GB ssd
10.0.0.13 centos03  4.4.237-1.el7.elrepo.x86_64 centos7 Cpu: (6*2) Mem: 16GB Disk: 256GB ssd
10.0.0.14 centos04  4.4.237-1.el7.elrepo.x86_64 centos7 Cpu: (6*2) Mem: 16GB Disk: 256GB ssd
```

##### 安装JDK8
```
手动下载
https://www.oracle.com/java/technologies/javase/javase-jdk8-downloads.html
自动下载安装
yum install java

配置环境变量
hadoop> vim ~/.bashrc
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.222.b03-1.el7.x86_64
export CLASSPATH=.:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export PATH=$JAVA_HOME/bin:$PATH
```

##### 创建用户

所有机器都创建hadoop用户

```
centos01> sudo adduser hadoop
centos01> passwd 2020root
centos01> sudo usermod -a -G hadoop hadoop 
centos01> sudo vim /etc/sudoers
修改文件如下：
# User privilege specification
root ALL=(ALL) ALL
hadoop ALL=(ALL) ALL //具有sudo权限
```

##### 互信设置

切换到hadoop用户后在centos01执行

```
hadoop> ssh-keygen -t rsa //一直回车就好
hadoop> ssh-copy-id -i  .ssh/id_rsa.pub hadoop@centos02
hadoop> ssh-copy-id -i  .ssh/id_rsa.pub hadoop@centos03
hadoop> ssh-copy-id -i  .ssh/id_rsa.pub hadoop@centos04
```

##### 配置hosts

分发到每个机器的/etc/

```
vim /etc/hosts
10.0.0.11  centos01
10.0.0.12  centos02
10.0.0.13  centos03
10.0.0.14  centos04
```

##### 下载与解压hadoop安装包

分发到每个机器执行

```
hadoop> wget https://www.apache.org/dyn/closer.cgi/hadoop/common/hadoop-3.1.4/hadoop-3.1.4.tar.gz
hadoop> tar xvf hadoop-3.1.4.tar.gz -C /home/servers/
hadoop> vim ~/.bashrc 
追加如下环境变量
export HADOOP_HOME=/home/servers/hadoop-3.1.4
export HADOOP_MAPRED_HOME=${HADOOP_HOME}
export HADOOP_COMMON_HOME=${HADOOP_HOME}
export HADOOP_HDFS_HOME=${HADOOP_HOME}
export HADOOP_YARN_HOME=${HADOOP_HOME}
export HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
hadoop> source ~/.bashrc
```

##### 配置hadoop

创建本地文件夹datanode（datanode节点创建）, namenode（namenode节点创建）,tmp

```
hadoop> mkdir -p /home/servers/hadoop-3.1.4/namenode
hadoop> mkdir -p /home/servers/hadoop-3.1.4/datanode
hadoop> mkdir -p /home/servers/hadoop-3.1.4/tmp
```

进入到/home/servers/hadoop-3.1.4/etc/hadoop目录：

core-site.xml

```
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://centos01/</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/home/servers/hadoop-3.1.4/tmp</value>
    </property>
    <property>
        <name>io.file.buffer.size</name>
        <value>131072</value>
    </property>
</configuration>
```

hdfs-site.xml

```
<configuration>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/home/servers/hadoop-3.1.4/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/home/servers/hadoop-3.1.4/datanode</value>
    </property>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.namenode.rpc-address</name>
        <value>centos01:8020</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>centos01:9870</value>
    </property>
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>centos02:9868</value>
    </property>
    <property>
        <name>dfs.blocksize</name>
        <value>268435456</value>
    </property>
    <property>
        <name>dfs.namenode.handler.count</name>
        <value>100</value>
    </property>
</configuration>
```

mapred-site.xml

```
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_MAPRED_HOME}</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_MAPRED_HOME}</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_MAPRED_HOME}</value>
    </property>
</configuration
```

yarn-site.xml

```
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>centos01</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name> // 此处取消虚拟内存限制检查
        <value>false</value>
    </property>
    <property>
        <name>yarn.log-aggregation-enable</name> // 开启日志聚合，容器日志均采集到hdfs
        <value>true</value>
    </property>
    <property>
        <name>yarn.log.server.url</name>
        <value>http://centos01:19888/jobhistory/logs</value> // 日志聚合服务地址
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,
        HADOOP_COMMON_HOME,
        HADOOP_HDFS_HOME,
        HADOOP_CONF_DIR,
        CLASSPATH_PREPEND_DISTCACHE,
        HADOOP_YARN_HOME,
        HADOOP_HOME,
        PATH,
        LANG,
        TZ,
        HADOOP_MAPRED_HOME
        </value>
    </property>
    <property>
       <name>yarn.resourcemanager.recovery.enabled</name> // 持久化job记录，重启后依然可以看到job
       <value>true</value>
    </property>
    <property>
       <name>yarn.resourcemanager.fs.state-store.uri</name> // job记录存放在hdfs目录
       <value>/rmstore</value>
    </property>
</configuration>
```

workers

```
centos02
centos03
centos04
```

##### 启动hdfs
```
hdfs namenode -format // namenode节点需做格式化
start-dfs.sh
```
##### 启动yarn
```
start-yarn.sh
```
##### 启动jobhistoryserver
```
mr-jobhistory-daemon.sh start historyserver
```

##### WebUI

```
http://centos01:8088 yarn 
http://centos01:9870 namenode
http://centos02:9868 secondary namenode
http://centos01:19888 jobhistory 
```

##### 参考

https://hadoop.apache.org/docs/r3.1.4/

https://a-ghorbani.github.io/2016/12/23/spark-on-yarn-and-java-8-and-virtual-memory-error
