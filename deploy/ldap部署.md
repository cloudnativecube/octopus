# 安装OpenLDAP

编译选项可以通过./configure --help查看；  
其中make test一步时间较长；  
如果未设置CPPFLAGS，configure过程可能会提示configure: error: BDB/HDB: BerkeleyDB not available 或 configure: error: BerkeleyDB version incompatible with BDB/HDB backends

## 安装部署
[ root@centos01 ~]# cd /home/guolei  
[ root@centos01 ~]# tar -xvf openldap-2.4.48.tgz  
[ root@centos01 ~]# cd openldap-2.4.48/  
[ root@centos01 openldap-2.4.48]# ./configure --prefix=/usr/local//src/openldap-2.4.48 --enable-spasswd --enable-syslog --enable-modules --enable-debug --with-tls CPPFLAGS=-I/usr/local/src/berkeleydb-5.1.29/include/ LDFLAGS=-L/usr/local/src/berkeleydb-5.1.29/lib/
```
遇到错误：configure: error: could not locate libtool ltdl.h
解决：rpm -ivh libtool-ltdl-devel-2.4.2-22.el7_3.x86_64.rpm
```
[ root@centos01 openldap-2.4.48]# make depend  
[ root@centos01 openldap-2.4.48]# make  
[ root@centos01 openldap-2.4.48]# make test  
[ root@centos01 openldap-2.4.48]# make install

### 设置可执行命令

[ root@centos01 ~]# ln -s /usr/local/src/openldap-2.4.48/bin/* /usr/local/bin/  
[ root@centos01 ~]# ln -s /usr/local/src/openldap-2.4.48/sbin/ /usr/local/sbin/  

### 配置openldap

配置rootdn密码(optional)  
设置rootdn密码，这里设置为admin@123  
这样rootdn密码为密文方式，复制输出密文到主配置文件rootdn对应的位置即可，如果不想麻烦，可以忽略此步，在主配置文件中使用明文即可。  
[root@centos01 openldap-2.4.48]# ./servers/slapd/slappasswd  
```
New password:
Re-enter new password:
{SSHA}h7vtH8Zp0wZOHeBcKMrPyjeV2O15IRBF
```

#### 修改配置文件
[ root@centos01 ~]# vim /usr/local/src/openldap-2.4.48/etc/openldap/slapd.conf  
include     /usr/local/src/openldap-2.4.48/etc/openldap/schema/core.schema  
schema默认只有core.schema，各级需要添加，这里将同配置文件一个目录的schema目录中有的schema文件都加到配置文件中
添加一下内容  
````
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/collective.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/corba.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/cosine.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/duaconf.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/dyngroup.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/inetorgperson.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/java.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/misc.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/nis.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/openldap.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/pmi.schema
include /usr/local/src/openldap-2.4.48/etc/openldap/schema/ppolicy.schema

pidfile     /usr/local/src/openldap-2.4.48/var/run/slapd.pid
argsfile    /usr/local/src/openldap-2.4.48/var/run/slapd.args
````

#### 修改域名及管理员账户名
```
suffix      "dc=openldap,dc=com"
rootdn      "cn=root,dc=openldap,dc=com"
```

#### 使用密文密码，即前面使用slappasswd生成的密文
rootpw      {SSHA}4hV2tOLdqS8SyUfySmuhqbaPT0ZLQu0K

### 启动OpenLADP
##### 直接在后台工作;
[ root@centos01 ~]# /usr/local/src/openldap-2.4.48/libexec/slapd

#### 在前台启动并输出debug信息
[ root@centos01 ~]# /usr/local/src/openldap-2.4.48/libexec/slapd -d 256


### 验证
验证监听的端口和启动的进程  
```
[ root@centos01 ~]# ss -tnl | grep 389
LISTEN     0      128          *:389                      *:*                  
LISTEN     0      128       [::]:389                   [::]:*                  
[ root@centos01 ~]# ps aux | grep slapd
root       7901  0.0  0.0 1169740 3996 ?        Ssl  17:08   0:00 /usr/local/src/openldap-2.4.48/libexec/slapd
```
验证openldap程序是否正常  
```
[ root@centos01 ~]# ldapsearch -x -b '' -s base'(objectclass=*)'
# extended LDIF
#
# LDAPv3
# base <> with scope baseObject
# filter: (objectclass=*)
# requesting: ALL
#

#
dn:
objectClass: top
objectClass: OpenLDAProotDSE

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
```

### 创建用户组和用户
#### 创建用户组
cat group.ldif  
```
dn: ou=people,dc=openldap,dc=com
objectClass: organizationalUnit
ou: people
```
ldapadd -x -D 'cn=root,dc=openldap,dc=com' -f group.ldif -w admin@123
#### 创建用户
cat user.ldif  
```
dn: uid=user1,ou=people,dc=openldap,dc=com
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: user1
uid: user1
uidNumber: 16859
gidNumber: 100
homeDirectory: /home/user1
loginShell: /bin/bash
gecos: user1
userPassword: 123456
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0
```
ldapadd -x -D 'cn=root,dc=openldap,dc=com' -f user.ldif -w admin@123
#### 查询
ldapsearch -x -b 'dc=openldap,dc=com'

