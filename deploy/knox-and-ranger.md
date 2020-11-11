# 一、Knox

用户文档：http://knox.apache.org/books/knox-1-4-0/user-guide.html

下载地址：https://cwiki.apache.org/confluence/display/KNOX/Apache+Knox+Releases#ApacheKnoxReleases-Downloads

选择[knox-1.1.0.zip](https://www.apache.org/dyn/closer.cgi/knox/1.1.0/knox-1.1.0.zip)

## 1. Knox启动

```
# pwd
/home/servers
# unzip knox-1.1.0.zip
# cd knox-1.1.0 //GATEWAY_HOME=/home/servers/knox-1.1.0
# sudo su - hadoop

// 生成master secret，以密文形式持久化到{GATEWAY_HOME}/data/security/master文件中
# bin/knoxcli.sh create-master //这里设置为2020root

// 启动服务
# bin/ldap.sh start
# bin/gateway.sh start //gateway不能用root启动
```



## 2. 反向代理

### 2.1 配置文件

- conf/gateway-site.xml 白名单。修改完之后要重启gateway服务。
- conf/topologies/octopus.xml 网关与后端服务的映射。octopus是我们项目的集群名，每次修改这个文件不用重启knox服务，它是热部署。
- conf/users.ldif 用户名和密码。
- data/services/ 所有被代理组件的rewrite规则。
- data/deployments/ 集群拓扑的部署目录。每次修改conf/topologies/中的文件就会自动重新部署。

### 2.3 认证配置

与用户名密码配置有关的参数：

```
            <param>
                <name>main.ldapRealm.userDnTemplate</name>
                <value>uid={0},ou=people,dc=hadoop,dc=apache,dc=org</value>
            </param>
```

以及文件conf/users.ldif，修改这个文件之后要重启ldap服务。

### 2.3 各服务的gateway地址

通过knox gateway访问hadoop集群中的服务的格式为：

```
https://10.0.0.11:8443/gateway/<topology>/<service>
```

用户名和密码即为knox的users.ldif文件中配置的用户信息。

各服务地址列举如下：

- HDFSUI

  配置：

  ```
      <service>
          <role>HDFSUI</role>
          <url>http://centos01:9870/</url>
          <version>2.7.0</version>
      </service>
  ```

  浏览器打开：https://10.0.0.11:8443/gateway/octopus/hdfs

- WEBHDFS

  配置：

  ```
      <service>
          <role>WEBHDFS</role>
          <url>http://centos01:9870/webhdfs</url>
      </service>
  ```

  访问：

```
# curl -i -k -u guest:guest-password -X GET 'https://10.0.0.11:8443/gateway/octopus/webhdfs/v1/?op=LISTSTATUS'
```

- YARNUI

  配置：

  ```
      <service>
          <role>YARNUI</role>
          <url>http://centos01:8088</url>
      </service>
  ```

  浏览器打开：https://10.0.0.11:8443/gateway/octopus/yarn

- YARN

  配置：

  ```
      <service>
          <role>RESOURCEMANAGER</role>
          <url>http://centos01:8088/ws</url>
      </service>
  ```

  访问示例：

```
# curl -i -k -u admin:admin-password -X GET 'https://10.0.0.11:8443/gateway/octopus/resourcemanager/v1/cluster'
```

- JobHistory

  因为yarn job history起在多个节点上，所以这里可能要配置多个地址。

  ```
      <service>
          <role>JOBHISTORYUI</role>
          <url>http://centos01:19888</url>
      </service>
  ```

- Hive

  以下配置要与hive-site.xml的`hive.server2.thrift.http.port`、`hive.server2.thrift.http.path`参数保持一致：

  ```
      <service>
          <role>HIVE</role>
          <url>http://centos01:10001/cliservice</url>
      </service>
  ```

  如果要验证，需要将hive的`hive.server2.transport.mode`设置为http，它默认是binary。

- Hive WebHCat

  要先启动`$HIVE_HOME/hcatalog/sbin/webhcat_server.sh`。

  配置：

```
    <service>
        <role>WEBHCAT</role>
        <url>http://centos01:50111/templeton</url>
    </service>
```

访问示例：

```
# curl -i -k -u admin:admin-password 'https://10.0.0.11:8443/gateway/octopus/templeton/v1/status'
```

- Spark History Server

```
    <service>
        <role>SPARKHISTORYUI</role>
        <url>http://centos01:18080/</url>
    </service>
```

浏览器打开：https://10.0.0.11:8443/gateway/octopus/sparkhistory

- HBASEUI

  配置：

  ```
      <service>
          <role>HBASEUI</role>
          <url>http://centos01:16010</url>
      </service>
  ```

  浏览器打开：https://10.0.0.11:8443/gateway/octopus/hbase/webui (我没验证成功)

# 二、Ranger

### 1. 文档

- Quick Start Guide：http://ranger.apache.org/quick_start_guide.html

- 安装文档：

  - https://cwiki.apache.org/confluence/display/RANGER/Apache+Ranger+0.5.0+Installation

  - https://cwiki.apache.org/confluence/display/RANGER/Ranger+Installation+Guide

- Ranger User Guide：https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=57901344#RangerUserGuide(workinprogress)-KnoxRepositoryconfiguration

- 参考：https://juejin.im/post/6844904159930482696

### 2. 安装包

下载：http://ranger.apache.org/download.html 选择[apache-ranger-2.0.0.tar.gz](https://www.apache.org/dyn/closer.lua/ranger/2.0.0/apache-ranger-2.0.0.tar.gz)

编译：

```
# mvn -DskipTests=true clean package install assembly:assembly
```

在target目录中生成压缩包：

```
ranger-2.0.0-admin.tar.gz
ranger-2.0.0-atlas-plugin.tar.gz
ranger-2.0.0-elasticsearch-plugin.tar.gz
ranger-2.0.0-hbase-plugin.tar.gz
ranger-2.0.0-hdfs-plugin.tar.gz
ranger-2.0.0-hive-plugin.tar.gz
ranger-2.0.0-kafka-plugin.tar.gz
ranger-2.0.0-kms.tar.gz
ranger-2.0.0-knox-plugin.tar.gz
ranger-2.0.0-kylin-plugin.tar.gz
ranger-2.0.0-migration-util.tar.gz
ranger-2.0.0-ozone-plugin.tar.gz
ranger-2.0.0-presto-plugin.tar.gz
ranger-2.0.0-ranger-tools.tar.gz
ranger-2.0.0-solr-plugin.tar.gz
ranger-2.0.0-solr_audit_conf.tar.gz
ranger-2.0.0-sqoop-plugin.tar.gz
ranger-2.0.0-src.tar.gz
ranger-2.0.0-storm-plugin.tar.gz
ranger-2.0.0-tagsync.tar.gz
ranger-2.0.0-usersync.tar.gz
ranger-2.0.0-yarn-plugin.tar.gz
```

每个组件在安装时，都要先配置各自的install.properties。

### 3. admin组件

#### 3.1 概述

依赖组件：

- mysql：用于存储acl策略
- solr：用于存储审计日志
- zookeeper：solr集群依赖zookeeper

部署目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-admin
```

日志目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-admin/ews/logs/
```

#### 3.2 install.properties配置

```
SQL_CONNECTOR_JAR=/usr/share/java/mysql-connector-java-5.1.49.jar
audit_solr_urls=http://centos01:8983/solr/ranger_audits
hadoop_conf=/home/servers/hadoop-3.1.4/etc/hadoop

// 访问mysql时的用户信息
db_root_user=root
db_root_password=
db_host=localhost
// 使用以上用户创建如下的db和user
db_name=ranger
db_user=rangeradmin
db_password=2020root
// 登录web UI的用户名和密码：admin/2020root
rangerAdmin_password=2020root
rangerTagsync_password=2020root
rangerUsersync_password=2020root
keyadmin_password=2020root
// 审计日志
audit_store=solr
audit_solr_urls=http://centos01:8983/solr/ranger_audits  // plugin的配置要用到该参数
audit_solr_user=
audit_solr_password=
audit_solr_zookeepers=centos01:2181,centos02:2181,centos03:2181/ranger_audits
audit_solr_collection_name=ranger_audits
audit_solr_config_name=ranger_audits
audit_solr_no_shards=3
audit_solr_no_replica=2
audit_solr_max_shards_per_node=1
audit_solr_acl_user_list_sasl=solr,infra-solr
```

#### 3.3 mysql

install.properties中需要配置`SQL_CONNECTOR_JAR=/usr/share/java/mysql-connector-java-5.1.49.jar`

将mysql-connector-java包放到/usr/share/java/。下载地址：https://dev.mysql.com/downloads/connector/j/5.1.html。

#### 3.4 solr

参考：

- https://lucene.apache.org/solr/guide/8_6/

- https://www.cnblogs.com/hit-zb/p/11691375.html

- 下载页面：https://lucene.apache.org/solr/downloads.html

步骤**（可以部署多个节点组成solr集群）**：

```
# pwd
/home/servers/solr-8.6.3

// 在zookeeper上创建审计日志的根目录，只需要执行一次
# server/scripts/cloud-scripts/zkcli.sh -zkhost centos01:2181,centos02:2181,centos03:2181 -cmd makepath /ranger_audits

// 配置zookeeper地址
# vim bin/solr.in.sh
ZK_HOST="centos01:2181,centos02:2181,centos03:2181/ranger_audits"

// 启动solr
# bin/solr start -force -cloud  // root用户要使用-force参数
// 省略中间输出
Started Solr server on port 8983 (pid=12474). Happy searching

// 创建collection，只需要执行一次
# bin/solr create_collection -force -c ranger_audits -d /home/servers/ranger-2.0.0/ranger-2.0.0-admin/contrib/solr_for_audit_setup/conf/ -shards 3 -replicationFactor 2  // -c是集合名，-d是ranger_admin的solr conf目录
```

solr默认监听8983端口。web UI：http://10.0.0.11:8983/solr/#/

solr接收日志时，同步到各节点有些延迟，当在ranger-admin上查看日志时要等一会。

其他命令：

```
# bin/solr stop -all
# bin/solr delete -c ranger_audits // 删除collection
```

#### 3.5 安装和启动admin服务

用root执行：

```
# ./setup.sh
// 省略中间输出
Installation of Ranger PolicyManager Web Application is completed.
# ranger-admin start
```

admin web UI：http://10.0.0.11:6080

停止命令：

```
# ranger-admin stop
```

### 4. user-sync组件

目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-usersync
```

配置：

```
POLICY_MGR_URL=http://centos01:6080
hadoop_conf=/home/servers/hadoop-3.1.4/etc/hadoop
rangerUsersync_password=2020root // 要与admin的配置一致
```

用root执行：

```
# ./setup.sh
# ranger-usersync start  // 或./ranger-usersync-services.sh start
```

### 5. HDFS plugin

目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-hdfs-plugin
```

配置：

```
POLICY_MGR_URL=http://centos01:6080
REPOSITORY_NAME=hadoopdev
COMPONENT_INSTALL_DIR_NAME=/home/servers/hadoop-3.1.4  // hadoop的HOME目录
CUSTOM_USER=hadoop
CUSTOM_GROUP=hadoop

// 审计日志
XAAUDIT.SOLR.ENABLE=true
XAAUDIT.SOLR.URL=NONE
XAAUDIT.SOLR.USER=NONE
XAAUDIT.SOLR.PASSWORD=NONE
XAAUDIT.SOLR.ZOOKEEPER=centos01:2181,centos02:2181,centos03:2181/ranger_audits
XAAUDIT.SOLR.FILE_SPOOL_DIR=/var/log/hadoop/hdfs/audit/solr/spool
XAAUDIT.SOLR.IS_ENABLED=false
XAAUDIT.SOLR.MAX_QUEUE_SIZE=1
XAAUDIT.SOLR.MAX_FLUSH_INTERVAL_MS=1000
XAAUDIT.SOLR.SOLR_URL=http://centos01:8983/solr/ranger_audits
```

用root执行：

```
# ./enable-hdfs-plugin.sh
// 省略中间输出
Ranger Plugin for hadoop has been enabled. Please restart hadoop to ensure that changes are effective.
```

拷贝jar包：

```
cp lib/*.jar /home/servers/hadoop-3.1.4/share/hadoop/hdfs/
```

重启hdfs（切换到hadoop用户）：

```
# pwd
/home/servers/hadoop-3.1.4
# sbin/stop-dfs.sh
# sbin/start-dfs.sh
```

打开admin web UI，进入AccessManager => ServiceManager => 选择HDFS点击"+" Create Service，配置相关信息

```
Service Name = hadoopdev
Username = hadoop
Password = 2020root
Namenode URL = hdfs://10.0.0.11:8020
```

测试连接，保存。

在ranger-admin上查看plugins状态是否是200。

### 6. YARN plugin

目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-yarn-plugin
```

配置：

```
POLICY_MGR_URL=http://centos01:6080
REPOSITORY_NAME=yarndev
COMPONENT_INSTALL_DIR_NAME=/home/servers/hadoop-3.1.4  // hadoop的HOME目录
CUSTOM_USER=hadoop
CUSTOM_GROUP=hadoop

// 审计日志
XAAUDIT.SOLR.ENABLE=true
XAAUDIT.SOLR.URL=NONE
XAAUDIT.SOLR.USER=NONE
XAAUDIT.SOLR.PASSWORD=NONE
XAAUDIT.SOLR.ZOOKEEPER=centos01:2181,centos02:2181,centos03:2181/ranger_audits
XAAUDIT.SOLR.FILE_SPOOL_DIR=/var/log/hadoop/yarn/audit/solr/spool
XAAUDIT.SOLR.IS_ENABLED=false
XAAUDIT.SOLR.MAX_QUEUE_SIZE=1
XAAUDIT.SOLR.MAX_FLUSH_INTERVAL_MS=1000
XAAUDIT.SOLR.SOLR_URL=http://centos01:8983/solr/ranger_audits
```

执行：

```
# ./enable-yarn-plugin.sh
// 省略中间输出
Ranger Plugin for yarn has been enabled. Please restart yarn to ensure that changes are effective.
```

拷贝jar包：

```
# cp lib/*.jar  /home/servers/hadoop-3.1.4/share/hadoop/yarn/
```

重启yarn：

```
# pwd
/home/servers/hadoop-3.1.4
# sbin/stop-yarn.sh
# sbin/start-yarn.sh
```

在ranger-admin上创建Service：

```
YARN REST URL = http://10.0.0.11:8088
```

### 7. Hive plugin

目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-hive-plugin
```

配置：

```
POLICY_MGR_URL=http://centos01:6080
REPOSITORY_NAME=hivedev
COMPONENT_INSTALL_DIR_NAME=/home/servers/hive-3.1.2
CUSTOM_USER=hadoop
CUSTOM_GROUP=hadoop

// 审计日志
XAAUDIT.SOLR.ENABLE=true
XAAUDIT.SOLR.URL=NONE
XAAUDIT.SOLR.USER=NONE
XAAUDIT.SOLR.PASSWORD=NONE
XAAUDIT.SOLR.ZOOKEEPER=centos01:2181,centos02:2181,centos03:2181/ranger_audits
XAAUDIT.SOLR.FILE_SPOOL_DIR=/var/log/hive/audit/solr/spool
XAAUDIT.SOLR.IS_ENABLED=false
XAAUDIT.SOLR.MAX_QUEUE_SIZE=1
XAAUDIT.SOLR.MAX_FLUSH_INTERVAL_MS=1000
XAAUDIT.SOLR.SOLR_URL=http://centos01:8983/solr/ranger_audits
```

执行：

```
# ./enable-hive-plugin.sh
// 省略中间输出
Ranger Plugin for hive has been enabled. Please restart hive to ensure that changes are effective.
```

重启hiveserver2：

```
# pwd
/home/servers/hive-3.1.2
# ps -ef | grep hiveserver2 // 先kill掉hiveserver2
# nohup hive --service hiveserver2 2>&1 > hiveserver2.log &
```

在ranger-admin上创建Hive Service：

```
Service Name = hivedev  // 与REPOSITORY_NAME配置一致
Username = hadoop
Password = 2020root
jdbc.driverClassName = org.apache.hive.jdbc.HiveDriver
jdbc.url = jdbc:hive2://centos01:10000
```

在ranger-admin上查看Plugins状态是否是200。

使用beelin执行hive sql语句：

```
# bin/beeline -n hadoop -u jdbc:hive2://localhost:10000
// 执行select查询
```

然后在ranger-admin上能看到审计日志。

### 8. HBase plugin

**注意：hbase plugin需要部署在所有hbase master节点上。**

目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-hbase-plugin
```

配置：

```
POLICY_MGR_URL=http://centos01:6080
REPOSITORY_NAME=hivedev
COMPONENT_INSTALL_DIR_NAME=/home/servers/hbase-2.2.6
CUSTOM_USER=hadoop
CUSTOM_GROUP=hadoop

// 审计日志
XAAUDIT.SOLR.ENABLE=true
XAAUDIT.SOLR.URL=NONE
XAAUDIT.SOLR.USER=NONE
XAAUDIT.SOLR.PASSWORD=NONE
XAAUDIT.SOLR.ZOOKEEPER=centos01:2181,centos02:2181,centos03:2181/ranger_audits
XAAUDIT.SOLR.FILE_SPOOL_DIR=/var/log/hbase/audit/solr/spool
XAAUDIT.SOLR.IS_ENABLED=false
XAAUDIT.SOLR.MAX_QUEUE_SIZE=1
XAAUDIT.SOLR.MAX_FLUSH_INTERVAL_MS=1000
XAAUDIT.SOLR.SOLR_URL=http://centos01:8983/solr/ranger_audits
```

执行：

```
# ./enable-hbase-plugin.sh
// 省略中间输出
Ranger Plugin for hbase has been enabled. Please restart hbase to ensure that changes are effective.
```

拷贝jar包：

```
# cp /home/servers/ranger-2.0.0/ranger-2.0.0-admin/ews/webapp/WEB-INF/lib/jersey-bundle-1.19.3.jar /home/servers/hbase-2.2.6/lib/
```

创建spool目录：

```
# mkdir -p /var/log/hbase/audit/solr/spool
# chown -R hadoop:hadoop /var/log/hbase/audit/solr/spool
```

重启hbase：

```
# pwd
/home/servers/hbase-2.6.6
# bin/stop-hbase.sh
# bin/start-hbase.sh
```

在ranger-admin上创建HBase Service：

```
Service Name = hbasedev  // 与REPOSITORY_NAME配置一致
Username = hadoop
Password = 2020root
hadoop.security.authentication = Simple
hbase.security.authentication= Simple
hbase.zookeeper.property.clientPort = 2181
hbase.zookeeper.quorum = centos01,centos02,centos03
zookeeper.znode.parent = /hbase
```

在ranger-admin上查看Plugins状态是否是200。

### 9. Elasticsearch Plugin

参考资料：

- https://cwiki.apache.org/confluence/display/RANGER/Elasticsearch+Plugin
- https://segmentfault.com/a/1190000023643744

**注意：elasticsearch plugin需要部署在所有elasticsearch的master和data节点上。**

目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-elasticsearch-plugin
```

配置：

```
POLICY_MGR_URL=http://centos01:6080
REPOSITORY_NAME=elasticsearchdev
COMPONENT_INSTALL_DIR_NAME=/home/servers/elasticsearch-6.2.2
CUSTOM_USER=hadoop
CUSTOM_GROUP=hadoop

// 审计日志
XAAUDIT.SOLR.ENABLE=true
XAAUDIT.SOLR.URL=NONE
XAAUDIT.SOLR.USER=NONE
XAAUDIT.SOLR.PASSWORD=NONE
XAAUDIT.SOLR.ZOOKEEPER=centos01:2181,centos02:2181,centos03:2181/ranger_audits
XAAUDIT.SOLR.FILE_SPOOL_DIR=/var/log/elasticsearch/audit/solr/spool
XAAUDIT.SOLR.IS_ENABLED=false
XAAUDIT.SOLR.MAX_QUEUE_SIZE=1
XAAUDIT.SOLR.MAX_FLUSH_INTERVAL_MS=1000
XAAUDIT.SOLR.SOLR_URL=http://centos01:8983/solr/ranger_audits
```

创建spool目录：

```
# mkdir -p /var/log/elasticsearch/audit/solr/spool
# chown -R hadoop:hadoop /var/log/elasticsearch/audit/solr/spool
```

从hdfs plugin目录把jar包拷过来，同时拷贝到两个目录（不知道为什么缺少jar包）：

```
# cp /home/servers/ranger-2.0.0/ranger-2.0.0-hdfs-plugin/install/lib/{woodstox-core-5.0.3.jar,stax2-api-3.1.4.jar,commons-configuration2-2.1.1.jar,htrace-core4-4.1.0-incubating.jar} ./install/lib/
# cp /home/servers/ranger-2.0.0/ranger-2.0.0-hdfs-plugin/install/lib/{woodstox-core-5.0.3.jar,stax2-api-3.1.4.jar,commons-configuration2-2.1.1.jar,htrace-core4-4.1.0-incubating.jar} ./lib/ranger-elasticsearch-plugin/
# cp /home/servers/ranger-2.0.0/ranger-2.0.0-admin/ews/lib/zookeeper-3.4.14.jar ./lib/ranger-elasticsearch-plugin/ranger-elasticsearch-plugin-impl/
```

安装插件：

```
# ./enable-elasticsearch-plugin.sh
// 省略中间输出
Ranger Plugin for elasticsearch has been enabled. Please restart elasticsearch to ensure that changes are effective.
```

在es的目录下产生plugin的文件：

```
/home/servers/elasticsearch-6.2.2/config/ranger-elasticsearch-plugin/ranger-elasticsearch-audit.xml
/home/servers/elasticsearch-6.2.2/config/ranger-elasticsearch-plugin/ranger-elasticsearch-security.xml
/home/servers/elasticsearch-6.2.2/plugins/ranger-elasticsearch-plugin/
```

在ranger-admin上创建Elasticsearch Service（需要先在es上有存在的index才能测试连接成功）：

```
Service Name = elasticsearchdev  // 与REPOSITORY_NAME配置一致
Username = hadoop
Elasticsearch URL: http://centos01:9200
```

修改文件lib/ranger-elasticsearch-plugin/plugin-security.policy（有些权限需要添加，否则es启不来）：

```
grant {
  permission java.lang.RuntimePermission "createClassLoader";
  permission java.lang.RuntimePermission "getClassLoader";
  permission java.lang.RuntimePermission "setContextClassLoader";
  permission java.lang.RuntimePermission "shutdownHooks";
  permission java.lang.RuntimePermission "accessDeclaredMembers";
  permission java.lang.RuntimePermission "accessClassInPackage.sun.misc";
  permission java.lang.RuntimePermission "loadLibrary.*";
  permission java.lang.reflect.ReflectPermission "suppressAccessChecks";
  permission java.lang.reflect.ReflectPermission "newProxyInPackage.com.kstruct.gethostname4j";
  permission javax.security.auth.AuthPermission "getLoginConfiguration";
  permission javax.security.auth.AuthPermission "setLoginConfiguration";

  permission java.net.NetPermission "getProxySelector";
  // adapt to connect different IP and Port
  permission java.net.SocketPermission "*", "connect,resolve";

  permission java.util.PropertyPermission "*", "read,write";
  // adapt to different directories configured by user
  permission java.io.FilePermission "<<ALL FILES>>", "read,write,delete";
};
```

在文件/home/servers/elasticsearch-6.2.2/config/jvm.options中配置elasticsearch的jvm参数：

```
-Djava.security.policy=/home/servers/elasticsearch-6.2.2/plugins/ranger-elasticsearch-plugin/plugin-security.policy
```

重启es。**注意：在启动之前，要检查/home/servers/elasticsearch-6.2.2/plugins/有没有`.ranger-elasticsearch-plugin`开头的隐藏目录，有的话就删除，否则es会报错。**

发请求验证：

```
# curl -u hadoop:hadoop http://centos01:9200/_cluster/health?pretty
```

`-u`参数指定用户名和密码，用户名必须是ranger的policy里配置的user，密码随便写。

未解决问题：

- es日志中报`java.lang.SecurityException`，不知道什么原因，但不影响审计日志和权限控制。
- kibana中配置的es用户名和密码是`hadoop`，可以在ranger中看到kibana访问es的审计日志，而且是放行的，但是kibana界面上还是无法显示结果。
- 如果想使用其他用户名，需要在centos01上创建新用户，例如创建用户kibana，然后ranger-usersync会同步到ranger-admin上，将用户kibana配置到ranger policy里，这样就可以使用kibana用户访问es了，譬如把它给kibana服务使用。但是密码可以随便写。

### 10. Knox plugin

目录：

```
/home/servers/ranger-2.0.0/ranger-2.0.0-knox-plugin
```

配置：

```
POLICY_MGR_URL=http://centos01:6080
REPOSITORY_NAME=knoxdev
KNOX_HOME=/home/servers/knox-1.1.0
CUSTOM_USER=hadoop
CUSTOM_GROUP=hadoop

// 审计日志
XAAUDIT.SOLR.ENABLE=true
XAAUDIT.SOLR.URL=NONE
XAAUDIT.SOLR.USER=NONE
XAAUDIT.SOLR.PASSWORD=NONE
XAAUDIT.SOLR.ZOOKEEPER=centos01:2181,centos02:2181,centos03:2181/ranger_audits
XAAUDIT.SOLR.FILE_SPOOL_DIR=/var/log/knox/audit/solr/spool
XAAUDIT.SOLR.IS_ENABLED=false
XAAUDIT.SOLR.MAX_QUEUE_SIZE=1
XAAUDIT.SOLR.MAX_FLUSH_INTERVAL_MS=1000
XAAUDIT.SOLR.SOLR_URL=http://centos01:8983/solr/ranger_audits
```

用root执行：

```
# ./enable-knox-plugin.sh
// 省略中间输出
Ranger Plugin for knox has been enabled. Please restart knox to ensure that changes are effective.
```

用hadoop用户重启knox：

```
# pwd
/home/servers/knox-1.1.0
# bin/ldap.sh stop
# bin/ldap.sh start
# bin/gateway.sh stop
# bin/gateway.sh start
```

#### 将knox的自签名证书导入ranger-admin

生成crt文件：

```
# pwd
/home/servers/knox-1.1.0/data/security/keystores
# keytool -exportcert -alias gateway-identity -keystore gateway.jks -file knox.crt
// 输入密码2020root
```

导入ranger-admin：

```
# pwd
/home/servers/ranger-2.0.0/ranger-2.0.0-admin
# cp /home/servers/knox-1.1.0/data/security/keystores/knox.crt /home/servers/ranger-2.0.0/ranger-2.0.0-admin
# cp $JAVA_HOME/jre/lib/security/cacerts cacertswithknox
# keytool -import -trustcacerts -file knox.crt -alias knox -keystore cacertswithknox
输入密钥库口令: changeit
所有者: CN=localhost, OU=Test, O=Hadoop, L=Test, ST=Test, C=US
发布者: CN=localhost, OU=Test, O=Hadoop, L=Test, ST=Test, C=US
序列号: 592d7d757bb31e07
有效期为 Sat Oct 10 14:28:21 CST 2020 至 Sun Oct 10 14:28:21 CST 2021
证书指纹:
	 MD5:  8A:62:09:8C:59:BF:26:03:38:C2:2A:E7:54:DF:58:7A
	 SHA1: 3B:D0:B4:8E:C6:68:2B:9D:76:86:4E:0E:D5:7F:0B:49:C4:85:7F:AC
	 SHA256: EC:AE:E4:38:EE:00:DC:86:45:DB:40:96:DA:CF:16:AF:C7:67:0B:1E:A1:EF:49:2D:59:59:9E:72:E9:32:0A:6D
签名算法名称: SHA1withRSA
主体公共密钥算法: 1024 位 RSA 密钥
版本: 3
是否信任此证书? [否]:  是
证书已添加到密钥库中
```

修改ews/ranger-admin-services.sh：

```
-Djavax.net.ssl.trustStore=/home/servers/ranger-2.0.0/ranger-2.0.0-admin/cacertswithknox
```

注意，改install.properties以下这个配置不管用！因为java默认使用系统的证书`/etc/pki/java/cacerts`。

```
javax_net_ssl_trustStore=/home/servers/ranger-2.0.0/ranger-2.0.0-admin/cacertswithknox
javax_net_ssl_trustStorePassword=changeit
```

重启ranger-admin：

```
# ./setup.sh
# ranger-admin restart
```

#### 调试命令

```
// 查看keystore文件内容
# keytool -list -v -keystore cacertswithknox -storepass changeit
// 查看crt文件内容
# keytool -printcert -file knox.crt
```

证书中有一行是：

```
所有者: CN=localhost, OU=Test, O=Hadoop, L=Test, ST=Test, C=US
```

在ranger-admin上创建knox Service时，knox.url要使用证书中CN里的地址localhost：

```
knox.url = https://localhost:8443/gateway/admin/api/v1/topologies
```

#### 在ranger-admin上创建Knox Service

```
Service Name = knoxdev  // 与REPOSITORY_NAME配置一致
Username = admin
Password = admin-password
knox.url = https://localhost:8443/gateway/admin/api/v1/topologies
```

在ranger-admin上查看Plugins状态是否是200。

# 三、Ranger授权

### 1. 参考

- https://blog.cloudera.com/best-practices-in-hdfs-authorization-with-apache-ranger/
- https://docs.cloudera.com/cdp-private-cloud-base/7.1.4/security-ranger-authorization/topics/security-ranger-provide-authorization-cdp.html

### 2. HDFS native权限

HDFS本身并没有提供用户名、组等的创建和管理，在客户端操作Hadoop时，Hadoop自动识别执行命令所在的进程的用户名和用户组，然后检查是否具有权限。启动Hadoop的用户即为超级用户，可以进行所有操作。

在linux机器上上创建两个用户：

```
# useradd madianjun -g hadoop
# useradd machao -g hadoop
```

给这两个用户创建hdfs目录，并设置权限禁止其他用户访问：

```
# hdfs dfs -mkdir /user/madianjun
# hdfs dfs -mkdir /user/machao
# hdfs dfs -chmod 700 /user/madianjun
# hdfs dfs -chmod 700 /user/machao
# hdfs dfs -ls /user
Found 2 items
drwx------   - machao    hadoop              0 2020-10-15 16:45 /user/machao
drwx------   - madianjun hadoop              0 2020-10-15 11:37 /user/madianjun
```

用madianjun访问/user/machao目录，没有权限：

```
# hdfs dfs -ls /user/machao
ls: Permission denied: user=madianjun, access=READ_EXECUTE, inode="/user/machao":hadoop:supergroup:drwx------
```

### 3. 配置ranger授权策略

首先确认madianjun, machao两个用户已经同步到ranger-admin里。如果没有同步，可能需要重启ranger-usersync。

新建一个策略，允许madianjun访问/user/machao目录：

```
Resource Path = /user/machao
Select User = madianjun
Permissions = Read Write Execute
```

用madianjun访问/user/machao目录，有权限：

```
# hdfs dfs -ls /user/machao
Found 2 items
drwxr-xr-x   - hadoop hadoop          0 2020-10-15 16:45 /user/machao/aa
drwxr-xr-x   - hadoop hadoop          0 2020-10-15 16:45 /user/machao/bb
```

