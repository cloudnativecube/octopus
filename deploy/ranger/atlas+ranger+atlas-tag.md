### Atlas Plugin

将ranger的atlas插件服务部署到配置atlas服务的节点上

```
tar zxvf ranger-2.1.0-atlas-plugin.tar.gz
cd ranger-2.1.0-atlas-plugin
```

修改install.properties中相关配置

```
POLICY_MGR_URL=http://30.23.4.117:6080
REPOSITORY_NAME=atlasdev
COMPONENT_INSTALL_DIR_NAME=/data/servers/atlas-2.1.0

# Enalbe audit logs to Solr
XAAUDIT.SOLR.ENABLE=true
XAAUDIT.SOLR.URL=http://30.23.4.69/solr/ranger_audits
XAAUDIT.SOLR.USER=NONE
XAAUDIT.SOLR.PASSWORD=NONE
XAAUDIT.SOLR.ZOOKEEPER=master:2181,slave01:2181,slave02:2181/solr
XAAUDIT.SOLR.SOLR_URL=http://30.23.4.69:8984/solr/ranger_audits

# You do not need use SSL between agent and security admin tool, please leave these sample value as it is.
#
SSL_KEYSTORE_FILE_PATH=/etc/atlas/conf/ranger-plugin-keystore.jks
SSL_KEYSTORE_PASSWORD=myKeyFilePassword
SSL_TRUSTSTORE_FILE_PATH=/etc/atlas/conf/ranger-plugin-truststore.jks
SSL_TRUSTSTORE_PASSWORD=changeit

#
# Custom component user
# CUSTOM_COMPONENT_USER=<custom-user>
# keep blank if component user is default
CUSTOM_USER=


#
# Custom component group
# CUSTOM_COMPONENT_GROUP=<custom-group>
# keep blank if component group is default
CUSTOM_GROUP=
```

然后用root执行：

```shell
./enable-atlas-plugin.sh
// 省略中间输出
Ranger Plugin for atlas has been enabled. Please restart hadoop to ensure that changes are effective.
```

这时候打开atlas的配置：

```
cat /data/servers/atlas-2.1.0/conf/atlas-application.properties | grep -v '#' | grep -v ^$
```

你会看到新增了两条关于ranger的配置:

```
#### Altas Authorization ####
atlas.authorizer.impl=org.apache.ranger.authorization.atlas.authorizer.RangerAtlasAuthorizer
atlas.authorizer.simple.authz.policy.file=atlas-simple-authz-policy.json
```

重启atlas服务：

```
cd /data/servers/atlas-2.1.0/bin
python atlas_stop.py
python atlas_start.py
```

很可能会因为缺包，启动失败，这时候查看相关日志

```
less /data/servers/atlas-2.1.0/logs/application.log
```

shift+G翻到末尾，往上翻一翻，然后把相应缺失的jar包放到/data/servers/atlas-2.1.0/libext/目录下，如果配置到抓狂😫，那就全放进去，scp或cp ranger-admin/ews/webapp/WEB-INF/lib/* 到上面的目录下，总有一款适合你。如果这个操作觉得不够美，那就慢慢来，之后哪怕atlas服务能重启成功，连接上也可能会出错，要结合ranger-admin的log同时看，多看日志，豁然开朗！

启动成功后，打开admin web UI，进入AccessManager => ServiceManager => 选择Atlas点击"+" Create Service，配置相关信息

```
Service Name = atlasdev

#居然可以套娃😂
Select Tag Service=atlas_tag

Username = 这里随意，不重要
Password = 按照你先前配置的来
atlas.rest.address=http://30.23.5.180:21000
```

然后点一下Test Connection，显示"Connected Successfully"，居然可以连！欢呼三秒钟🎉

然后保存，就行了，点击Audit=>Plugins，可以看到你部署好的atlas服务在这里冒泡，然后点击Plugin Status，可以看到这个插件已然成为了ranger的常任理事。

#### 简单验证

点击atlasdev可以看到ranger已经帮你同步好了atlas用户的7个策略，其中有个策略名字叫"all-entity-type, entity-classification, entity"，点击右边👉的小眼睛👀查看策略细则，可以看到在"Allow Condition"下"rangertagsync"只允许"entity-read"而不能操作👇其他操作：

```
entity-create
entity-update
entity-delete
entity-add-classification
entity-update-classification
entity-remove-classification
```

来，这会儿我们饶有兴趣地验证一下是不是真的那么神，打开Atlas web UI: 30.23.5.180:21000，登陆输入

```
# 除非当初配置有特意修改，否则atlas用户rangertagsync默认密码和用户名相同
用户名：rangertagsync
密码：rangertagsync
```

随便选个entity或者以防万一，无关紧要的entity，给它打标签🏷️（classfication上加一个tag），选择任意标签，点击add，这时候可以看到右上角红色弹窗显示类似警告⚠️：

```
rangertagsync is not authorized to perform add classification: guid=a1d138bc-acee-4c83-8a8e-cc67dad47878,classification=ETL
```

同理，验证删除实体标签，点击🏷️classification出现有各种标签的页面，点击其中一个标签比如"ETL"出现所有相关实体，在实体一览旁边点击相应的标签的"x"号，弹框点击"Remove"，右上角红色弹窗显示类似警告⚠️：

```
rangertagsync is not authorized to perform remove classification: guid=a1d138bc-acee-4c83-8a8e-cc67dad47878,classification=ETL
```

这时候来一波反向验证, 前往上面👆ranger的策略一览，修改策略"all-entity-type, entity-classification, entity"，点击Action下✏️修改，给rangertagsync加上"Add Classification"的权限，点击保存。

迫不及待地到atlas web ui，随便点击一个entity贴标签，看到加载标志等待一会儿，右上角随即绿色弹唱显示：

```
Classifiction ETL has been added to entity
```

反复横箱跳跃一波，回到前面的policy，给rangertagsync加上"Remove Classification"的权限，同时把"Add Classification"的权限删了，返回🔙还开着的atlas页面，相应标签点击删除，加载一会儿，可以看到绿色弹窗删除成功，然后加上标签发现不成功。

点击看ranger admin web UI中的Audit => plugins, 可以看到策略同步的信息，HTTP Response code显示200。

基本功能验证完毕！

### Atlas Tag

打开admin web UI，进入Access Manager => Tag Based Policies => 选择Tag服务点击"+" Create Service，

啥都不用配，好耶！😂，填一下服务名称就行了

```
Service Name=atlas_tag
```

测试连接，保存，然后就可以畅玩atlas_tag的policy配置了

### Atlas-tag操作验证指南

操作详情参考：[Apache Ranger基于Apache Atlas标签的策略](https://blog.csdn.net/wangpei1949/article/details/88048355?utm_medium=distribute.pc_relevant_download.none-task-blog-2~default~BlogCommendFromBaidu~default-1.nonecase&depth_1-utm_source=distribute.pc_relevant_download.none-task-blog-2~default~BlogCommendFromBaidu~default-1.nonecas)