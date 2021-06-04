# Superset

## 安装

### 环境

os版本：

```
# uname -r
3.10.0-1062.el7.x86_64
# cat /etc/centos-release
CentOS Linux release 7.7.1908 (Core)
```

软件版本（这两个版本比较匹配，其他版本安装都不顺利）：

- Python-3.7.10

- Superset-1.0.1

安装步骤参考：

- https://superset.apache.org/docs/installation/installing-superset-from-scratch

### 安装OS依赖

安装os依赖包：

```
# yum install gcc gcc-c++ libffi-devel python-devel python-pip python-wheel openssl-devel cyrus-sasl-devel openldap-devel
```

### 安装python-3.7.10

下载地址：https://www.python.org/ftp/python/3.7.10/Python-3.7.10.tar.xz

```
# ./configure
# make
# make install
# python3 --version
Python 3.7.10
```

### 安装Python Virtual Environment

```
# pip3 --version
pip 21.1.1 from /usr/local/lib/python3.7/site-packages/pip (python 3.7)
# pip3 install virtualenv //如果报错需要安装其他依赖，请执行pip3 install安装
# python3 -m venv venv //用venv命令，创建venv目录
# . venv/bin/activate //进入虚拟环境
# pip config list //默认是douban的源
global.index-url='http://pypi.douban.com/simple'
global.trusted-host='pypi.douban.com'
```

### 安装并初始化Superset

```
# pip install --upgrade pip
//安装superset的依赖，superset-src是源码目录
# cat superset-src/requirements/base.txt | awk '{print $1}' | grep -E "^[a-zA-Z]" | xargs -i pip install {} -i https://pypi.tuna.tsinghua.edu.cn/simple
# wget https://files.pythonhosted.org/packages/72/17/69d789e8a0d4248352e314d3e294b6ef9976a6b31f80ad1393d3cf35bd5e/apache-superset-1.0.1.tar.gz
# pip install ./apache-superset-1.0.1.tar.gz
# superset db upgrade //生成文件在：~/.superset/superset.db
# export FLASK_APP=superset
# superset fab create-admin //指定用户名密码都是admin
Username [admin]:
User first name [admin]:
User last name [user]:
Email [admin@fab.org]:
Password:
Repeat for confirmation:
Recognized Database Authentications.
Admin User admin created.
//初始化并启动
# superset init
# superset run -h 0.0.0.0 -p 8088 --with-threads --reload --debugger
```

注意：

- 有的依赖从默认安装源找不到，需要修改安装源，用-i参数指定：`pip install -i https://pypi.tuna.tsinghua.edu.cn/simple  <xxx>`。

- 如果安装过程中下载太慢，容易出现网络中断。解决办法是下载`.whl`，然后执行`pip install <xxx>.whl`。

  搜索依赖包的地址：https://pypi.org/search/?q=selenium，可以在“Release history”里查看该包的历史版本。

- 有的依赖包版本跟python版本绑定，这里选择的是python-3.7。

- 一次安装多个包可能会有冲突，所以最好还是逐个安装。

## 连接clickhouse

安装连接ck的依赖包：

```
clickhouse-driver==0.2.0
clickhouse-sqlalchemy==0.1.6
```

添加database时指定的jdbc链接地址（使用tcp端口9000）：

```
无密码： clickhouse+native://default@localhost:9000/default
有密码： clickhouse+native://demo:demo@localhost:9000/default
```

## 配置superset

将superset_config.py放到`PYTHONPATH`包含的路径里。flask的配置也可以写在superset_config.py里。

启动superset（假设superset_config.py放到/export/superset/venv）：

```
#!/bin/sh
export PYTHONPATH=$PYTHONPATH:/export/superset/venv
superset run -h 192.168.56.30 -p 8088 --with-threads --reload --debugger
```

如果让superset使用https，则在superset run命令之后添加参数：

```
--cert ./cert.pem  --key ./cert.key
```

产生证书的命令为：

```
# openssl genrsa > cert.key
# openssl req -new -x509 -key cert.key > cert.pem
```

参考：

- superset配置：https://superset.apache.org/docs/installation/configuring-superset
- flask配置：https://flask-appbuilder.readthedocs.org/en/latest/config.html

##  docker安装（未完成）

https://docs.docker.com/engine/install/centos/

```
yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
yum install -y yum-utils
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager --enable docker-ce-nightly
yum install docker-ce-18.06.3.ce-3.el7 docker-ce-cli-18.06.3.ce-3.el7 containerd.io
```

https://docs.docker.com/compose/install/

```
# curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
# docker-compose --version
docker-compose version 1.29.1, build c34c88b2
```

## 对接Knox SSO

文档：http://knox.apache.org/books/knox-1-5-0/user-guide.html。

1.将knox server所在的主机名centos0.local配置在conf/gateway-site.xml中：

```
<name>gateway.dispatch.whitelist</name>
<value>^https?:\/\/(localhost|127\.0\.0\.1|centos0.local|0:0:0:0:0:0:0:1|::1):[0-9].*$</value>  
```

2.启动knox server。

3.生成证书文件给superset用

在data/security/keystores中执行：

```
# keytool -keystore gateway.jks -export-cert -file gateway.cer -alias gateway-identity -rfc
```

然后把gateway.cer文件拷贝到superset目录下，并在superset_config.py中配置：

```
KNOX_CERT_FILE = "/export/superset/venv/gateway.cer"
```

在python环境中安装[Authlib](https://docs.authlib.org/en/stable/jose/index.html)（这里安装的是最新版0.15.3，项目仓库在https://github.com/lepture/authlib）：

```
# pip install Authlib
```

superset改动的代码在：cloudnativecube/superset-sso的master分支。

最终部署的文件如下：

```
(venv) [root@centos0 venv]# pwd
/export/superset/venv
(venv) [root@centos0 venv]# ll
总用量 40
drwxr-xr-x 2 root root 4096 5月  19 18:14 bin
-rw-r--r-- 1 root root 1679 6月   2 16:30 cert.key
-rw-r--r-- 1 root root 1472 6月   2 16:30 cert.pem
-rw-r--r-- 1 root root 4074 6月   3 14:02 custom_security.py
-rw-r--r-- 1 root root 1279 6月   2 11:29 gateway.cer
drwxr-xr-x 3 root root   18 5月  17 17:42 include
drwxr-xr-x 3 root root   23 5月  17 17:28 lib
lrwxrwxrwx 1 root root    3 5月  17 17:28 lib64 -> lib
drwxr-xr-x 2 root root   82 6月   3 14:02 __pycache__
-rw-r--r-- 1 root root   76 5月  17 17:28 pyvenv.cfg
-rw-r--r-- 1 root root 1360 6月   2 17:13 superset_config.py
-rwxr-xr-x 1 root root  226 6月   2 16:34 superset.sh
```

对于一个superset上不存在的用户，当knox认证通过之后，将在superset里自动创建该用户。然后通过admin给该用户授予角色Alpha和sql_lab，就可以用sql语句查询后端database了。

## 对接CAS（废弃）

### 安装python-cas client

可用版本到这里查看：https://pypi.org/project/python-cas/#history 。

```
# pip install python-cas==1.5.0
```

一个flask的example（参见https://djangocas.dev/blog/python-cas-flask-example/）：

```
# git clone git@github.com:python-cas/flask-example.git python-cas-flask-example
# cd python-cas-flask-example
# pip install -r requirements.txt
# sh run_debug_server.sh
```

### superset代码备忘

1.入口函数的定义：

```
lib64/python3.7/site-packages/apache_superset-1.0.1-py3.7.egg-info/entry_points.txt
```

2.修改日志级别

默认日志类：lib/python3.7/site-packages/superset/utils/logging_configurator.py

如果想开启某些模块的DEBUG日志，就在这个类里设置它的日志级别，比如：

```
logging.getLogger("flask_appbuilder").setLevel(logging.DEBUG)
```

3.编译superset并安装（好像没有生效，待以后验证）：

```
# python setup.py build
# cp build/lib/superset lib/python3.7/site-packages/
```

4.集成CAS

开发自定义的SecurityManager，用于SSO，代码文件：custom_security.py（存放在git上）。

配置文件superset_config.py：

```
# cat superset_config.py
from custom_security import CustomSecurityManager
CUSTOM_SECURITY_MANAGER = CustomSecurityManager
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Gamma"
```

将superset_config.py和custom_security.py放到/export/superset/venv目录下。

启动脚本：

```
# cat superset.sh
#!/bin/sh
export PYTHONPATH=$PYTHONPATH:/export/superset/venv
superset run -h 192.168.56.30 -p 8088 --with-threads --reload --debugger
```

启动：

```
# ./superset.sh
```

参考文档：

- Flask-AppBuilder文档：https://flask-appbuilder.readthedocs.io/en/latest/intro.html

### 编译cas server

cas编译依赖java11。

macos安装java11的下载地址：https://repo.huaweicloud.com/java/jdk/11.0.2+9/jdk-11.0.2_osx-x64_bin.dmg。

```
# export JAVA_HOME=`/usr/libexec/java_home -v 11` 
```

#### 1. 使用cas-overlay-template编译

```
# git clone git@github.com:apereo/cas-overlay-template.git
# cd cas-overlay-template
# vim gradle.properties // 修改cas.version为合适的版本
# ./gradlew build //期间可能因为依赖包下载失败而停止，解决办法是手动下载后放到当前目录即可
```

如果下载gradle包很慢，可以这样解决：

```
(1) 手动下载gradle-7.0-bin.zip，然后拷贝到gradle/wrapper目录里
(2) 修改配置文件gradle/wrapper/gradle-wrapper.properties以下参数：
distributionUrl=gradle-7.0-bin.zip
```

#### 2. 使用源码编译

参考：https://apereo.github.io/cas/6.3.x/developer/Build-Process.html

```
# git clone git@github.com:apereo/cas.git 
# cd cas
# git branch branch-v6.3.4 v6.3.4
# git checkout branch-v6.3.4
# cp gradle-6.8.3-bin.zip gradle/wrapper //下载gradle安装包，放到gradle/wrapper目录下
// 修改配置文件gradle/wrapper/gradle-wrapper.properties：
distributionUrl=gradle-6.8.3-bin.zip
# ./gradlew build install --parallel -x test -x javadoc -x check --build-cache --configure-on-demand
```

### 部署cas  server

生成密钥库：

```
//创建密钥库
# keytool -genkey -alias cas -keyalg RSA -validity 999 -keystore /etc/cas/thekeystore -ext san=dns:$HOSTNAME
//生成证书文件
# keytool -export -file /etc/cas/config/cas.crt -keystore /etc/cas/thekeystore -alias cas
//导入证书到全局密钥库
# sudo keytool -import -file /etc/cas/config/cas.crt -alias cas -keystore $JAVA_HOME/lib/security/cacerts
```

配置文件/etc/cas/config/cas.properties：

```
# cat /etc/cas/config/cas.properties
cas.server.name=https://marsno.local:8443
cas.server.prefix=${cas.server.name}/cas
logging.config=file:/etc/cas/config/log4j2.xml
cas.authn.accept.users=casuser::Mellon
cas.service-registry.watcher-enabled=true
cas.service-registry.init-from-json=true
cas.service-registry.json.location=file:/etc/cas/services
cas.logout.follow-service-redirects=true
cas.logout.redirect-parameter=service
```

一个service的例子：

```
# cat /etc/cas/services/centos0-10000001.json
{
  "@class": "org.apereo.cas.services.RegexRegisteredService",
  "serviceId": "http://.*",
  "name": "centos0",
  "id": 10000001,
  "description": "description demo",
  "evaluationOrder": 1
}
```

启动cas-server：

```
// 这是cas-overlay方式编译出来的包
# java -jar build/libs/cas.war
```

用浏览器访问：https://marsno.local:8443/cas

登录的用户名/密码：casuser / Mellon

#### 其他密钥库常用操作

```
//列出密钥库中的条目
# keytool -storepass changeit -list -keystore /Library/Java/JavaVirtualMachines/jdk-11.0.2.jdk/Contents/Home/lib/security/cacerts
```

