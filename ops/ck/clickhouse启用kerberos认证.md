## Kerberos简介
Kerberos主要用于计算机网络的身份鉴别, 用户只需输入一次身份验证信息就可以凭借此验证获得的票据(ticket-granting ticket)访问多个服务，即SSO(Single Sign On)。由于在每个Client和Service之间建立了共享密钥，使得该协议具有相当的安全性。  
Kerberos 是第三方认证机制，其中用户和服务依赖于第三方（Kerberos 服务器）来对彼此进行身份验证。整体上有以下三部分组成:  
（1）保存用户和服务及其各自的 Kerberos 密码的数据库。  
（2）认证服务器（Authentication Server，简称 AS）：验证Client端的身份（确定你是身份证上的本人），验证通过就会给一张票证授予票证（Ticket Granting Ticket，简称 TGT）给 Client。  
（3）票据授权服务器（Ticket Granting Server，简称 TGS）：通过 TGT（AS 发送给 Client 的票）获取访问 Server 端的票（Server Ticket，简称 ST）。ST（Service Ticket）也有资料称为 TGS Ticket。  
### 访问过程
![image](https://user-images.githubusercontent.com/10804016/116025739-c6225f00-a683-11eb-822d-4f011e111539.png)
### kerberos故事
网上找的，能更好的帮助kerberos工作过程
```
首先用户去游乐场肯定是游乐场授权的，而且可以制定用户对哪些游乐设施在特定的时间有特定的游玩权限，这个信息需要在游乐场那里提前记录，对应Kerberos就是后台执行add_principal命令。
用户拥有自己的用户名和密码，密码只有用户自己和游乐场管理处知道，游乐设施都不能知道用户密码，否则用户密码需要多个地方存储而且对于做得不好的有了设施也有泄漏用户密码的风险。
用户直接去游乐场门卫那里说明自己要进园，这时不能直接报上自己的用户名和密码，因为旁边的人可能偷听，在互联网中截取路由中的消息包非常简单，并且获取监听到用户密码可以做更多高危操作。
因为不能直接报密码，因此这里就需要第一次的非对称加密，简化一下实际的加密流程，游乐园提供一个公开的复杂数字例如958746，假设用户密码是23452，然后经过一个不可逆计算例如用户密码加上公开数字然后平方再加上用户密码的平方，也就是(958746+23452)**2+23452**2=965262907508，这个数字即使被别人看到了再加上公开的数字也难以知道用户密码是什么，而游乐园因为已经支持了用户密码因此只需要代入公式简单计算就可以验证这个用户是否合法。
游乐园确认用户信息后，就可以基于用户的密码来生成一个新的加密数字，加密后的数字虽然是公开的，但因为只有用户有自己的密码因此只有用户知道加密前的数字是什么，后续用户和管理员通信就用加密前的数字加密就可以，这样也可以避免其他用户在不知道真实用户密码的是否也发一个965262907508的请求，即使服务器响应了返回结果不知道真实用户密码也是没用的。
用户和游乐园有了专属的加密通信渠道后，游乐园就会给用户发送每个游乐设施的ticket，里面包含了这个用户可以在特定时间内对特定游乐设施可以进行的特定操作，那么这个ticket也不能是明文写的，因为用户就可以自己伪造ticket来直接用游乐设备了。
因此游乐园和每个游乐设备都需要谈好一个加密数字，这个加密数字也是只有游乐园和各个游乐设备自己知道，游乐园就是用这个加密数字把信息加密好再发给用户，用户拿到加密后的ticket其实也不理解内容，因为是不可逆加密因此也无法伪造一个合法的ticket。
用户就把管理员给的ticket，以及自己的信息按和游乐场约定加密数字进行加密发送，那么游乐设施拿到ticket因为自己知道和游乐场约定的加密数字因此知道这个用户是否合法，里面还包括了用户和管理员约定的加密数字，因此可以解密用户发来的信息来确认身份。
这个过程和前面的故事拿卡到票据授权机直接刷票不一样，是因为现实生活中默认拿着卡的就是卡的拥有着，而互联网上截取别人的卡的机会则更多，因此除了把卡给游乐设别还需要发一段不可伪造的加密信息，而游乐设别不需要知道用户的密码只需要知道用户和游乐场约定的加密数字就可以，整个过程所有出示的数字都可以公开和截取，但伪造者一直没有办法能模拟真实用户来请求。
这是我重新复术的Kerberos工作原理故事，显然Kerberos的家解密算法不只是简单的数值计算，而且没有绝对安全的加密算法，只能保证在现有计算能力的限制下极大概率保证安全，而这种在公开环境下仍能保证私密通信的机制，让我们再次感受到数学和计算之美。
```
## Kerberos部署
### Master主机安装Kerberos
vim /var/kerberos/krb5kdc/kdc.conf
```
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 EXAMPLE.COM = {
  #master_key_type = aes256-cts
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 }
```
vim /etc/krb5.conf
```
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
 pkinit_anchors = FILE:/etc/pki/tls/certs/ca-bundle.crt
 default_realm = EXAMPLE.COM
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 EXAMPLE.COM = {
  kdc = centos03
  admin_server = centos03
 }

[domain_realm]
 .example.com = EXAMPLE.COM
 example.com = EXAMPLE.COM
```
### 初始化kerberos database
kdb5_util create -s -r EXAMPLE.COM
### 修改database administrator的ACL权限
vim /var/kerberos/krb5kdc/kadm5.acl  
#修改如下  
*/admin@EXAMPLE.COM     *
### 启动kerberos daemons
systemctl start kadmin krb5kdc  
systemctl enable kadmin krb5kdc
### 部署Kerberos Client
yum install krb5-workstation krb5-libs -y  
scp /etc/krb5.conf node-2:/etc/krb5.conf
### kerberos操作
#### 配置root/admin密码
```
[root@centos03 log]# kadmin.local
Authenticating as principal hd1/admin@EXAMPLE.COM with password.
kadmin.local:  addprinc root/admin
WARNING: no policy specified for root/admin@EXAMPLE.COM; defaulting to no policy
Enter password for principal "root/admin@EXAMPLE.COM":
Re-enter password for principal "root/admin@EXAMPLE.COM":
add_principal: Principal or policy already exists while creating "root/admin@EXAMPLE.COM".
kadmin.local:  listprincs
K/M@EXAMPLE.COM
hd1@EXAMPLE.COM
kadmin/admin@EXAMPLE.COM
kadmin/centos03@EXAMPLE.COM
kadmin/changepw@EXAMPLE.COM
kiprop/centos03@EXAMPLE.COM
krbtgt/EXAMPLE.COM@EXAMPLE.COM
root/admin@EXAMPLE.COM
```
#### 添加新用户
```
[root@centos03 log]# kadmin
Authenticating as principal root/admin@EXAMPLE.COM with password.
Password for root/admin@EXAMPLE.COM:
kadmin:  addprinc hd2
WARNING: no policy specified for hd2@EXAMPLE.COM; defaulting to no policy
Enter password for principal "hd2@EXAMPLE.COM":
Re-enter password for principal "hd2@EXAMPLE.COM":
Principal "hd2@EXAMPLE.COM" created.
```
#### 用户登录
```
[root@centos03 log]# kinit hd2
Password for hd2@EXAMPLE.COM:
[root@centos03 log]# klist
Ticket cache: KEYRING:persistent:0:0
Default principal: hd2@EXAMPLE.COM

Valid starting       Expires              Service principal
2021-04-26T13:46:08  2021-04-27T13:46:08  krbtgt/EXAMPLE.COM@EXAMPLE.COM
```
## Clickhouse启用Kerberos认证
### 使用限制
1. Kerberos身份验证不能与其他任何身份验证机制一起使用。如果其他任何部分（如kerberos）和密码一起出现，将迫使ClickHouse关闭。
2. Kerberos is supported since version 21.4.
3. Currently, Kerberos can only be used as an external authenticator for existing users.
4. only use HTTP requests and must be able to authenticate using GSS-SPNEGO mechanism.

### 启动21.4.5.46版本的CK
docker run -d --name clickhouse-server --ulimit nofile=262144:262144 -p 9000:9000 -p 8123:8123 docker.io/yandex/clickhouse-server:21.4.5.46 sleep infinity  
#### 启动ck
clickhouse start
### CK配置
vim /etc/clickhouse-server/config.d/kerberos.xml
```
<?xml version="1.0" encoding="utf-8"?>
<yandex>
    <kerberos/>
</yandex>
```
vim /etc/clickhouse-server/users.d/kerberosuser.xml
```
<?xml version="1.0" encoding="utf-8"?>
<yandex>
    <users>
        <hd1>
            <kerberos>
                <realm>EXAMPLE.COM</realm>
            </kerberos>
        </hd1>
    </users>
</yandex>
```
### 未完成
#### Kerberos HTTP SPNEGO
https://docs.cloudera.com/cdp-private-cloud-base/7.1.6/scaling-namespaces/topics/hdfs-curl-url-http-spnego.html  
测试命令(未生效，一直返回default用户):  
echo 'SELECT user()' | curl  -u : --negotiate 'http://127.0.0.1:8123/' -d @-  
查看curl是否支持GSS-API  
```
curl --version
curl 7.58.0 (x86_64-pc-linux-gnu) libcurl/7.58.0 OpenSSL/1.1.0g zlib/1.2.11 libidn2/2.0.4 libpsl/0.19.1 (+libidn2/2.0.4) nghttp2/1.30.0 librtmp/2.3
Release-Date: 2018-01-24
Protocols: dict file ftp ftps gopher http https imap imaps ldap ldaps pop3 pop3s rtmp rtsp smb smbs smtp smtps telnet tftp
Features: AsynchDNS IDN IPv6 Largefile GSS-API Kerberos SPNEGO NTLM NTLM_WB SSL libz TLS-SRP HTTP2 UnixSockets HTTPS-proxy PSL
```
#### 测试
目前还没有跑通，关于CK启用kerberos的资料很少，需要梳理用户认证相关代码  
ClickHouse-21.4.5.46-stable/src/Access/Authentication.cpp
```
bool Authentication::areCredentialsValid(const Credentials & credentials, const ExternalAuthenticators & external_authenticators) const
{
    if (!credentials.isReady())
        return false;

    if (const auto * gss_acceptor_context = dynamic_cast<const GSSAcceptorContext *>(&credentials))
    {
        switch (type)
        {
            case NO_PASSWORD:
            case PLAINTEXT_PASSWORD:
            case SHA256_PASSWORD:
            case DOUBLE_SHA1_PASSWORD:
            case LDAP:
                throw
                <BasicCredentials>("ClickHouse Basic Authentication");

            case KERBEROS:
                return external_authenticators.checkKerberosCredentials(kerberos_realm, *gss_acceptor_context);

            case MAX_TYPE:
                break;
        }
    }

    if (const auto * basic_credentials = dynamic_cast<const BasicCredentials *>(&credentials))
    {
        switch (type)
        {
            case NO_PASSWORD:
                return true; // N.B. even if the password is not empty!

            case PLAINTEXT_PASSWORD:
            {
                if (basic_credentials->getPassword() == std::string_view{reinterpret_cast<const char *>(password_hash.data()), password_hash.size()})
                    return true;

                // For compatibility with MySQL clients which support only native authentication plugin, SHA1 can be passed instead of password.
                const auto password_sha1 = encodeSHA1(password_hash);
                return basic_credentials->getPassword() == std::string_view{reinterpret_cast<const char *>(password_sha1.data()), password_sha1.size()};
            }

            case SHA256_PASSWORD:
                return encodeSHA256(basic_credentials->getPassword()) == password_hash;

            case DOUBLE_SHA1_PASSWORD:
            {
                const auto first_sha1 = encodeSHA1(basic_credentials->getPassword());

                /// If it was MySQL compatibility server, then first_sha1 already contains double SHA1.
                if (first_sha1 == password_hash)
                    return true;

                return encodeSHA1(first_sha1) == password_hash;
            }

            case LDAP:
                return external_authenticators.checkLDAPCredentials(ldap_server_name, *basic_credentials);

            case KERBEROS:
                throw Require<GSSAcceptorContext>(kerberos_realm);

            case MAX_TYPE:
                break;
        }
    }

    if ([[maybe_unused]] const auto * always_allow_credentials = dynamic_cast<const AlwaysAllowCredentials *>(&credentials))
        return true;

    throw Exception("areCredentialsValid(): authentication type " + toString(type) + " not supported", ErrorCodes::NOT_IMPLEMENTED);
}
```
