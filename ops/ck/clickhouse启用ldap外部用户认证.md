
### ldap server配置
vim /etc/clickhouse-server/config.d/ldap_servers.xml  
```
<?xml version="1.0" encoding="utf-8"?>
<yandex>
  <ldap_servers>
    <!--LDAP servers b9f1f80c_6598_11eb_80c1_39d7fbdc1e26-->
    <openldap1>
      <host>localhost</host>
      <port>389</port>
      <enable_tls>no</enable_tls>
      <auth_dn_prefix>cn=</auth_dn_prefix>
      <auth_dn_suffix>,ou=people,dc=openldap,dc=com</auth_dn_suffix>
      <tls_require_cert>never</tls_require_cert>
    </openldap1>
  </ldap_servers>
</yandex>
```
检查是否配置成功  
cat /home/servers/clickhouse/data/preprocessed_configs/config.xml |grep b9f1f80c_6598_11eb_80c1_39d7fbdc1e26  
### 添加ldap外部用户目录配置
vim /etc/clickhouse-server/config.d/ldap_external_user_directory.xml  
```
<yandex>
    <!--LDAP external user directory da296a1c-7874-11eb-998e-ddba30bbed5d -->
    <user_directories>
        <ldap>
            <server>openldap1</server>
            <roles>
                <ldap_user_role/>
            </roles>
        </ldap>
    </user_directories>
</yandex>
```
检查是否配置成功  
cat /home/servers/clickhouse/data/preprocessed_configs/config.xml |grep da296a1c-7874-11eb-998e-ddba30bbed5d  
### 重启clickhouse使其生效
clickhouse restart  
### 测试效果
#### 在CK内创建一个测试role并赋权
clickhouse-client -m  
CREATE ROLE ldap_user_role;  
SHOW ROLES;  
```
SHOW ROLES

Query id: f804dd09-88ba-476c-bbd7-e87dc87b1a21

┌─name───────────┐
│ cru_account    │
│ ldap_user_role │
│ z2_test        │
└────────────────┘

3 rows in set. Elapsed: 0.008 sec.
```
赋权  
GRANT ALL ON \*.\* TO ldap_user_role;  
#### 在ldap中创建一个用户
创建用户描述文件:  
vim user.ldif  
```
dn: cn=user8,ou=people,dc=openldap,dc=com
objectClass: inetOrgPerson
cn: user8
sn: Jensen
title: hahaha
mail: user8@pingan.com.cn
uid: abc
```
执行创建用户命令:  
ldapadd -x -D 'cn=root,dc=openldap,dc=com' -f user.ldif -w admin@123
获取用户密码:  
ldappasswd -x -H ldap://10.0.0.11:389 -D "cn=root,dc=openldap,dc=com" -w admin@123 "cn=user8,ou=people,dc=openldap,dc=com"  
 ```
 New password: 32bk1yKg
 ```
使用user8用户访问CK测试:  
clickhouse-client -n --user "user8" --password "32bk1yKg" -q "SELECT user()"  
正常返回结果  
```
user8
```
如果使用错误的密码:  
clickhouse-client -n --user "user8" --password "32bk1yKgxxx" -q "SELECT user()"  
```
Code: 516. DB::Exception: Received from localhost:9000. DB::Exception: user8: Authentication failed: password is incorrect or there is no user with such name.
```
