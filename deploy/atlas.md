# Apache-Atlas编译安装及整合Hive、HBase

参考链接：http://atlas.apache.org

(编译与安装参考)

https://blog.csdn.net/xiangwang2206/article/details/111503412

https://blog.csdn.net/xiangwang2206/article/details/112001194?utm_medium=distribute.pc_relevant.none-task-blog-OPENSEARCH-1.control&depth_1-utm_source=distribute.pc_relevant.none-task-blog-OPENSEARCH-1.control

(整合各个组件参考)

https://www.cnblogs.com/shenyuelan/p/14085496.html

(理解atlas工作原理的大概)

https://blog.csdn.net/tomalun/article/details/105100307

## 一、环境准备

注：如果要独立部署atlas和其他组件的话，以下是环境必备组件，否则选择部署带有内嵌组件的atlas的话，只要jdk1.8x及以上就行。

### 1. 组件版本
|组件|版本|
|:--|:--|
|os|Linux 3.10.0-1127.el7.x86_64|
|java|1.8.0_261|
|zookeeper|3.6.2|
|kafka|2.13-2.7.0(版本偏高)|
|hadoop|2.6.0(版本偏低)|
|hbase|2.2.6|
|solr|8.6.3|
|hive|2.0.1(版本偏低)|
|atlas|2.1.0|

### 2.角色分配
|组件|30.23.5.180(master)|30.23.4.69(slave-01)|30.23.5.206(slave-02)|30.23.4.117(slave-03)|30.23.5.142(slave-04)|30.23.4.95(slave-05)|30.23.4.187(slave-06)|
|:--|:--|:--|:--|:--|:--|:--|:--|
|zookeeper|&radic;-Leader|&radic;-Follower|&radic;-Follower|--|--|--|--|
|kafka|&radic;-9092|&radic;|&radic;|--|--|--|--|
|NameNode|&radic;-50070|--|--|--|--|--|--|
|SecondaryNameNode|&radic;-50090|--|--|--|--|--|--|
|MR JobHistory Server|&radic;|&radic;|&radic;|&radic;|&radic;|&radic;|&radic;|
|DataNode|--|&radic;|&radic;|&radic;|&radic;|&radic;|&radic;|
|ResourceManager|&radic;|--|--|--|--|--|--|
|NodeManager|--|&radic;|&radic;|&radic;|&radic;|&radic;|&radic;|
|hbase|&radic;-HMaster|--|--|--|&radic;-HMaster,HRegionServer|&radic;-HRegionServer|&radic;-HRegionServer|
|solr|&radic;|&radic;|&radic;|--|--|--|--|
|hive|&radic;|--|--|--|--|--|--|
|MySQL|&radic;|--|--|--|--|--|--|
|atlas|&radic;|--|--|--|--|--|--|

## 二、编译
由于Atlas需要不同组件配置好了才能正常启动，各组件版本不同，所需要的安装包不同，所以官网上没有提供编译好的二进制包，只有源码包😭，开始编译前，检查环境的maven，jdk版本要分别在Maven3.X，jdk1.8x及以上，系统最好默认python2.7以便之后启动atlas的python脚本。

前往官网，下载atlas 2.1.0版本：https://atlas.apache.org/#/Downloads

### 1. 修改部分配置文件

编译下载前修改maven镜像，亲测阿里的镜像最好用，修改apache-maven-3.6.x/conf/settings.xml中<mirros>部分如下:

```
<mirror>
    <id>alimaven</id>
    <name>aliyun maven</name>
    <url>http://maven.aliyun.com/nexus/content/groups/public/</url>
    <mirrorOf>central</mirrorOf>
</mirror>
```
把修改好的settings.xml拷贝到~/.m2/

```
cp .../apache-maven-3.6x/conf/settings.xml ~/.m2/
```

之后回到atlas压缩包所在目录：

```
tar xvzf apache-atlas-2.1.0-sources.tar.gz
```

修改atlas源码工程中的pom.xml：将hbase, zookeeper, hive等依赖版本修改成自己环境中一致的或兼容版本:

```
<hadoop.version>3.1.1</hadoop.version>
<hbase.version>2.2.6</hbase.version>
<solr.version>8.6.3</solr.version>
<hive.version>3.1.0</hive.version>
<kafka.version>2.2.1</kafka.version>
<kafka.scala.binary.version>2.11</kafka.scala.binary.version>
<calcite.version>1.16.0</calcite.version>
<zookeeper.version>3.6.2</zookeeper.version>
```

注：自己环境中hive版本一般是2.x但这里保持其默认的3.1.0，环境中hadoop版本偏低编译下载容易失败，所以保持其默认，而环境中kafka及其所编写的scala版本偏高，所以保持其默认

### 2. 执行maven编译

```
cd apache-atlas-sources-2.1.0/
export MAVEN_OPTS="-Xms2g -Xmx2g"
mvn clean -DskipTests install
```
Atlas可以使用内嵌的hbase-solr作为底层索引储存和搜索组件，也可以使用外置的hbase和solr，选择其中之一的方式就行。

#### a. 打包内嵌组件的话，最好先修改distro文件夹中hbase和solr压缩包的下载路径为:

```
<hbase.tar>http://mirrors.tuna.tsinghua.edu.cn/apache/hbase/${hbase.version}/hbase-${hbase.version}-bin.tar.gz</hbase.tar>

<solr.tar>http://mirrors.tuna.tsinghua.edu.cn/apache/lucene/solr/${solr.version}/solr-${solr.version}.tgz</solr.tar>
```

```
mvn clean -DskipTests package -Pdist,embedded-hbase-solr
```

#### b. 如果不内置的话:

```
mvn clean -DskipTests package -Pdist
```

#### c. 以debug模式编译下载：

```
mvn clean -DskipTests package -Pdist -X
```

编译打包时长比较慢，一般要2个小时，这个时候喝杯咖啡，看些文章，一会儿就过去了。遇到的问题无非是网络传输，node代理等问题，可以上网查找失败文件所对应的jar包以及pom文件下载放入本地maven仓库相应的路径中/root/.m2/repository/...

本人比较幸运，第一次编译选择内嵌hbase和solr只报了一个有关文件“Too many files with unapproved license”的错，删除对应报错路径多余的文件，重新在官网上下载对应的压缩包放进apache-atlas-sources-2.1.0中对应路径再继续之前的编译就好

```
mvn clean -DskipTests package -Pdist,embedded-hbase-solr -rf :报错的包名
```

编译下载成功，先🍻庆祝，然后查看apache-sources-2.1.0/distro/target下，你可以看到各种压缩包，包括二进制压缩包，用来监听各个组件的hook压缩包以及单纯atlas的server压缩包。

```
distro/target/apache-atlas-{project.version}-bin.tar.gz
distro/target/apache-atlas-{project.version}-hbase-hook.tar.gz
distro/target/apache-atlas-{project.version}-hive-hook.gz
distro/target/apache-atlas-{project.version}-kafka-hook.gz
distro/target/apache-atlas-{project.version}-sources.tar.gz
distro/target/apache-atlas-{project.version}-sqoop-hook.tar.gz
distro/target/apache-atlas-{project.version}-storm-hook.tar.gz
```

去其糟粕，取其精华，只要将apache-atlas-2.1.0-bin.tar.gz解压到服务器你专门存放server或者data之类的文件夹中，源码包其他的用不到。所以当时编译，本人在本地电脑上进行，然后得到二进制压缩包放到服务器上，进行下一步。

## 三、安装

到编译好的工程包的路径下apache-atlas-sources-2.1.0/distro/target，将生成好的安装包apache-atlas-2.1.0-bin.tar.gz拷贝到目标路径下，解压并且重命名：

```
tar zxvf apache-atlas-2.1.0-bin.tar.gz
mv apache-atlas-2.1.0 atlas-2.1.0
```

### (a) 如果当初选择内嵌编译下载的话，只要确保环境中已经配置好JAVA_HOME的环境变量，可以直接启动atlas，并到此为止：

```
cd /data/servers/atlas-2.1.0
bin/atlas_start.py
```

### (b) 如果要集成已经有的组件：

#### 1. 修改配置文件atlas-env.sh：

```
vim /data/servers/atlas-2.1.0/conf/atlas-env.sh
```

atlas-env.sh中修改下面几项：

```
export JAVA_HOME=/usr/local/java/jdk1.8.0_261
export MANAGE_LOCAL_HBASE=false # 不启动内嵌组件
export MANAGE_LOCAL_SOLR=false
# 修改Hbase配置文件路径
export HBASE_CONF_DIR=/data/servers/hbase-2.2.6/conf
```
#### 2. 然后是配置的重点以及难点，修改atlas-application.properties：

```
vim /data/servers/atlas-2.1.0/conf/atlas-application.properties
```

atlas-application.properties中修改hbase，solr，kafka的配置，并增加有关hive和hbase的hook的相关配置：

```
#Hbase
#for distributed mode, specify zookeeper quorum here
atlas.graph.storage.hostname=30.23.4.69:2181,30.23.5.206:2181,30.23.5.180:2181

#Solr
#Solr cloud mode properties
atlas.graph.index.search.solr.mode=cloud
atlas.graph.index.search.solr.zookeeper-url=30.23.4.69:2181,30.23.5.206:2181,30.23.5.180:2181/solr
atlas.graph.index.search.solr.zookeeper-connect-timeout=60000
atlas.graph.index.search.solr.zookeeper-session-timeout=60000
atlas.graph.index.search.solr.wait-searcher=true

#Notification Configs
atlas.notification.embedded=false
atlas.kafka.zookeeper.connect=30.23.4.69:2181,30.23.5.206:2181,30.23.5.180:2181/kafka
atlas.kafka.bootstrap.servers=30.23.4.69:9092,30.23.5.206:9092,30.23.5.180:9092
atlas.kafka.zookeeper.session.timeout.ms=60000
atlas.kafka.zookeeper.connection.timeout.ms=30000
atlas.kafka.enable.auto.commit=true

##### Server Properties #####
atlas.rest.address=http://localhost:21000

atlas.hook.hive.synchronous=false
atlas.hook.hive.numRetries=3
atlas.hook.hive.queueSize=10000

atlas.hook.hbase.synchronous=false
atlas.hook.hbase.numRetries=3
atlas.hook.hbase.queueSize=10000

atlas.cluster.name=primary
```

然后启动atlas，并可引入一些example数据：

```
cd /data/servers/atlas-2.1.0
bin/atlas_start.py
bin/quick_start.py
```

## 四、整合HBase、Hive

这是整个过程中最消磨一个人热情的时候，诸君一路祈祷吧


### 1.整合HBase

Atlas在HBase master注册一个钩子，当检测到HBase中namespaces/tables/column-families发生变化时，atlas安插的这个钩子会通过kafka通知来更新这些储存在atlas的元数据。

#### 1.1 修改$HBASE_HOME/conf里的hbase-site.xml配置

```
vim /data/servers/hbase-2.2.6/conf/hbase-site.xml
```

在原先的hbase-site.xml文件中添加如下配置：

```
<property>
  <name>hbase.coprocessor.master.classes</name>
  <value>org.apache.atlas.hbase.hook.HBaseAtlasCoprocessor</value>
</property>
```

#### 1.2 在$HBASE_HOME/lib中添加来自hbase-hook的软链接

```
ln -s /data/servers/atlas-2.1.0/hook/hbase/* $HBASE_HOME/lib/
```

#### 1.3 添加atlas-2.1.0/conf中的atlas-application.properties到$HBASE_HOME/conf中

atlas-application.properties中的如下内容是用来控制钩子的线程池以及Kafka通知配置：

```
atlas.hook.hbase.synchronous=false # whether to run the hook synchronously. false recommended to avoid delays in HBase operations. Default: false
atlas.hook.hbase.numRetries=3      # number of retries for notification failure. Default: 3
atlas.hook.hbase.queueSize=10000   # queue size for the threadpool. Default: 10000
atlas.cluster.name=primary # clusterName to use in qualifiedName of entities. Default: primary
atlas.kafka.zookeeper.connect=30.23.4.69:2181,30.23.5.206:2181,30.23.5.180:2181/kafka
atlas.kafka.zookeeper.connection.timeout.ms=30000
atlas.kafka.zookeeper.session.timeout.ms=60000
atlas.kafka.zookeeper.sync.time.ms=20
```
#### 1.4 导入原有HBase数据

```
cd /data/servers/atlas-2.1.0
hook-bin/import-hbase.sh
```

除了上述全导入之外还可以选择导入特定的表格或者在特定namespce的表格，用法如下：

```
Usage 1: <atlas package>/hook-bin/import-hbase.sh
Usage 2: <atlas package>/hook-bin/import-hbase.sh [-n <namespace regex> OR --namespace <namespace regex>] [-t <table regex> OR --table <table regex>]
Usage 3: <atlas package>/hook-bin/import-hbase.sh [-f <filename>]
           File Format:
             namespace1:tbl1
             namespace1:tbl2
             namespace2:tbl1
```

下面开始踩坑记录：

```
...
Caused by: org.apache.commons.configuration.ConversionException: 'atlas.graph.index.search.solr.wait-searcher' doesn't map to a List object: true, a java.lang.Boolean
...
Failed to import HBase Data Model!!!
```

这个是commons-configuration-{version}的版本冲突，原先import hbase调用1.6版本，这里要用1.10版本，所以要修改import-hbase.sh的脚本。

import-hbase.sh中：

```
CP="/data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/commons-configuration-1.10.jar:${HBASE_CP}:${HADOOP_CP}:${ATLASCPPATH}"
```

修改完后，终于能输入账户/密码了，但是下一个坑又来了：

```
>>>>> hook-bin/import-hbase.sh
>>>>> /data/servers/atlas-2.1.0
Using HBase configuration directory [/data/servers/hbase-2.2.6/conf]
Log file for import is /data/servers/atlas-2.1.0/logs/import-hbase.log
Enter username for atlas  :- admin
Enter password for atlas  :- 
Exception in thread "main" java.lang.NoClassDefFoundError: org/apache/htrace/core/Tracer
...
Caused by: java.lang.ClassNotFoundException: org.apache.htrace.core.Tracer
...
Failed to import HBase Data Model!!!
```

不就是缺包吗！通过find命令找到可能关联jar包，然后开始做起搬运工的本职工作：

```
find /data/servers/atlas-2.1.0/ -name htrace-core*
```

找到两个嫌疑人：

```
/data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/htrace-core-3.2.0-incubating.jar
/data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/htrace-core4-4.1.0-incubating.jar
```

然后嘿嘿，都粘到$HBASE_HOME/lib，其实试了一下，好像是调用了htrace-core4里的方法：

```
cp /data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/htrace-core-3.2.0-incubating.jar $HBASE_HOME/lib
cp /data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/htrace-core4-4.1.0-incubating.jar $HBASE_HOME/lib
```

OK! 成了！可在http://30.23.5.180:21000页面检索hbase_namespace、hbase_column_family、hbase_table等查看成功植入的数据。

```
>>>>> hook-bin/import-hbase.sh
>>>>> /data/servers/atlas-2.1.0
Using HBase configuration directory [/data/servers/hbase-2.2.6/conf]
Log file for import is /data/servers/atlas-2.1.0/logs/import-hbase.log
Enter username for atlas  :- admin
Enter password for atlas  :- 
HBase Data Model imported successfully!!!
```

#### 1.5 重启HBase验证Hook功能

HBase-hook相当于Atlas在HBase组件那儿驻扎的外交官，随时反馈HBase里表格的动向，做到知己知彼，数据治理

```
stop-hbase.sh
jps
```

可以看到主机的HMaster进程被停用了，心里默数三个数，然后重启：

```
start-hbase.sh
jps
```

检查到HMaster的进程又出现了，说明hook的配置没有影响到HBase的正常启动，然后验证一下hook有没有做事，在hbase创建一个table试试：

```
hbase shell
hbase(main):001:0> create 'test', 'cf'
hbase(main):001:0> list 'test'
hbase(main):001:0> describe 'test'
hbase(main):001:0> put 'test', 'row1', 'cf:a', 'value1'
hbase(main):001:0> put 'test', 'row2', 'cf:b', 'value2'
hbase(main):001:0> put 'test', 'row3', 'cf:b', 'value3'
hbase(main):001:0> scan 'test'
hbase(main):001:0> get 'test', 'row1'
```

以上在HBase建造了一个以test之名有三行数据的表格，先查看一下HBase遣团使有没有踏上丝绸之路：

```
kafka-console-consumer.sh --bootstrap-server 30.23.5.180:9092,30.23.4.69:9092,30.23.5.206:9092 --topic ATLAS_HOOK --from-beginning|jq
```

可以看到hbase_namespace、hbase_column_family、hbase_table在路上了，这时候访问http://30.23.5.180:21000检索它们的来访记录，可以看到它们已经到了而且在Atlas上登记过了，真是令人振奋的消息！有了前车之鉴，Atlas开始大张旗鼓在Hive也整个访团。

### 2. 整合Hive

Atlas在Hive组件中登记一个钩子用来监听它的create/update/delete的操作并且通过Kafka通知来更新存在Atlas里的Hive元数据

#### 2.1 修改$HIVE_HOME/conf里的hive-site.xml：

```
vim /data/servers/hive-2.0.1/conf/hive-site.xml
```

在原先的hive-site.xml文件中添加如下配置：

```
<property>
    <name>hive.exec.post.hooks</name>
    <value>org.apache.atlas.hive.hook.HiveHook</value>
</property>
```

#### 2.2 修改$HIVE_HOME/lib里的hive-env.sh

```
vim /data/servers/hive-2.0.1/conf/hive-env.sh
```

在原先的hive-env.sh里添加如下配置：

```
export HIVE_AUX_JARS_PATH=/data/servers/atlas-2.1.0/hook/hive
```

#### 2.3 复制atlas-2.1.0/conf中的atlas-application.properties到$HIVE_HOME/conf中

atlas-application.properties中的如下内容是用来控制钩子的线程池以及Kafka通知配置：

```
atlas.hook.hive.synchronous=false # whether to run the hook synchronously. false recommended to avoid delays in Hive query completion. Default: false
atlas.hook.hive.numRetries=3      # number of retries for notification failure. Default: 3
atlas.hook.hive.queueSize=10000   # queue size for the threadpool. Default: 10000
atlas.cluster.name=primary # clusterName to use in qualifiedName of entities. Default: primary
atlas.kafka.zookeeper.connect=30.23.4.69:2181,30.23.5.206:2181,30.23.5.180:2181/kafka
atlas.kafka.zookeeper.connection.timeout.ms=30000
atlas.kafka.zookeeper.session.timeout.ms=60000
atlas.kafka.zookeeper.sync.time.ms=20
```

#### 2.4 导入Hive元数据

```
cd /data/servers/atlas-2.1.0
bin/import-hive.sh
```

除了上述全导入之外还可以选择导入特定的表格或者在特定数据库的表格，用法如下：

```
Usage 1: <atlas package>/bin/import-hive.sh
Usage 2: <atlas package>/bin/import-hive.sh [-d <database regex> OR --database <database regex>] [-t <table regex> OR --table <table regex>]
Usage 3: <atlas package>/bin/import-hive.sh [-f <filename>]
           File Format:
             database1:tbl1
             database1:tbl2
             database2:tbl1
```

下面开始踩坑记录：

```
...
Caused by: org.apache.commons.configuration.ConversionException: 'atlas.graph.index.search.solr.wait-searcher' doesn't map to a List object: true, a java.lang.Boolean
...
Failed to import Hive Meta Data!!!
```

这个是commons-configuration-{version}的版本冲突，原先import hive调用1.6版本，这里要用1.10版本，所以要修改import-hive.sh的脚本。

import-hive.sh中：

```
CP="/data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/commons-configuration-1.10.jar:${HIVE_CP}:${HADOOP_CP}:${ATLASCPPATH}"
```

修改完这个之后，缺包的坑接踵而至，先陈列一下报错:

Error 1:

```
...
Exception in thread "main" java.lang.NoClassDefFoundError: com/fasterxml/jackson/jaxrs/base/ProvideerBase
...
Caused by: java.lang.ClassNotFoundException: com.fasterxml.jackson.jaxrs.base.ProviderBase
...
Failed to import Hive Meta Data!!!
```

Error 2:

```
...
Exception in thread "main" java.lang.NoClassDefFoundError: com/fasterxml/jackson/jaxrs/json/JacksonJaxbJsonProvider
...
Caused by: java.lang.ClassNotFoundException: com.fasterxml.jackson.jaxrs.json.JacksonJaxbJsonProvider
...
Failed to import Hive Meta Data!!!
```

Error 3:

```
...
Exception in thread "main" java.lang.NoClassDefFoundError: com/fasterxml/jackson/module/jaxb/JaxbAnnotationIntrospector
...
Caused by: java.lang.ClassNotFoundException: com.fasterxml.jackson.module.jaxb.JaxbAnnotationIntrospector
...
Failed to import Hive Meta Data!!!
```

Error 4:

```
...
Exception in thread "main" java.lang.NoClassDefFoundError: com/fasterxml/jackson/core/exc/InputCoercionException
...
Caused by: java.lang.ClassNotFoundException: com.fasterxml.jackson.core.exc.InputCoercionException
...
Failed to import Hive Meta Data!!!
```

开始搬运大法：

```
cp /data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/jackson-jaxrs-json-provider-2.9.9.jar hook/hive/atlas-hive-plugin-impl/

cp /data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/jackson-jaxrs-base-2.9.9.jar hook/hive/atlas-hive-plugin-impl/

cp /data/servers/atlas-2.1.0/server/webapp/atlas/WEB-INF/lib/jackson-module-jaxb-annotations-2.9.9.jar hook/hive/atlas-hive-plugin-impl/

cp /data/servers/spark-3.0.1/jars/jackson-core-2.10.0.jar hook/hive/atlas-hive-plugin-impl/
```

以上分别解决上述问题。期间还发生一个需要改源码包里的代码重新封装jar包的错误：

Error 5：

```
java.lang.NoSuchMethodError: org.apache.hadoop.hive.metastore.api.Database.getCatalogName()Ljava/lang/String;
```

修改源码包addons/hive-bridge/src/main/java/org/apache/atlas/hive/bridge/HiveMetaStoreBridge.java中的getDatabaseName()方法即可。

修改前：

```
public static String getDatabaseName(Database hiveDB) {
    String dbName      = hiveDB.getName().toLowerCase();
    String catalogName = hiveDB.getCatalogName() != null ? hiveDB.getCatalogName().toLowerCase() : null;

    if (StringUtils.isNotEmpty(catalogName) && !StringUtils.equals(catalogName, DEFAULT_METASTORE_CATALOG)) {
        dbName = catalogName + SEP + dbName;
    }

    return dbName;
}
```

排查后发现Atlas代码中用的Hive版本为3.1.0，而环境中的Hive是2.0.1。hive-bridge模块中调用了2.0.1版本中不存在的方法报错导致。注释掉部分代后：

```
public static String getDatabaseName(Database hiveDB) {
    String dbName      = hiveDB.getName().toLowerCase();
    /*
    String catalogName = hiveDB.getCatalogName() != null ? hiveDB.getCatalogName().toLowerCase() : null;

    if (StringUtils.isNotEmpty(catalogName) && !StringUtils.equals(catalogName, DEFAULT_METASTORE_CATALOG)) {
        dbName = catalogName + SEP + dbName;
    }
    */

    return dbName;
}
```

然后重新进addons/hive-bridge目录下打包出hive-bridge-2.1.0.jar，替换原先hook/hive/atlas-hive-plugin-impl目录下文件即可。最后，终于：

```
[root@SZD-L0430613 atlas-2.1.0]# bin/import-hive.sh
Using Hive configuration directory [/data/servers/hive-2.0.1/conf]
Log file for import is /data/servers/atlas-2.1.0/logs/import-hive.log
...
Enter username for atlas :- admin
Enter password for atlas :- 
Hive Meta Data imported successfully!!!
```
之后进入Atlas Web界面http://30.23.5.180:21000 可以查看之前植入的Hive元数据及HBase表格，在shell也可以通过curl命令查看相关信息，比如：

```
curl http://admin:admin@30.23.5.180:21000/api/atlas/entities?type=hive_db
curl -u admin:admin http://localhost:21000/api/atlas/v2/search/basic?typeName=hive_db
```

详细API可查看 https://atlas.apache.org/api/v2/index.html

在shell中查看Atlas通过Kafka能查看关于entity创建的通信的消费数据，命令如下：

```
kafka-console-consumer.sh --bootstrap-server 30.23.5.180:9092 --topic Atlas_ENTITIES --from-beginning|jq
```

#### 2.5 重启Hive验证Hook功能

```
jps
ps -ef|grep hive
```

可以查看到JVM的两个RunJar进程分别是Hive server以及Hive metastore的服务，获取它们的pid，然后通过直接拆炸弹剪线的方式，停止这两个进程

```
kill -9 <metastore's pid>
kill -9 <hiveserver2's pid>
```

然后心中祈祷一切顺利，开始重启：

```
nohup hive --service metastore >> /data/servers/hive-2.0.1/metastore.log 2>&1 &
nohup hive --service hiveserver2 >> /data/servers/hive-2.0.1/hiveserver2.log 2>&1 &
jps
pe -ef|grep hive
```

两个进程又见面了，说明hive-hook大概率安插成功了。验证一下hook的功能通不：

```
hive
.........
hive> create database atlasdemo;
hive> use atlasdemo;
hive> create table `test` (
hive>   `name` string,
hive>   `age` int
hive> );
hive> insert into `test` values ('xiaozeng', 19);

kafka-console-consumer.sh --bootstrap-server 30.23.5.180:9092,30.23.4.69:9092,30.23.5.206:9092 --topic ATLAS_HOOK --from-beginning|jq
```

查看到消息队列有新建db的消息，然后可以访问http://30.23.5.180:21000 检索hive_db查看到新建的database的详情，说明hive-hook的功能基本OK！

# Apache Atlas学习之路

## 一、看Atlas如何展现hive表格亲缘关系

hive表的血缘关系图是由一切由它产生以及一切为了产生它的实体组成。

hive建表参考：https://www.cnblogs.com/qingyunzong/p/8747656.html

### 例子1: 求单月访问次数和总访问次数

准备通过自定义数据，建造一张外部表，然后通过这张表进行数据分析

/root/zxx_test_data/access.txt

```
A,2015-01,5
A,2015-01,15
B,2015-01,5
A,2015-01,8
B,2015-01,25
A,2015-01,5
A,2015-02,4
A,2015-02,6
B,2015-02,10
B,2015-02,5
A,2015-03,16
A,2015-03,22
B,2015-03,23
B,2015-03,10
B,2015-03,1
```
上述表字段分别是：用户名、月份、访问次数; 然后开始建造atlas的hive实例；为了实时查看atlas信道数据，本人在mobaxterm上开了两个terminal界面，其中一个用来查看kafka的消费数据，另外一个开启hive客户端交互界面，分别如下：

```
kafka-console-consumer.sh --bootstrap-server 30.23.5.180:9092,30.23.4.69:9092,30.23.5.206:9092 --topic ATLAS_HOOK --from-beginning|jq
```

另外一个终端在打开hive交互界面之后，分别输入：

创建表：

```
create database xiaozeng;
use xiaozeng;

create external table if not exists t_access(
uname string comment '用户名',
umonth string comment '月份',
ucount int comment '访问次数'
) comment '用户访问表' 
row format delimited fields terminated by "," 
location "/hive/t_access";
```

导入数据并验证数据：

```
load data local inpath "zxx_test_data/access.txt" into table t_access;

select * from t_access;
```

在每次hive操作显示OK的时候，可以看到另外一个信道突然涌现有关创建新的hive_db、hive_table、hive_column的消息内容，很好，看着车水马龙，很安心！

然后根据原先的表另立当月访问次数表tmp_access：

```
create table tmp_access(
name string,
mon string,
num int
); 

insert into table tmp_access 
select uname,umonth,sum(ucount)
 from t_access t group by t.uname,t.umonth;select * from tmp_access;
```

接着分析每个用户的每月总访问量、历史月最大访问量以及每月累计访问量，并产出一个自连接视图tmp_view以及一张result_access的表格：

```
create view tmp_view as 
select a.name anme,a.mon amon,a.num anum,b.name bname,b.mon bmon,b.num bnum from tmp_access a join tmp_access b 
on a.name=b.name;

select * from tmp_view;

create table result_access as
select anme,amon,anum,max(bnum) as max_access,sum(bnum) as sum_access 
from tmp_view 
where amon>=bmon 
group by anme,amon,anum;
```

建了这三张表格成功后，除了看到kafka信道的流水json，我们这时候访问atlas UI界面：http://30.23.5.180:21000 左边👈检索hive_db然后点击右边👉出现的xiaozeng这个hive_db name的字段，进入它的详情页面，点击Relationships的tab，可以看到前面这三张表的名称显示在key为tables的value下，然后随意点击其中一张表，比如t_access，跳转到它的详情页面，点击Lineage的tab，一张巨幅的血缘网络出现在你眼前，从左到右分别是：

```
初始外部表的hdfs_path -> 导入数据的hive_process -> hive_table t_access -> query t_access的hive_process -> 根据query结果新建的hive_table tmp_access -> tmp_access自己join自己的 hive_process -> 表视图hive_table tmp_view -> 联立两张表的建表过程 hive_process -> 最终输出结果hive_table result_access
```

看到这里不禁倒吸一口冷气，深感凡事做过，必留痕迹；点击这条关系网络上的图标可以看到这个entity的实例基本信息的弹窗包括guid、类型、名称、所有者、建立时间、状态等，点击图标上方的名称，可以跳转到相应实例的详情页面；期间本人删除过几次表，在xiaozeng的hive_db详情页面上Relationships的tab下可看到这些table的状态是deleted🚮，既然信息详情那么详细，那如果给hive建立分区表，那会是怎么样呢?

### 例子2：学生课程成绩

在hive客户端中输入：

```
createt database partition_test;
use partition_test;

create table course (
id int,
sid int comment '学号',
course string comment '课程',
score int comment '成绩'
) comment '学生课程成绩'
partitioned by (dt String, school String)
row format delimited fields terminated by ",";

show tables;
```

可以看到关于course的表格已经建成，kafka信道上也有出现建造hive_table的实例的消息，来，造些数据:

/root/zxx_test_data/partitions/fudan-1.txt:

```
1,1,Math,89
2,1,CS,76
3,2,Math,99
4,2,CS,99
5,3,Math,100
6,3,CS,100
```

/root/zxx_test_data/partitions/mit-1.txt:

```
1,1,Math,43
2,1,CS,55
3,2,Math,77
4,2,CS,88
5,3,Math,98
6,3,CS,65
```

/root/zxx_test_data/partitions/mit-2.txt:

```
7,4,CS,76
8,4,Math,93
9,5,CS,53
10,5,Math,75
11,6,CS,68
12,6,Math,66
13,7,CS,85
14,7,Math,93
```

然后根据时间，学校分区导入数据到course表中，在hive客户端中输入：

```
load data local inpath 'zxx_test_data/partitions/mit-1.txt' into table course partition (dt='2021-01-27',school='MIT');
load data local inpath 'zxx_test_data/partitions/mit-2.txt' into table course partition (dt='2021-01-28',school='MIT');
load data local inpath 'zxx_test_data/partitions/fudan-1.txt' into table course partition (dt='2021-01-26',school='Fudan');
```
在kafka信道上看到消息后，访问http://30.23.5.180:21000 左边👈检索hive_table，`Search By Term`中输入`course`可以看到详情页面，properties下面出现partitionKeys的字段，里面有之前创的分区值`dt`和`school`，点击`dt`查看详情，发现它被归类为hive_column，好像分区也就相当于给原表加一个column，继续给`course`表加一些亲缘关系表，看看会不会产生什么裂变，比如：

```
create view tmp_course as
select sid, case course when "Math" then score else 0 end as Math,
case course when "CS" then score else 0 end as CS from course;

select * from tmp_course_view;

create view tmp_course_view1 as
select aa.sid, max(aa.Math) as Math, max(aa.CS) as CS from tmp_course_view aa group by sid;

select * from tmp_course_view1;

create table CS_gt_MAth_sid
comment '计算机成绩比数学好的成绩最好的学生' as
select * from tmp_course_view1 where CS > Math;
```

然后上atlas UI页面查看course的亲缘关系，发现它并没有把course这个hive_table实体拆开，看来atlas在管理各个组件的时候细粒度级就是这些实体，而partitions被归为hive_column

## 二、Atlas类型系统与Rest API

参考：

http://atlas.apache.org/api/v2/index.html

https://blog.csdn.net/x_iaoa_o/article/details/109581930

https://blog.csdn.net/wangpei1949/article/details/87891862

### 1. Apache Atlas组件官网综述

不才在这里翻译并简要概括一下官网所介绍的atlas结构，加上自己的理解，如若理解有所不妥，欢迎指出：

#### a. Atlas核心组件`Core`

`类型系统（Type System）`：将所有技术类的元数据`technical metadata`以及业务类的元数据`business metadata`对象化成一个个实体`entity`，每个实体分属于一种类型`type`，然后将他们的关系紧密联系起来。


```
技术类元数据：服务于制造对象元数据的中间产物，对于用户没有任何实质帮助
业务类元数据：大数据处理呈现给用户的最终产物，直接用于指导管理业务类数据的数据

实体：用户定义的具体的数据库、表格、kafka话题等等
类型: 将atlas所有集成组件如Hive、HBase大卸八块，包括所有在Atlas UI页面`Search By Type`下拉表单的所有内容、常见的比如hbase_column_family、hbase_namespace、hbase_table、hdfs_path、hive_column、hive_db、hive_table、LoadProcess、StorageDesc
```

`图像引擎（Graph Engine）`：用来给每个实体建立一个信息树🌲结构，方便用户及自己检索元数据对象，具象化表现为亲缘图`Lineage`以及构造关系图`Relationships`。

`导入与反馈（Ingest/Export）`：通过import的方法调用导入组件原有元数据以及通过atlas安插在各组件的hook及kafka信道实时反馈实体的成长变化。

#### b. 整合部分`Integration`包括`REST API`以及`信使Messaging`

`REST API`: 用户可以通过它创建、更新并且删除`类型`及`实体`，做到挟天子以令诸侯。不过感觉比较麻烦，条件允许的话创建及更新的工作还是交给各个组件吧。

`信使Messaging`：通过atlas安插在各个组件的hook生产数据，然后通过ATLAS-HOOK以及ATLAS-ENTITIES两大kafka信道获取消费数据。

#### c. 元数据来源`Metadata sources`

这部分是万恶之源，不过atlas还是很强大的，支持导入管理以下但不限于元数据来源：HBase、Hive、Sqoop、Storm、Kafka，导入意味着有功能即时或者批次处理元数据的导入，管理意味着atlas自己本身能定义这些组件的元数据对象。

#### d. 应用`Applications`

`Atlas管理用户界面Atlas Admin UI`：提供网页应用程序以供大数据管家以及科学家理解注释元数据，但是主要是用来检索的界面，支持任何类似sql的检索语句，用Rest API来实现它的功能。

`标签治理Tag Based Policies`：通过Apache Ranger来更高效安全地管理元数据。

### 2. 常用Rest API

#### a. AdminREST

查看Atlas Metadata Server节点状态 `GET` /admin/status：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/admin/status"|jq

ACTIVE:此实例处于活跃状态，可以响应用户请求。
PASSIVE:此实例处于被动状态。它会将收到的任何用户请求重定向到当前ACTIVE实例。
BECOMING_ACTIVE:此实例正在转换为ACTIVE实例，在此状态下无法为用户提供请求服务。
BECOMING_PASSIVE:此实例正在转换为PASSIVE实例，在此状态下无法为用户提供请求服务。

注意：正常情况下，只有一个应该为ACTIVE状态，其他实例均为PASSIVE状态。
```

查看Atlas版本和描述 `GET` /admin/version：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/admin/version"|jq
```

#### b. DiscoveryREST

基本搜索 `GET` /v2/search/basic：

```
#查询所有Hive表
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/search/basic?typeName=hive_table"|jq

#查询所有Hive表，且包含某一关键字
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/search/basic?query=custo*&typeName=hive_table"|jq
```

DSL 搜索 `GET` /v2/search/dsl：

```
#DSL方式查询Hive表
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/search/dsl?typeName=hive_table&query=where%20name%3D%22customer%22"|jq

注意:URL中特殊字符编码。
```

全文检索 `GET` /v2/search/fulltext：

```
#全文检索方式查询
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/search/fulltext?query=where%20name%3D%22customer%22"|jq
```

#### c. TypesREST

检索所有Type，并返回所有信息 `GET` /v2/types/typedefs：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/types/typedefs"|jq
```

检索所有Type，并返回最少信息 `GET` /v2/types/typedefs/headers：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/types/typedefs/headers"|jq
如:
{
    "guid": "77edd2dc-cc4e-4980-ae65-b3dd72cf5980",
    "name": "dim_table",
    "category": "CLASSIFICATION"
  },
  {
    "guid": "9d6c9b56-b91b-45f5-9320-d10c67736d05",
    "name": "fact_table",
    "category": "CLASSIFICATION"
  }
.......
```

#### d. EntityREST

批量根据GUID检索Entity `GET` /v2/entity/bulk：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/entity/bulk?minExtInfo=yes&guid=7a625477-060d-4629-8804-be241271c026"|jq
```

获取某个Entity定义 `GET` /v2/entity/guid/{guid}：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/entity/guid/7a625477-060d-4629-8804-be241271c026"|jq
```

获取某个Entity的TAG列表 `GET` /v2/entity/guid/{guid}/classifications：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/entity/guid/3b0ceec1-d41d-497a-b63e-d210b9862eef/classifications"|jq
```

#### e. LineageREST

查询某个Entity的Lineage GET /v2/lineage/{guid}：

```
curl -s -u admin:admin "http://30.23.5.180:21000/api/atlas/v2/lineage/c8f071e1-36d7-4a93-bc8f-35b0fa3b113c"|jq
```