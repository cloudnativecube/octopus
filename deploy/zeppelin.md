# Zeppelin安装及使用

官方文档：http://zeppelin.apache.org/docs/0.9.0/

### 1.环境要求

安装版本0.9.0，需要环境为JDK1.8 (151+，set `JAVA_HOME`)

### 2.安装Zeppelin

1.下载安装包，安装包分两个版本：

1）包含全部interpreters：[**https://mirrors.bfsu.edu.cn/apache/zeppelin/zeppelin-0.9.0/zeppelin-0.9.0-bin-all.tgz**](https://mirrors.bfsu.edu.cn/apache/zeppelin/zeppelin-0.9.0/zeppelin-0.9.0-bin-all.tgz) 

2）仅包含spark等常用的interpreters：[**https://mirrors.bfsu.edu.cn/apache/zeppelin/zeppelin-0.9.0/zeppelin-0.9.0-bin-netinst.tgz**](https://mirrors.bfsu.edu.cn/apache/zeppelin/zeppelin-0.9.0/zeppelin-0.9.0-bin-netinst.tgz) 

本次安装的是第二种。

2.在安装路径解压，修改配置文件

```
cd /home/servers/zeppelin-0.9.0-bin-netinst/conf
mv zeppelin-site.xml.template zeppelin-site.xml
mv zeppelin-env.sh.template zeppelin-env.sh
```

以上两个文件可以根据需要修改其中的端口配置及JAVA_HOME等。

zeppelin-site.xml文件可修改如下两个参数：

```xml
<!--允许从任一服务器访问-->
<property>
  <name>zeppelin.server.addr</name>
  <value>0.0.0.0</value>
  <description>Server binding address</description>
</property>

<!--根据需要修改服务端口-->
<property>
  <name>zeppelin.server.port</name>
  <value>8082</value>
  <description>Server port.</description>
</property>
```

3.安装interpreters

默认的轻量安装包不包含jdbc，需要扩展jdbc interpreter，其他interpreter也可以根据需要安装，可供安装的interpreter可以执行以下命令查看。

```sh
#列出可安装的interpreter
./bin/install-interpreter.sh --list
#安装需要从maven仓库下载包，需要联网
./bin/install-interpreter.sh --name jdbc 
```

下载trino的jdbc包并放在./interpreter/jdbc/trino-jdbc-353.jar。

下载链接：https://repo1.maven.org/maven2/io/trino/trino-jdbc/353/trino-jdbc-353.jar

4.启动服务

```sh
/home/servers/zeppelin-0.9.0-bin-netinst/bin/zeppelin-daemon.sh start
```

启动完毕后可以访问页面http://10.0.0.11:8082，开始使用zeppelin。

5.配置trino interpreter

zeppelin默认不支持trino，可以通过新增一个jdbc interpreter来配置：

1）访问http://10.0.0.11:8082/#/interpreter，点击create interpreter；

2）interpreter name可赋值trino，interpreter group选择jdbc，其他需修改如下属性：

default.url=jdbc:trino://10.0.0.11:8081

default.driver=com.facebook.presto.jdbc.PrestoDriver

default.user=xxx（用户名和密码需要结合trino的配置，测试环境暂未设置权限，可随意填一个）

3）新建notebook，选择trino interpreter，可以执行测试SQL。

 





