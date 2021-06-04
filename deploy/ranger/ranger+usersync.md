# Apache Ranger Usersync

Ranger User Sync进程支持从以下来源读取用户/组信息：

- Unix
- LDAP/AD
- csv或者json格式文件

## 配置及启动

install.properties配置：

```
# The base path for the usersync process
ranger_base_dir = /etc/ranger
#
# The following URL should be the base URL for connecting to the policy manager web application
# For example:
#
#  POLICY_MGR_URL = http://policymanager.xasecure.net:6080
#
POLICY_MGR_URL = http://30.23.4.117:6080

# sync source,  only unix and ldap are supported at present
# defaults to unix
# 默认同步来源unix
SYNC_SOURCE = unix

#
# Minimum Unix User-id to start SYNC.
# This should avoid creating UNIX system-level users in the Policy Manager
# /etc/passwd文件格式：
# 用户名:密码:UID:GID:用户信息:HOME目录路径:用户shell
# 其中UID为0则是用户root，1～499为系统用户，500以上为普通用户
# 避免在策略管理中生成UNIX系统用户
MIN_UNIX_USER_ID_TO_SYNC = 500

# Minimum Unix Group-id to start SYNC.
# This should avoid creating UNIX system-level users in the Policy Manager
#
MIN_UNIX_GROUP_ID_TO_SYNC = 500

# sync interval in minutes
# user, groups would be synced again at the end of each sync interval
# defaults to 5   if SYNC_SOURCE is unix 默认每隔5分钟
# defaults to 360 if SYNC_SOURCE is ldap
SYNC_INTERVAL =

#User and group for the usersync process
unix_user=ranger
unix_group=ranger

#change password of rangerusersync user. Please note that this password should be as per rangerusersync user in ranger
rangerUsersync_password=2021root

#Set to run in kerberos environment
# 与kerberos验证对接有关
usersync_principal=
usersync_keytab=
hadoop_conf=/etc/hadoop/conf
#
# The file where all credential is kept in cryptic format
#
CRED_KEYSTORE_FILENAME=/etc/ranger/usersync/conf/rangerusersync.jceks

# SSL Authentication
AUTH_SSL_ENABLED=false
AUTH_SSL_KEYSTORE_FILE=/etc/ranger/usersync/conf/cert/unixauthservice.jks
AUTH_SSL_KEYSTORE_PASSWORD=UnIx529p
AUTH_SSL_TRUSTSTORE_FILE=
AUTH_SSL_TRUSTSTORE_PASSWORD=

# ---------------------------------------------------------------
# The following properties are relevant only if SYNC_SOURCE = ldap
# ---------------------------------------------------------------

# The below properties ROLE_ASSIGNMENT_LIST_DELIMITER, USERS_GROUPS_ASSIGNMENT_LIST_DELIMITER, USERNAME_GROUPNAME_ASSIGNMENT_LIST_DELIMITER,
#and GROUP_BASED_ROLE_ASSIGNMENT_RULES can be used to assign role to LDAP synced users and groups
#NOTE all the delimiters should have different values and the delimiters should not contain characters that are allowed in userName or GroupName

# default value ROLE_ASSIGNMENT_LIST_DELIMITER = &
ROLE_ASSIGNMENT_LIST_DELIMITER = &

#default value USERS_GROUPS_ASSIGNMENT_LIST_DELIMITER = :
USERS_GROUPS_ASSIGNMENT_LIST_DELIMITER = :

#default value USERNAME_GROUPNAME_ASSIGNMENT_LIST_DELIMITER = ,
USERNAME_GROUPNAME_ASSIGNMENT_LIST_DELIMITER = ,

# with above mentioned delimiters a sample value would be ROLE_SYS_ADMIN:u:userName1,userName2&ROLE_SYS_ADMIN:g:groupName1,groupName2&ROLE_KEY_ADMIN:u:userName&ROLE_KEY_ADMIN:g:groupName&ROLE_USER:u:userName3,userName4&ROLE_USER:g:groupName3
#&ROLE_ADMIN_AUDITOR:u:userName&ROLE_KEY_ADMIN_AUDITOR:u:userName&ROLE_KEY_ADMIN_AUDITOR:g:groupName&ROLE_ADMIN_AUDITOR:g:groupName
GROUP_BASED_ROLE_ASSIGNMENT_RULES =

# URL of source ldap 
# a sample value would be:  ldap://ldap.example.com:389
# Must specify a value if SYNC_SOURCE is ldap
SYNC_LDAP_URL = 

# ldap bind dn used to connect to ldap and query for users and groups
# a sample value would be cn=admin,ou=users,dc=hadoop,dc=apache,dc=org
# Must specify a value if SYNC_SOURCE is ldap
SYNC_LDAP_BIND_DN = 

# ldap bind password for the bind dn specified above
# please ensure read access to this file  is limited to root, to protect the password
# Must specify a value if SYNC_SOURCE is ldap
# unless anonymous search is allowed by the directory on users and group
SYNC_LDAP_BIND_PASSWORD = 

# ldap delta sync flag used to periodically sync users and groups based on the updates in the server
# please customize the value to suit your deployment
# default value is set to true when is SYNC_SOURCE is ldap
SYNC_LDAP_DELTASYNC = 

# search base for users and groups
# sample value would be dc=hadoop,dc=apache,dc=org
SYNC_LDAP_SEARCH_BASE = 

# search base for users
# sample value would be ou=users,dc=hadoop,dc=apache,dc=org
# overrides value specified in SYNC_LDAP_SEARCH_BASE
SYNC_LDAP_USER_SEARCH_BASE = 

# search scope for the users, only base, one and sub are supported values
# please customize the value to suit your deployment
# default value: sub
SYNC_LDAP_USER_SEARCH_SCOPE = sub

# objectclass to identify user entries
# please customize the value to suit your deployment
# default value: person
SYNC_LDAP_USER_OBJECT_CLASS = person

# optional additional filter constraining the users selected for syncing
# a sample value would be (dept=eng)
# please customize the value to suit your deployment
# default value is empty
SYNC_LDAP_USER_SEARCH_FILTER =

# attribute from user entry that would be treated as user name
# please customize the value to suit your deployment
# default value: cn
SYNC_LDAP_USER_NAME_ATTRIBUTE = cn

# attribute from user entry whose values would be treated as 
# group values to be pushed into Policy Manager database
# You could provide multiple attribute names separated by comma
# default value: memberof, ismemberof
SYNC_LDAP_USER_GROUP_NAME_ATTRIBUTE = memberof,ismemberof
#
# UserSync - Case Conversion Flags
# possible values:  none, lower, upper
SYNC_LDAP_USERNAME_CASE_CONVERSION=lower
SYNC_LDAP_GROUPNAME_CASE_CONVERSION=lower

#user sync log path
logdir=logs
#/var/log/ranger/usersync

# PID DIR PATH
USERSYNC_PID_DIR_PATH=/var/run/ranger

# do we want to do ldapsearch to find groups instead of relying on user entry attributes
# valid values: true, false
# any value other than true would be treated as false
# default value: false
SYNC_GROUP_SEARCH_ENABLED=

# do we want to do ldapsearch to find groups instead of relying on user entry attributes and
# sync memberships of those groups
# valid values: true, false
# any value other than true would be treated as false
# default value: false
SYNC_GROUP_USER_MAP_SYNC_ENABLED=

# search base for groups
# sample value would be ou=groups,dc=hadoop,dc=apache,dc=org
# overrides value specified in SYNC_LDAP_SEARCH_BASE,  SYNC_LDAP_USER_SEARCH_BASE
# if a value is not specified, takes the value of  SYNC_LDAP_SEARCH_BASE
# if  SYNC_LDAP_SEARCH_BASE is also not specified, takes the value of SYNC_LDAP_USER_SEARCH_BASE
SYNC_GROUP_SEARCH_BASE=

# search scope for the groups, only base, one and sub are supported values
# please customize the value to suit your deployment
# default value: sub
SYNC_GROUP_SEARCH_SCOPE=

# objectclass to identify group entries
# please customize the value to suit your deployment
# default value: groupofnames
SYNC_GROUP_OBJECT_CLASS=

# optional additional filter constraining the groups selected for syncing
# a sample value would be (dept=eng)
# please customize the value to suit your deployment
# default value is empty
SYNC_LDAP_GROUP_SEARCH_FILTER=

# attribute from group entry that would be treated as group name
# please customize the value to suit your deployment
# default value: cn
SYNC_GROUP_NAME_ATTRIBUTE=

# attribute from group entry that is list of members
# please customize the value to suit your deployment
# default value: member
SYNC_GROUP_MEMBER_ATTRIBUTE_NAME=

# do we want to use paged results control during ldapsearch for user entries
# valid values: true, false
# any value other than true would be treated as false
# default value: true
# if the value is false, typical AD would not return more than 1000 entries
SYNC_PAGED_RESULTS_ENABLED=

# page size for paged results control
# search results would be returned page by page with the specified number of entries per page
# default value: 500
SYNC_PAGED_RESULTS_SIZE=
#LDAP context referral could be ignore or follow
SYNC_LDAP_REFERRAL =ignore

# if you want to enable or disable jvm metrics for usersync process
# valid values: true, false
# any value other than true would be treated as false
# default value: false
# if the value is false, jvm metrics is not created
JVM_METRICS_ENABLED=

# filename of jvm metrics created for usersync process
# default value: ranger_usersync_metric.json
JVM_METRICS_FILENAME=

#file directory for jvm metrics
# default value : logdir
JVM_METRICS_FILEPATH=

#frequency for jvm metrics to be updated
# default value : 10000 milliseconds 
JVM_METRICS_FREQUENCY_TIME_IN_MILLIS=
```

用root执行：

```
# ./setup.sh
# ranger-usersync start  // 或./ranger-usersync-services.sh start
```

## 验证usersync与unix同步功能

### 造成不能同步可能的主要原因及解决方法：

1.rangerusersync和ranger数据库中所存的rangerusersync用户的密码不一致，导致java进程登陆rangerusersync用户失败，修改后可能需要再同步

- 解决方法：

在ranger-2.1.0-usersync文件夹路径下跑策略管理用户同步管理员用户名/密码更新代码：

```
python updatepolicymgrpassword.py
```

设置在配置文件设定的密码，然后重启ranger-usersync模块，在审计页面login session下可以查看到userAgeent为JAVA的ranger-usersync用户登陆成功

2.ranger-usersync开关没打开

- 解决方法：

修改/etc/ranger/usersync/conf/ranger-ugsync-site.xml中ranger.usersync.enabled的值为true，然后重启ranger-usersync，可以查看到审计页面下User Sync的日志同步信息，查看设置页面出现所有unix普通用户的信息

### 查看unix同步信息

首先，查看unix普通用户（uid >= 500）的用户列表：

```shell
cat /etc/passwd
cat /etc/group
```

然后点击Ranger-admin的web页面的tab：Settings -> Users/Groups/Roles -> Users/Groups/Roles:

一看果然那些unix普通用户都在这里

## 验证usersync与ldap同步功能

### 参考
1. https://www.cnblogs.com/daiss314/p/13227180.html
2. ldap存储规则：https://www.cnblogs.com/daiss314/p/13227486.html

### ldap服务器安装及配置

```shell
yum install -y openldap openldap-clients openldap-servers migrationtools
```

最后显示安装类似：

```
Installed:
  migrationtools.noarch 0:47-15.el7  openldap-clients.x86-64 0:2.4.44-23.el7_9  openldap-servers.x86_64 0:2.4.44-23.el7_9
```

代表安装成功！然后配置ldap的域和密码

```shell
vim /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif
```

配置类似：

```shell
# AUTO-GENERATED FILE - DO NOT EDIT!! Use Ldapmodify.
# CRC32 9f29ca96
dn: olcDatabase={2}hdb
objectClass: olcDatabaseConfig
objectClass: olcHdbConfig
olcDatabase: {2}hdb
olcDbDirectory: /var/lib/ldap
olcSuffix: dc=openldap, dc=com
olcRootDN: cn=root, dc=openldap, dc=com
olcRootPW:   admin@123
olcDbIndex: objectClass eq,pres
olcDbIndex: ou,cn,mail,surname,givenname eq,pres,sub
structuralObjectClass: olcHdbConfig
entryUUID: 5b3256fe-52d5-103b-85d6-65167b31e9a0
creatorsName: cn=config
createTimestamp: 20210527011941Z
entryCSN: 20210527011941.246608Z#000000#000#000000
modifersName: cn=config
modifyTimestamp: 20210527011941Z
```

配置监视数据库配置文件

```shell
vim /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{1\}monitor.ldif
```
修改dn.base里面的dc和cn，修改成与服务器配置一样的域:

```shell
dn: olcDatabase={1}monitor
objectClass: olcDatabaseConfig
olcDatabase: {1}monitor
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=extern
al, cn=auth" read by dn.base="cn=root,dc=openldap,dc=com" read by * none
structuralObjectClass: olcDatabaseConfig
entryUUID: 5b3256fe-52d5-103b-85d6-65167b31e9a0
creatorsName: cn=config
createTimestamp: 20210527011941Z
entryCSN: 20210527011941.246472Z#000000#000#000000
modifersName: cn=config
modifyTimestamp: 20210527011941Z
```

接着，准备LDAP数据库，先将/usr/share/openldap-servers/DB_CONFIG.example的文件复制到/var/lib/ldap/DB_CONFIG目录下，并给文件授ldap权限：

```shell
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown -R ldap.ldap /var/lib/ldap
```

测试配置验证:

```shell
slaptest -u
```

输入命令出现succeeded表示验证成功!

#### 启动服务，并设置开机自启动

```shell
systemctl start slapd
systemctl enable slapd
```

显示创建软链接

```
Created symlink from /etc/systemd/system/multi-user.target.wants/slapd.service to /usr/lib/systemd/system/slapd/service.
```

查看ldap及端口：

```shell
netstat -lt | grep ldap
netstat -tunlp | egrep "389|636"
```

#### 要启动LDAP服务器的配置，请添加以下LDAP模式:
##### !!!务必在以下路径执行👇👇的命令

```shell
cd /etc/openldap/schema/
```

```shell
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f collective.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f corba.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f core.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f duaconf.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f dyngroup.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f inetorgperson.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f java.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f misc.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f openldap.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f pmi.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f ppolicy.ldif
```

#### 使用迁移工具创建LDAP DIT

```shell
vim /usr/share/migrationtools/migrate_common.ph 修改migrate_common.ph文件
```

修改61行  $NAMINGCONTEXT{'group'} = "ou=Groups";

修改71行   $DEFAULT_MAIL_DOMAIN = "openldap.com";

修改74行  $DEFAULT_BASE = "dc=openldap,dc=com";

修改90行  $EXTENDED_SCHEMA = 1;


#### 负载基地到LDAP数据库中

生成一个基地，ldif文件为您的域DIT:

```shell
cd /usr/share/migrationtools
./migrate_base.pl > /root/base.ldif
```

接着，执行：

```shell
ldapadd -x -W -D "cn=root,dc=openldap,dc=com" -f /root/base.ldif
```

执行结果类似：

```shell
Enter LDAP Password: admin@123
adding new entry "dc=openldap,dc=com"

adding new entry "ou=Hosts,dc=openldap,dc=com"

adding new entry "ou=Rpc,dc=openldap,dc=com"

adding new entry "ou=Services,dc=openldap,dc=com"

adding new entry "nisMapName=netgroup.byuser,dc=openldap,dc=com"

adding new entry "ou=Mounts,dc=openldap,dc=com"

adding new entry "ou=Networks,dc=openldap,dc=com"

adding new entry "ou=People,dc=openldap,dc=com"
```

#### ldap用户（组）创建

先执行如下命令：

```shell
mkdir /home/guests
useradd -d /home/guests/test12 test12
useradd -d /home/guests/test123 test123
echo 'csdn!123' | passwd --stdin test12
echo 'csdn!123' | passwd --stdin test123
```

过滤掉这些用户和组以及从/etc/shadow到不同文件的密码:

```shell
getent passwd | tail -n 5 > /root/users
getent shadow | tail -n 5 > /root/shadow
getent group | tail -n 5 > /root/groups
```

需要使用migrationtools为这些用户创建ldif文件:

```shell
cd /usr/share/migrationtools
vim migrate_passwd.pl
```

修改188行，把/etc/shadow换成/root/shadow; 再执行：

```shell
./migrate_passwd.pl /root/users > users.ldif
./migrate_group.pl /root/groups > groups.ldif
```

将这些用户和组ldif文件上传到LDAP数据库中:

```shell
ldapadd -x -W -D "cn=root,dc=openldap,dc=com" -f users.ldif
ldapadd -x -W -D "cn=root,dc=openldap,dc=com" -f groups.ldif
```

现在搜索LDAP DIT的所有记录（如果能搜索到就说明安装成功了，至此ldap服务器安装完成（按这个安装只支持uid用户的登录））:

```shell
ldapdearch -x -b "dc=openldap,dc=com" -H ldap://30.23.4.117:389
```

## 代码解析

上层抽象构建：

* **UserGroupSource**: 定义用户组来源
   * **AbstractUserGroupSource implements UserGroupSource**:
       * **LdapDeltaUserGroupBuilder extends AbstractUserGroupSource**:
       * **LdapUserGroupBuilder extends AbstractUserGroupSource**:
       * **FileSourceUserGroupBuilder extends AbstractUserGroupSource**:
   * **UnixUserGroupBuilder implements UserGroupSource**: 直接通过命令行读取用户/组信息
   ```java
    private void buildUserGroupInfo() throws Throwable {
		user2GroupListMap = new HashMap<String,List<String>>();
		groupId2groupNameMap = new HashMap<String, String>();
		internalUser2GroupListMap = new HashMap<String,List<String>>();
		allGroups = new HashSet<>();
        
        // 根据不同os读取组及用户信息
		if (OS.startsWith("Mac")) {
			buildUnixGroupList(MAC_GET_ALL_GROUPS_CMD, MAC_GET_GROUP_CMD, false);
			buildUnixUserList(MAC_GET_ALL_USERS_CMD);
		} else {
			if (!OS.startsWith("Linux")) {
				LOG.warn("Platform not recognized assuming Linux compatible");
			}
			buildUnixGroupList(LINUX_GET_ALL_GROUPS_CMD, LINUX_GET_GROUP_CMD, true);
			buildUnixUserList(LINUX_GET_ALL_USERS_CMD);
		}

		lastUpdateTime = System.currentTimeMillis();

		if (LOG.isDebugEnabled()) {
			print();
		}
	}
   ```

* **UserGroupSink**: 定义用户组出处
   * **LdapPolicyMgrUserGroupBuilder extends UserGroupSink**:
   * **PolicyMgrUserGroupBuilder extends UserGroupSink**:
   ```java
    synchronized public void init() throws Throwable {
		xgroupList = new ArrayList<XGroupInfo>();
		xuserList = new ArrayList<XUserInfo>();
		xusergroupList = new ArrayList<XUserGroupInfo>();
		userId2XUserInfoMap = new HashMap<String,XUserInfo>();
		userName2XUserInfoMap = new HashMap<String,XUserInfo>();
		groupName2XGroupInfoMap = new HashMap<String,XGroupInfo>();
		userMap = new LinkedHashMap<String, String>();
		groupMap = new LinkedHashMap<String, String>();
		recordsToPullPerCall = config.getMaxRecordsPerAPICall();
		policyMgrBaseUrl = config.getPolicyManagerBaseURL();
		isMockRun = config.isMockRunEnabled();
		noOfNewUsers = 0;
		noOfModifiedUsers = 0;
		noOfNewGroups = 0;
		noOfModifiedGroups = 0;
		isStartupFlag = true;
		isRangerCookieEnabled = config.isUserSyncRangerCookieEnabled();
		if (isMockRun) {
			LOG.setLevel(Level.DEBUG);
		}
		sessionId=null;
		String keyStoreFile =  config.getSSLKeyStorePath();
		String trustStoreFile = config.getSSLTrustStorePath();
		String keyStoreFilepwd = config.getSSLKeyStorePathPassword();
		String trustStoreFilepwd = config.getSSLTrustStorePathPassword();
		String keyStoreType = KeyStore.getDefaultType();
		String trustStoreType = KeyStore.getDefaultType();
		authenticationType = config.getProperty(AUTHENTICATION_TYPE,"simple");
		try {
			principal = SecureClientLogin.getPrincipal(config.getProperty(PRINCIPAL,""), LOCAL_HOSTNAME);
		} catch (IOException ignored) {
			 // do nothing
		}
		keytab = config.getProperty(KEYTAB,"");
		nameRules = config.getProperty(NAME_RULE,"DEFAULT");
		uGSyncClient = new RangerUgSyncRESTClient(policyMgrBaseUrl, keyStoreFile, keyStoreFilepwd, keyStoreType,
				trustStoreFile, trustStoreFilepwd, trustStoreType, authenticationType, principal, keytab,
				config.getPolicyMgrUserName(), config.getPolicyMgrPassword());

        String userGroupRoles = config.getGroupRoleRules();
        if (userGroupRoles != null && !userGroupRoles.isEmpty()) {
            getRoleForUserGroups(userGroupRoles);
        }
		buildUserGroupInfo() throws Throwable {
		  if(authenticationType != null && AUTH_KERBEROS.equalsIgnoreCase(authenticationType) && SecureClientLogin.isKerberosCredentialExists(principal, keytab)){
			if(LOG.isDebugEnabled()) {
				LOG.debug("==> Kerberos Environment : Principal is " + principal + " and Keytab is " + keytab);
			}
		}
		  if (authenticationType != null && AUTH_KERBEROS.equalsIgnoreCase(authenticationType) && SecureClientLogin.isKerberosCredentialExists(principal, keytab)) {
			try {
				LOG.info("Using principal = " + principal + " and keytab = " + keytab);
				Subject sub = SecureClientLogin.loginUserFromKeytab(principal, keytab, nameRules);
				Subject.doAs(sub, new PrivilegedAction<Void>() {
					@Override
					public Void run() {
						try {
                            // 建一个新的组列表
							buildGroupList();
                            // 建一个新的用户列表
							buildUserList();
                            // 建一个新的用户组关系列表
							buildUserGroupLinkList();
                            // 重构用户组对应关系
							rebuildUserGroupMap();
						} catch (Exception e) {
							LOG.error("Failed to build Group List : ", e);
						}
						return null;
					}
				});
			} catch (Exception e) {
				LOG.error("Failed to Authenticate Using given Principal and Keytab : ",e);
			}
		  } else {
			buildGroupList();
			buildUserList();
			buildUserGroupLinkList();
			rebuildUserGroupMap();
            if (LOG.isDebugEnabled()) {
				this.print();
			}
		}
	}
		if (LOG.isDebugEnabled()) {
			LOG.debug("PolicyMgrUserGroupBuilder.init()==> PolMgrBaseUrl : "+policyMgrBaseUrl+" KeyStore File : "+keyStoreFile+" TrustStore File : "+trustStoreFile+ "Authentication Type : "+authenticationType);
		}
	}
   ```