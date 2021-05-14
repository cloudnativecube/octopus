## 认证授权整体逻辑
- 用户属性包含鉴权信息和可访问地址
- Role是一组权限的集合，可以赋权给某用户或者其他Role
- SettingsProfile是对用户资源使用的限制，例如 max_memory_usage
- Quota是对用户访问频次的限制，例如 1分钟访问3次
- RowPolicy类似Ranger里面的行过滤
![image](https://user-images.githubusercontent.com/10804016/117924837-f5de9180-b328-11eb-8fef-297d867ed36a.png)  
权限的层级：https://clickhouse.tech/docs/zh/sql-reference/statements/grant/

## 认证
### 本地认证
本地认证就是在创建用户的时候设置密码  
auth_type: no_password | plaintext_password | sha256_password | sha256_hash | double_sha1_password | double_sha1_hash 
```
CREATE USER mira HOST IP '0.0.0.0/0' IDENTIFIED WITH sha256_password BY 'mira';
```
### ldap认证
#### 外部ldap用户鉴权认证
创建用户时选择ldap鉴权
```
CREATE USER mira IDENTIFIED WITH LDAP_SERVER BY 'openldap1';
```
openldap1是提前配置在clickhouse的配置文件中的。   
```
vim /etc/clickhouse-server/config.d/ldap_servers.xml 

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
#### 外部ldap用户目录认证
在clockhouse指定ldap搜索域，无需创建用户，可以直接使用ldap中的用户。  

```
vim /etc/clickhouse-server/config.d/ldap_external_user_directory.xml

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

### kerberos认证
#### 外部kerberos用户认证
创建用户时选择kerberos鉴权
```
CREATE USER mira IDENTIFIED WITH LDAP_SERVER BY kerberos REALM 'EXAMPLE.COM';
```
开启kerberos认证配置  
```
vim /etc/clickhouse-server/config.d/kerberos.xml

<?xml version="1.0" encoding="utf-8"?>
<yandex>
    <kerberos/>
</yandex>
```
#### 使用限制
- Kerberos身份验证不能与其他任何身份验证机制一起使用。如果其他任何部分（如kerberos）和密码一起出现，将迫使ClickHouse关闭。
- Kerberos is supported since version 21.4.
- Currently, Kerberos can only be used as an external authenticator for existing users.
- only use HTTP requests and must be able to authenticate using GSS-SPNEGO mechanism.

## 权限控制 - RBAC
#### 创建用户
#### 语法
```
CREATE USER [IF NOT EXISTS | OR REPLACE] name1 [ON CLUSTER cluster_name1] 
        [, name2 [ON CLUSTER cluster_name2] ...]
    [NOT IDENTIFIED | IDENTIFIED {[WITH {no_password | plaintext_password | sha256_password | sha256_hash | double_sha1_password | double_sha1_hash}] BY {'password' | 'hash'}} | {WITH ldap SERVER 'server_name'} | {WITH kerberos [REALM 'realm']}]
    [HOST {LOCAL | NAME 'name' | REGEXP 'name_regexp' | IP 'address' | LIKE 'pattern'} [,...] | ANY | NONE]
    [DEFAULT ROLE role [,...]]
    [SETTINGS variable [= value] [MIN [=] min_value] [MAX [=] max_value] [READONLY | WRITABLE] | PROFILE 'profile_name'] [,...]
```
##### 例子
```
CREATE USER mira HOST IP '127.0.0.1' IDENTIFIED WITH sha256_password BY 'qwerty'
```
#### 创建角色
#### 语法
```
CREATE ROLE [IF NOT EXISTS | OR REPLACE] name1 [, name2 ...]
    [SETTINGS variable [= value] [MIN [=] min_value] [MAX [=] max_value] [READONLY|WRITABLE] | PROFILE 'profile_name'] [,...]
```
##### 例子
CREATE ROLE accountant;
#### 授权语法
```
GRANT [ON CLUSTER cluster_name] privilege[(column_name [,...])] [,...] ON {db.table|db.*|*.*|table|*} TO {user | role | CURRENT_USER} [,...] [WITH GRANT OPTION]
GRANT [ON CLUSTER cluster_name] role [,...] TO {user | another_role | CURRENT_USER} [,...] [WITH ADMIN OPTION]
```
##### 给角色授权
```
GRANT SELECT(x,y) ON db.table TO accountant
GRANT accountant2 TO accountant
```
##### 给用户授权
```
GRANT SELECT(x,y) ON db.table TO mira WITH GRANT OPTION;
GRANT accountant TO mira WITH ADMIN OPTION;
```
GRANT OPTION : 权限允许给其它账号进行和自己账号权限范围相同的授权。  
ADMIN OPTION : 权限允许用户将他们的角色分配给其它用户。

## 行策略 - row policy
#### 语法
```
CREATE [ROW] POLICY [IF NOT EXISTS | OR REPLACE] policy_name1 [ON CLUSTER cluster_name1] ON [db1.]table1 
        [, policy_name2 [ON CLUSTER cluster_name2] ON [db2.]table2 ...] 
    [FOR SELECT] USING condition
    [AS {PERMISSIVE | RESTRICTIVE}]
    [TO {role1 [, role2 ...] | ALL | ALL EXCEPT role1 [, role2 ...]}]
```
#### 例子
```
CREATE ROW POLICY pol1 ON mydb.table1 USING b=1 TO mira, peter
```

#### 可见性公式

```
row_is_visible = (one or more of the permissive policies' conditions are non-zero) AND
                 (all of the restrictive policies's conditions are non-zero)
Example:
CREATE ROW POLICY pol1 ON mydb.table1 USING b=1 TO mira, peter
CREATE ROW POLICY pol2 ON mydb.table1 USING c=2 AS RESTRICTIVE TO peter, antonio
用户 peter 只能查询同时满足 b=1 AND c=2的行数据
```
## 设置描述 - settings profile
#### 语法
```
CREATE SETTINGS PROFILE [IF NOT EXISTS | OR REPLACE] TO name1 [ON CLUSTER cluster_name1] 
        [, name2 [ON CLUSTER cluster_name2] ...]
    [SETTINGS variable [= value] [MIN [=] min_value] [MAX [=] max_value] [READONLY|WRITABLE] | INHERIT 'profile_name'] [,...]
```
#### 例子
```
CREATE SETTINGS PROFILE max_memory_usage_profile SETTINGS max_memory_usage = 100000001 MIN 90000000 MAX 110000000 TO mira
```
#### READONLY(默认为WRITABLE)
set max_memory_usage=110000000  
```
Received exception from server (version 21.3.6):
Code: 452. DB::Exception: Received from localhost:9000. DB::Exception: Setting max_memory_usage should not be changed.
```
#### 继承
```
CREATE SETTINGS PROFILE max_memory_usage_profile2 SETTINGS INHERIT 'max_memory_usage_profile';
```
#### profiles
```
max_memory_usage
max_rows_to_read
max_bytes_to_read
max_execution_time
...
```

## 配额 - quota
#### 语法
```
CREATE QUOTA [IF NOT EXISTS | OR REPLACE] name [ON CLUSTER cluster_name]
    [KEYED BY {user_name | ip_address | client_key | client_key,user_name | client_key,ip_address} | NOT KEYED]
    [FOR [RANDOMIZED] INTERVAL number {second | minute | hour | day | week | month | quarter | year}
        {MAX { {queries | query_selects | query_inserts | errors | result_rows | result_bytes | read_rows | read_bytes | execution_time} = number } [,...] |
         NO LIMITS | TRACKING ONLY} [,...]]
    [TO {role [,...] | ALL | ALL EXCEPT role [,...]}]
```
#### 例子
限制mira用户在间隔为30分钟的时间段里，最大执行时间为0.5秒，在间隔为5刻钟的时间段内最大查询次数是321次，错误数是10。  

```
CREATE QUOTA qB FOR INTERVAL 30 minute MAX execution_time = 0.5, FOR INTERVAL 5 quarter MAX queries = 321, errors = 10 TO mira;
```
