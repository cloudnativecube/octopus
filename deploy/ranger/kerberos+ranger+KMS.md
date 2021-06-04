# Kerberos安装

## 参考：

1. https://www.jianshu.com/p/f84c3668272b
2. https://www.jianshu.com/p/fc2d2dbd510b
3. http://web.mit.edu/kerberos/krb5-1.12/doc/admin/conf_files/kadm5_acl.html

## 安装Kerberos：

```shell
yum install krb5-server krb5-libs krb5-workstation -y
```

- ### 1.配置kdc.conf:
```shell
vim /var/kerberos/krb5kdc/kdc.conf
```

    - #### 1.1 kdc.conf:
    ```conf
    [kdcdefaults]
    kdc_ports = 88
    kdc_tcp_ports = 88
    
    [realms]
    HADOOP.COM = {
        #master_key_type = aes256-cts
        acl_file = /var/kerberos/krb5kdc/kadm5.acl
        dict_file = /usr/share/dict/words
        admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
        max_renewable_life = 7d
        supported_enctypes = aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
    }
    ```
    
    - #### 1.2 说明：
        - HADOOP.COM:是设定的realms。名字随意。Kerberos可以支持多个realms，一般全用大写
        - master_key_type，supported_enctypes默认使用aes256-cts。由于，JAVA使用aes256-cts验证方式需要安装额外的jar包，这里暂不使用
        - acl_file:标注了admin的用户权限。文件格式是
        - Kerberos_principal permissions [target_principal] [restrictions]支持通配符等
        - admin_keytab:KDC进行校验的keytab
        - supported_enctypes:支持的校验方式。注意把aes256-cts去掉

- ### 2.配置krb5.conf：
```shell
vim /etc/krb5.conf
```

    - #### 2.1 配置krb5.conf:
    ```conf
    # Configuration snippets may be placed in this directory as well
    includedir /etc/krb5.conf.d/

    [logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log

    [libdefaults]
    dns_lookup_realm = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    clockskew = 120
    udp_preference_limit = 1
    pkinit_anchors = FILE:/etc/pki/tls/certs/ca-bundle.crt
    
    [realms]
    HADOOP.COM = {
        kdc = slave03:88
        admin_server = slave03
    }

    [domain_realm]
    .hadoop.com = HADOOP.COM
    hadoop.com = HADOOP.COM
    ```
    
    - #### 2.2 说明:
        - [logging]：表示server端的日志的打印位置
        - udp_preference_limit = 1 禁止使用udp可以防止一个Hadoop中的错误
        - ticket_lifetime： 表明凭证生效的时限，一般为24小时。
        - renew_lifetime： 表明凭证最长可以被延期的时限，一般为一个礼拜。当凭证过期之后，对安全认证的服务的后续访问则会失败。
        - clockskew：时钟偏差是不完全符合主机系统时钟的票据时戳的容差，超过此容差将不接受此票据，单位是秒
        
- ### 3.初始化kerberos database
```shell
kdb5_util create -s -r HADOOP.COM
```

    - #### 3.1 显示过程类似于：
    
    ```shell
    Loading random data
    Initializing database '/var/kerberos/krb5kdc/principal' for realm 'HADOOP.COM',
    master key name 'K/M@HADOOP.COM'
    You will be prompted for the database Master Password.
    It is important that you NOT FORGET this password.
    Enter KDC database master key: admin@123
    Re-enter KDC database master key to verify: 
    ```
    
    - #### 3.2 说明：
        - [-s] 生成一个stashfile
        - [-r] 制定一个realm name, 当krb5.conf中定义了多个realm时才有必要
        
- ### 4. 修改database administrator的ACL权限

```shell
vim /var/kerberos/krb5kdc/kadmin.acl

#修改为：
*/admin@HADOOP.COM  *
```

- ### 5. 启动kerberos daemons

```shell
systemcl start kadmin krb5kdc
systemcl enable kadmin krb5kdc
```

- ### 6. 配置root/admin密码

```bash
[root@SZD-L0430610 ~]# kadmin.local
Authenticating as principal root/admin@HADOOP.COM with password.
kadmin.local:  addprinc root/admin
WARNING: no policy specified for root/admin@HADOOP.COM; defaulting to no policy
Enter password for principal "root/admin@HADOOP.COM": 
Re-enter password for principal "root/admin@HADOOP.COM": 
Principal "root/admin@HADOOP.COM" created.
kadmin.local:  listprincs
K/M@HADOOP.COM
kadmin/admin@HADOOP.COM
kadmin/changepw@HADOOP.COM
kadmin/szd-l0430610@HADOOP.COM
kiprop/szd-l0430610@HADOOP.COM
krbtgt/HADOOP.COM@HADOOP.COM
root/admin@HADOOP.COM
kadmin.local:   q
```

# Ranger整合Kerberos

## 参考：
1. https://www.cnblogs.com/yjt1993/p/11888044.html

## 整合Kerberos

- ### 1. 在kerberos服务器生成用于ranger的用户主体：

```bash
# kadmin.local
addprinc -randkey HTTP/manager1@HADOOP.COM
addprinc -randkey rangeradmin/manager1@HADOOP.COM
ktadd -norandkey -kt rangeradmin.keytab HTTP/manager1@HADOOP.COM  rangeradmin/manager1@HADOOP.COM
```

拷贝rangeradmin.keytab到ranger admin的install.properties文件：
```shell
cp /root/rangeradmin.keytab /data/servers/apache-ranger-2.1.0/target/ranger-2.1.0-admin/
```

- ### 2. 修改配置

```shell
vim /data/servers/apache-ranger-2.1.0/target/ranger-2.1.0-admin/install.properties
```

主要修改以下配置：
```
#------------ Kerberos Config -----------------
spnego_principal=HTTP/manager1@HADOOP.COM
spnego_keytab=/data/servers/apache-ranger-2.1.0/target/ranger-2.1.0-admin/rangeradmin.keytab

admin_principal=rangeradmin/manager1@HADOOP.COM
admin_keytab=/data/servers/apache-ranger-2.1.0/target/ranger-2.1.0-admin/rangeradmin.keytab
lookup_principal=rangeradmin/manager1@HADOOP.COM
lookup_keytab=/data/servers/apache-ranger-2.1.0/target/ranger-2.1.0-admin/rangeradmin.keytab

hadoop_conf=/data/servers/hadoop-2.6.0/etc/hadoop/
```

- ### 3. 初始化并重启ranger-admin
```shell
cd /data/servers/apache-ranger-2.1.0/target/ranger-2.1.0-admin/
./setup.sh
ranger-admin restart
```

# 配置KMS