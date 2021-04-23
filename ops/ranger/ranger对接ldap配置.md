### 配置
cd /home/servers/ranger-2.0.0/ranger-2.0.0-usersync  
vim install.properties  
```
SYNC_LDAP_URL = ldap://10.0.0.11:389
SYNC_LDAP_BIND_DN = cn=root,dc=openldap,dc=com
SYNC_LDAP_BIND_PASSWORD = admin@123
SYNC_LDAP_USER_SEARCH_BASE = dc=openldap,dc=com
SYNC_LDAP_USER_SEARCH_SCOPE = sub
SYNC_LDAP_USER_OBJECT_CLASS = person
SYNC_LDAP_USER_NAME_ATTRIBUTE = cn
```
#### 生成配置文件
bash setup.sh  
#### 开启同步
 vim conf/ranger-ugsync-site.xml  
 ```
         <property>
                <name>ranger.usersync.enabled</name>
                <value>true</value>
        </property
 ```
 #### 重启生效配置
 ./ranger-usersync-services.sh stop
 ./ranger-usersync-services.sh start
 
 #### 检查
 tail -f /home/servers/ranger-2.0.0/ranger-2.0.0-usersync/logs/usersync-centos01-root.log
 ```
 23 四月 2021 14:17:16  INFO UserGroupSync [UnixUserSyncThread] - Begin: initial load of user/group from source==>sink
23 四月 2021 14:17:16  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - LdapDeltaUserGroupBuilder updateSink started
23 四月 2021 14:17:16  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Performing user search first
23 四月 2021 14:17:16  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - extendedUserSearchFilter = (&(objectclass=person)(|(uSNChanged>=0)(modifyTimestamp>=19700101080000Z)))
23 四月 2021 14:17:16  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210416101927Zand currentDeltaSyncTime = 1618539567000
23 四月 2021 14:17:16  INFO LdapPolicyMgrUserGroupBuilder [UnixUserSyncThread] - valid cookie saved
23 四月 2021 14:17:16  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 1, userName: user8
23 四月 2021 14:17:16  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210419090657Zand currentDeltaSyncTime = 1618794417000
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 2, userName: user9
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210419091129Zand currentDeltaSyncTime = 1618794689000
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 3, userName: user10
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210419092253Zand currentDeltaSyncTime = 1618795373000
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 4, userName: user11
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210419092929Zand currentDeltaSyncTime = 1618795769000
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 5, userName: user12
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210419094600Zand currentDeltaSyncTime = 1618796760000
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 6, userName: user13
23 四月 2021 14:17:17  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210420033232Zand currentDeltaSyncTime = 1618860752000
23 四月 2021 14:17:18  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 7, userName: user14
23 四月 2021 14:17:18  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210420073931Zand currentDeltaSyncTime = 1618875571000
23 四月 2021 14:17:18  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 8, userName: user15
23 四月 2021 14:17:18  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - timeStampVal = 20210420113049Zand currentDeltaSyncTime = 1618889449000
23 四月 2021 14:17:18  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - Updating user count: 9, userName: user17
23 四月 2021 14:17:18  INFO LdapDeltaUserGroupBuilder [UnixUserSyncThread] - LdapDeltaUserGroupBuilder.getUsers() completed with user count: 9
23 四月 2021 14:17:18  INFO UserGroupSync [UnixUserSyncThread] - End: initial load of user/group from source==>sink
23 四月 2021 14:17:18  INFO UserGroupSync [UnixUserSyncThread] - Done initializing user/group source and sink
23 四月 2021 14:17:20  INFO UnixAuthenticationService [main] - Enabling Unix Auth Service!
23 四月 2021 14:17:20  INFO UnixAuthenticationService [main] - Enabling Protocol: [SSLv2Hello]
23 四月 2021 14:17:20  INFO UnixAuthenticationService [main] - Enabling Protocol: [TLSv1]
23 四月 2021 14:17:20  INFO UnixAuthenticationService [main] - Enabling Protocol: [TLSv1.1]
23 四月 2021 14:17:20  INFO UnixAuthenticationService [main] - Enabling Protocol: [TLSv1.2]
 ```
 
### 问题
1. 定时同步间隔时间不能小于1小时，代码写死了
2. 用户组同步还没有测试
