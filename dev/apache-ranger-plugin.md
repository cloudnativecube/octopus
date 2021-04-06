# Apache Ranger Plugin

## 背景

Hadoop生态王朝群雄割据，各自为政，HDFS、HBASE、HIVE、YARN、KAFKA、STORM等各诸侯为抵御外患，各自修筑ACL(Access Control List)长城，零零散散，不堪重负，为大一统长城修筑工作，天子号召天下，招贤纳士，Apache Sentry、Apache Ranger从Cloudera、Hortonworks等地上朝进言，从朝都构建中央访问控制领域辐射各诸侯领地，连接并统领各地长城修筑...

以下简要介绍Apache Ranger贤士的修筑方案，特点如下：

- 基于策略(Policy-based)的访问权限模型

- 通用的策略同步与决策逻辑，方便控制插件的扩展接入

- 内置常见系统(如HDFS、YARN、HBase等12个)的控制插件，且可扩展；支持和kerberose的集成

- 内置基于LDAP、File、Unix的用户同步机制，且可扩展

- 提供了REST接口供二次开发

- 统一的中心化的管理界面，包括策略管理、审计查看、插件管理等

## 架构

![ranger-plugin-structure](https://img-blog.csdnimg.cn/20190515231350591.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxNDc1NzgxNjM4,size_16,color_FFFFFF,t_70)

简图：

![simple-ranger-plugin-structure](https://raw.githubusercontent.com/tragicjun/tragicjun.github.io/master/images/RangerArchitecture.png)


详细版：

![complex-ranger-plugin-structure](https://upload-images.jianshu.io/upload_images/11810589-11d157801079c42f.png?imageMogr2/auto-orient/strip|imageView2/2/w/960)

### 组件职能

- RangerAdmin: 以RESTFUL形式提供策略的增删改接口，同时内置一个Web管理页面；Ranger Admin Portal是安全管理的中心接口。 用户可以创建和更新策略，这些策略存储在策略数据库中。 每个组件内的Plugins会定期轮询这些策略。Portal还包括一个审计服务器，它发送从插件收集的审计数据，以便存储在HDFS或关系数据库中。


- AgentPlugin：插件是嵌入每个集群组件进程的轻量级Java程序。 例如，Apache Hive的Apache Ranger插件嵌入在Hiveserver2中。 这些插件从中央服务器提取策略，并将它们本地存储在一个文件中。 当用户请求通过组件时，这些插件拦截请求并根据安全策略进行评估。 插件还可以从用户请求中收集数据，并按照单独的线程将此数据发送回审计服务器。


- UserSync: 定期从LDAP/Unix/File中加载用户，上报给RangerAdmin

三者关系图：

![admin-agentPlugin-usersync](https://img-blog.csdnimg.cn/2020060220510932.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3RvdG8xMjk3NDg4NTA0,size_16,color_FFFFFF,t_70)

#### 其他组件：

- KMS: Hadoop透明加密，Hadoop Key Management Server（KMS）是一个基于HadoopKeyProvider API编写的密钥管理服务器。RangerKMS就是对KMS的策略管理和秘钥管理，使用keyadmin用户登陆。


- TAG: 基于标签的权限管理，当一个用户的请求涉及到多个应用系统中的多个资源的权限时，可以通过只配置这些资源的tag方便快速的授权。


### 权限模型

#### 概念

- user: Ranger自己管理的用户，分为internal和external，前者为Ranger自己的用户，例如admin；后者为linux或者LDAP的用户，在操作系统/LDAP里新增用户后会同步到Ranger。


- group: Ranger自己管理的用户组，也有内外之分，与user类似，设置与LDAP(Lightweight Directory Access Protocol)同步后会将LDAP的组同步过来，该组为外部组；如果是Ranger自己的用户新增的组，则为internal组。


- Service: 即授权管理服务，每个组件可以设置多个Service。


- Policy: 每个Service中可以有多条Policy，组件不同，Policy授权模型不同


#### "用户-资源-权限"三位一体

访问权限无非是定义了”用户-资源-权限“这三者间的关系，Ranger基于策略来抽象这种关系，进而延伸出自己的权限模型。”用户-资源-权限”的含义详解：

- 用户：由User或Group来表达，User代表访问资源的用户，Group代表用户所属的用户组。


- 资源：由Resource来表达，不同的组件对应的业务资源是不一样的，比如HDFS的File Path，HBase的Table。


- 权限：由(AllowACL, DenyACL)来表达，类似白名单和黑名单机制，AllowACL用来描述允许访问的情况，DenyACL用来描述拒绝访问的情况。不同的组件对应的权限也是不一样的。


Ranger中的访问权限模型可以用下面的表达式来描述，从而抽象出了”用户-资源-权限“这三者间的关系：

```
Policy = Service + List<Resource> + AllowACL + DenyACL

AllowACL = List<AccessItem> allow + List<AccssItem> allowException

DenyACL = List<AccessItem> deny + List<AccssItem> denyException

AccessItem = List<User/Group> + List<AccessType>
```

插件初始化UML图类似于：

![hdfs-plugin-initialization-UML](https://images2015.cnblogs.com/blog/1003929/201704/1003929-20170427153839178-983185981.png)

初始化RangerPlugin，如上面的类图可知，RangerHdfsPlugin是RangerBasePlugin类的子类，其具体的初始化是由父类的初始化方法来实现的。该方法主要完成了以下几个功能：

（1）调用cleanup()方法,主要完成清空了refresher、serviceName、policyEngine这三个变量的值。

（2）读取配置文件，并设置以下变量的初始值。

- serviceType：Ranger提供访问控制服务的类型。


- serviceName：Ranger提供访问控制服务的名称。


- appId：由Ranger提供服务的组件ID。


- propertyPrefix：Ranger插件的属性前缀。


- pollingIntervalMs：刷新器定期更新策略的轮询间隔时间。Ranger 插件会定期从Ranger Admin拉取新的策略信息，并保存在Hdfs缓存中。


- cacheDir：从Ranger Admin拉取策略到Hdfs插件的临时存放目录。


（3）设置PangerPolicyEngineOptions类的成员变量值。

- evaluatorType:评估器的类型。在Ranger对Hdfs的访问权限的鉴权阶段需要策略评估器根据策略判断是否具有访问权限。


- cacheAuditResults：是否缓存审计。


- disableContextEnrichers：是否使用上下文增强器。


- disableCustomConditions：是否使用自定义条件。在Ranger0.5版本之后加入上下文增强器和用户自定义条件这样的“钩子”函数以增加授权策略的可扩展性。


- disableTagPolicyEvaluation：是否使用基于标签的策略评估。在Ranger0.6版本以后，Ranger不仅仅支持基于资源的策略，还支持基于标签的策略，该策略的优点是资源分类与访问授权的分离，标记的单个授权策略可用于授权跨各种Hadoop组件访问资源。


（4）调用createAdminClient()，创建RangerAdmin与RangerPlugin通信的客户端。这里使用的基于RESTful的通信风格，所以创建RangerAdminClient类的实例对象。

（5）创建PolicyRefresher类的对象，调用startRefresher()开启策略刷新器，根据轮询间隔时间定期从Ranger Admin 拉取更新的策略。



以下以hive-plugin为例:

![hive-plugin-logic](https://img-blog.csdnimg.cn/20200602210609555.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3RvdG8xMjk3NDg4NTA0,size_16,color_FFFFFF,t_70)

## ranger-hive-plugin实现

hiveserver2-site.xml:

```
<property>
    <name>hive.security.authorization.enabled</name>
    <value>true</value>
</property>
<property>
    <name>hive.security.authorization.manager</name>
<value>org.apache.ranger.authorization.hive.authorizer.RangerHiveAuthorizerFactory</value>
</property>

```

### 施工方案👷

#### 一. 定义服务类型(Service-Type)

1.新建一张JSON表包含以下服务：

 - 资源： database, table, column, UDF, URL
 
 - 获取类型：select, update, create, drop, alter, index, lock, write, read, all
 
 - 连接服务配置：JDBC URL, JDBC driver, credentials, etc.
 
摘自[官方示例](https://cwiki.apache.org/confluence/display/RANGER/Apache+Ranger+0.6+-+REST+APIs+for+Service+Definition%2C+Service+and+Policy+Management)：

```
{
	"id":3,
	"name": "hive",
	"implClass": "org.apache.ranger.services.hive.RangerServiceHive",
	"label": "Hive Server2",
	"description": "Hive Server2",
	"guid": "3e1afb5a-184a-4e82-9d9c-87a5cacc243c",
	"resources":
	[
		{
			"itemId": 1,
			"name": "database",
			"type": "string",
...
			"matcher": "org.apache.ranger.plugin.resourcematcher.RangerDefaultResourceMatcher",
			"matcherOptions": { "wildCard":true, "ignoreCase":true },
...
		},

		{
			"itemId": 2,
			"name": "table",
			"type": "string",
			"level": 20,
			"parent": "database",
...
        },

		{
			"itemId": 3,
			"name": "udf",
			"type": "string",
			"level": 20,
			"parent": "database",
...
		},

		{
			"itemId": 4,
			"name": "column",
			"type": "string",
			"level": 30,
			"parent": "table",
...
		}
	],

	"accessTypes":
	[
		{
			"itemId": 1,
			"name": "select",
			"label": "select"
		},

		{
			"itemId": 2,
			"name": "update",
			"label": "update"
		},

		{
			"itemId": 3,
			"name": "create",
			"label": "Create"
		},
...
		{
			"itemId": 8,
			"name": "all",
			"label": "All",
			"impliedGrants":
			[
				"select",
				"update",
				"create",
				"drop",
				"alter",
				"index",
				"lock"
			]
		}
	],

	"configs":
	[
		{
			"itemId": 1,
			"name": "username",
			"type": "string",
...
		},

		{
			"itemId": 2,
			"name": "password",
			"type": "password",
...
		},

		{
			"itemId": 3,
			"name": "jdbc.driverClassName",
...
			"defaultValue": "org.apache.hive.jdbc.HiveDriver"
		},

		{
			"itemId": 4,
			"name": "jdbc.url",
			"type": "string",
...
	}
}
```

2.载入JSON到Ranger

#### 二. Ranger权限插件梳理👷（以hive为例）

#### 启动hiveserver2服务时：

1.RangerHiveAuthorizerFactory直接在hive所提供的org.apache.hadoop.hive.ql.security.authorization.plugin.HiveAuthorizerFactory接口上施工：

```java
/**
   * Create a new instance of HiveAuthorizer, initialized with the given objects.
   * @param metastoreClientFactory - Use this to get the valid meta store client (IMetaStoreClient)
   *  for the current thread. Each invocation of method in HiveAuthorizer can happen in
   *  different thread, so get the current instance in each method invocation.
   * @param conf - current HiveConf
   * @param hiveAuthenticator - authenticator, provides user name
   * @param ctx - session context information
   * @return new instance of HiveAuthorizer
   * @throws HiveAuthzPluginException
   */
  HiveAuthorizer createHiveAuthorizer(HiveMetastoreClientFactory metastoreClientFactory,
      HiveConf conf, HiveAuthenticationProvider hiveAuthenticator, HiveAuthzSessionContext ctx)
      throws HiveAuthzPluginException {
    return new RangerHiveAuthorizer(metastoreClientFactory, conf, hiveAuthenticator, sessionContext) {
    
    super(metastoreClientFactory, hiveConf, hiveAuthenticator, sessionContext);

		LOG.debug("RangerHiveAuthorizer.RangerHiveAuthorizer()");

		RangerHivePlugin plugin = hivePlugin;
		
		if(plugin == null) {
			synchronized(RangerHiveAuthorizer.class) {
				plugin = hivePlugin;

				if(plugin == null) {
					String appType = "unknown";

					if(sessionContext != null) {
						switch(sessionContext.getClientType()) {
							case HIVECLI:
								appType = "hiveCLI";
							break;

							case HIVESERVER2:
								appType = "hiveServer2";
							break;

							/*
							case HIVEMETASTORE:
								appType = "hiveMetastore";
								break;

							case OTHER:
								appType = "other";
								break;

							 */
						}
					}

					plugin = new RangerHivePlugin(appType);
					plugin.init();

					hivePlugin = plugin; // 保有hivePlugin的指针以便之后在权限授权的过程中引用
				}
			}
		}
}
}
```


2.创建一个hiveAuthorizer的对象的同时初始化一个rangerHivePlugin：


```java
class RangerHivePlugin extends RangerBasePlugin {
	public static boolean UpdateXaPoliciesOnGrantRevoke = RangerHadoopConstants.HIVE_UPDATE_RANGER_POLICIES_ON_GRANT_REVOKE_DEFAULT_VALUE;
	public static boolean BlockUpdateIfRowfilterColumnMaskSpecified = RangerHadoopConstants.HIVE_BLOCK_UPDATE_IF_ROWFILTER_COLUMNMASK_SPECIFIED_DEFAULT_VALUE;
	public static String DescribeShowTableAuth = RangerHadoopConstants.HIVE_DESCRIBE_TABLE_SHOW_COLUMNS_AUTH_OPTION_PROP_DEFAULT_VALUE;

	private static String RANGER_PLUGIN_HIVE_ULRAUTH_FILESYSTEM_SCHEMES = "ranger.plugin.hive.urlauth.filesystem.schemes";
	private static String RANGER_PLUGIN_HIVE_ULRAUTH_FILESYSTEM_SCHEMES_DEFAULT = "hdfs:,file:";
	private static String FILESYSTEM_SCHEMES_SEPARATOR_CHAR = ",";
	private String[] fsScheme = null;

	public RangerHivePlugin(String appType) {
		super("hive", appType);
	}

	@Override
	public void init() {
		super.init() { // 这一步启动 策略引擎 （policy engine）和 策略提取器 （policy refresher）从RangerAdmin提取更新
    
        cleanup();

		AuditProviderFactory providerFactory = AuditProviderFactory.getInstance();

		if (!providerFactory.isInitDone()) {
			if (pluginConfig.getProperties() != null) {
				providerFactory.init(pluginConfig.getProperties(), getAppId());
			} else {
				LOG.error("Audit subsystem is not initialized correctly. Please check audit configuration. ");
				LOG.error("No authorization audits will be generated. ");
			}
		}

		refresher = new PolicyRefresher(this);
		LOG.info("Created PolicyRefresher Thread(" + refresher.getName() + ")");
		refresher.setDaemon(true);
		refresher.startRefresher() { // 启动一个后台线程时不时从Ranger Admin拉取新的策略
            loadRoles(); // 从RangerAdmin中载入访问资源的用户组，如果调取失败从缓存中提取
            loadPolicy(); // 同上，用RangerPerfTracer记录日志、标签、数据以及时间戳

		    super.start();

		    policyDownloadTimer = new Timer("policyDownloadTimer", true);

		    try {
			    policyDownloadTimer.schedule(new DownloaderTask(policyDownloadQueue), pollingIntervalMs, pollingIntervalMs);
                // 使用java util的定时器以及一个布尔值队列强制以pollingIntervalMs的时间间隔执行策略提取

			    if (LOG.isDebugEnabled()) {
				    LOG.debug("Scheduled policyDownloadRefresher to download policies every " + pollingIntervalMs + " milliseconds");
			    }
		    } catch (IllegalStateException exception) {
			    LOG.error("Error scheduling policyDownloadTimer:", exception);
			    LOG.error("*** Policies will NOT be downloaded every " + pollingIntervalMs + " milliseconds ***");

			    policyDownloadTimer = null;
		    }
    
        } 

		for (RangerChainedPlugin chainedPlugin : chainedPlugins) {
			chainedPlugin.init(); // 启动这个plugin下一链的plugin如果有的话
		}
    } 

		RangerHivePlugin.UpdateXaPoliciesOnGrantRevoke = getConfig().getBoolean(RangerHadoopConstants.HIVE_UPDATE_RANGER_POLICIES_ON_GRANT_REVOKE_PROP, RangerHadoopConstants.HIVE_UPDATE_RANGER_POLICIES_ON_GRANT_REVOKE_DEFAULT_VALUE);
		RangerHivePlugin.BlockUpdateIfRowfilterColumnMaskSpecified = getConfig().getBoolean(RangerHadoopConstants.HIVE_BLOCK_UPDATE_IF_ROWFILTER_COLUMNMASK_SPECIFIED_PROP, RangerHadoopConstants.HIVE_BLOCK_UPDATE_IF_ROWFILTER_COLUMNMASK_SPECIFIED_DEFAULT_VALUE);
		RangerHivePlugin.DescribeShowTableAuth = getConfig().get(RangerHadoopConstants.HIVE_DESCRIBE_TABLE_SHOW_COLUMNS_AUTH_OPTION_PROP, RangerHadoopConstants.HIVE_DESCRIBE_TABLE_SHOW_COLUMNS_AUTH_OPTION_PROP_DEFAULT_VALUE);

		String fsSchemesString = getConfig().get(RANGER_PLUGIN_HIVE_ULRAUTH_FILESYSTEM_SCHEMES, RANGER_PLUGIN_HIVE_ULRAUTH_FILESYSTEM_SCHEMES_DEFAULT);
		fsScheme = StringUtils.split(fsSchemesString, FILESYSTEM_SCHEMES_SEPARATOR_CHAR);

		if (fsScheme != null) {
			for (int i = 0; i < fsScheme.length; i++) {
				fsScheme[i] = fsScheme[i].trim();
			}
		}
	}

	public String[] getFSScheme() {
		return fsScheme;
	}
}
```

策略更新流程图，类似于：

![policy-refresher-diagram](https://images2015.cnblogs.com/blog/1003929/201704/1003929-20170427154213131-740729630.png)

3.每次访问操作都会有对应的审计控制，这些审计控制会产生对应访问操作的审计日志

```java
enum HiveObjectType { NONE, DATABASE, TABLE, VIEW, PARTITION, INDEX, COLUMN, FUNCTION, URI, SERVICE_NAME, GLOBAL };
enum HiveAccessType { NONE, CREATE, ALTER, DROP, INDEX, LOCK, SELECT, UPDATE, USE, READ, WRITE, ALL, REPLADMIN, SERVICEADMIN, TEMPUDFADMIN };
```

```java
private RangerAccessResult createAuditEvent(RangerHivePlugin hivePlugin, String userOrGrantor, List<String> roleUsers, HiveOperationType hiveOperationType, HiveAccessType accessType, List<String> roleNames, boolean result) {
		RangerHiveAccessRequest	rangerHiveAccessRequest	= createRangerHiveAccessRequest(userOrGrantor, roleUsers, hiveOperationType, accessType, roleNames);
		RangerAccessResult		accessResult 			= createRangerHiveAccessResult(hivePlugin, userOrGrantor, rangerHiveAccessRequest, result);
		return accessResult;
	}
```


RangerAuditHandler在处理每个访问请求的时候都会对自己所产生的对应alias角色产生相应操作，包括以下接口：

```java
public interface RangerAdminClient {

	void init(String serviceName, String appId, String configPropertyPrefix, Configuration config);

	ServicePolicies getServicePoliciesIfUpdated(long lastKnownVersion, long lastActivationTimeInMillis) throws Exception;

	RangerRoles getRolesIfUpdated(long lastKnownRoleVersion, long lastActivationTimeInMills) throws Exception;

	RangerRole createRole(RangerRole request) throws Exception;

	void dropRole(String execUser, String roleName) throws Exception;

	List<String> getAllRoles(String execUser) throws Exception;

	List<String> getUserRoles(String execUser) throws Exception;

	RangerRole getRole(String execUser, String roleName) throws Exception;

	void grantRole(GrantRevokeRoleRequest request) throws Exception;

	void revokeRole(GrantRevokeRoleRequest request) throws Exception;

	void grantAccess(GrantRevokeRequest request) throws Exception;

	void revokeAccess(GrantRevokeRequest request) throws Exception;

	ServiceTags getServiceTagsIfUpdated(long lastKnownVersion, long lastActivationTimeInMillis) throws Exception;

	List<String> getTagTypes(String tagTypePattern) throws Exception;

	RangerUserStore getUserStoreIfUpdated(long lastKnownUserStoreVersion, long lastActivationTimeInMillis) throws Exception;

}
```

用法以RangerHiveAuthorizer中createRole()为例：

```java
@Override
	public void createRole(String roleName, HivePrincipal adminGrantor)
			throws HiveAuthzPluginException, HiveAccessControlException {
		if(LOG.isDebugEnabled()) {
			LOG.debug(" ==> RangerHiveAuthorizer.createRole()");
		}
		RangerHiveAuditHandler auditHandler = new RangerHiveAuditHandler();
		String currentUserName = getGrantorUsername(adminGrantor);
		List<String> roleNames     = Arrays.asList(roleName);
		List<String> userNames     = Arrays.asList(currentUserName);
		boolean		 result		   = false;

		if (RESERVED_ROLE_NAMES.contains(roleName.trim().toUpperCase())) {
			throw new HiveAuthzPluginException("Role name cannot be one of the reserved roles: " +
					RESERVED_ROLE_NAMES);
		}

		try {
			RangerRole role  = new RangerRole();
			role.setName(roleName);
			role.setCreatedByUser(currentUserName);
			role.setCreatedBy(currentUserName);
			role.setUpdatedBy(currentUserName);
			//Add grantor as the member to this role with grant option.
			RangerRole.RoleMember userMember = new RangerRole.RoleMember(currentUserName, true);
			List<RangerRole.RoleMember> userMemberList = new ArrayList<>();
			userMemberList.add(userMember);
			role.setUsers(userMemberList);
			RangerRole ret = hivePlugin.createRole(role, auditHandler);
            // RangerAuditHandler根据自己线程上对应的AdminClient调用RangerAdminRESTClient类生成一个RangerRole
			if(LOG.isDebugEnabled()) {
				LOG.debug("<== createRole(): " + ret);
			}
			result = true;
		} catch(Exception excp) {
			throw new HiveAccessControlException(excp);
		} finally {
			RangerAccessResult accessResult = createAuditEvent(hivePlugin, currentUserName, userNames, HiveOperationType.CREATEROLE, HiveAccessType.CREATE, roleNames, result);
			auditHandler.processResult(accessResult);
			auditHandler.flushAudit();
		}
	}
```

以上操作涉及的主要类包括：org.apache.ranger.authorization.hive.authorizer.RangerHiveAuthorizer、org.apache.ranger.plugin.service.RangerBasePlugin以及org.apache.ranger.admin.client.RangerAdminRESTClient

#### 给一个访问资源操作授权：

1. RangerHiveAuthorizer中调用checkPriviliages方法实现：

```java
/**
	 * Check if user has privileges to do this action on these objects
	 * @param hiveOpType
	 * @param inputHObjs
	 * @param outputHObjs
	 * @param context
	 * @throws HiveAuthzPluginException
	 * @throws HiveAccessControlException
	 */
	@Override
	public void checkPrivileges(HiveOperationType         hiveOpType,
								List<HivePrivilegeObject> inputHObjs,
							    List<HivePrivilegeObject> outputHObjs,
							    HiveAuthzContext          context)
		      throws HiveAuthzPluginException, HiveAccessControlException {
		UserGroupInformation ugi = getCurrentUserGroupInfo();

		if(ugi == null) {
			throw new HiveAccessControlException("Permission denied: user information not available");
		}

		RangerHiveAuditHandler auditHandler = new RangerHiveAuditHandler(); // 生成一个新的 审计控制 类

		RangerPerfTracer perf = null;

		try {
			HiveAuthzSessionContext sessionContext = getHiveAuthzSessionContext();
			String                  user           = ugi.getShortUserName();
			Set<String>             groups         = Sets.newHashSet(ugi.getGroupNames());
			Set<String>             roles          = getCurrentRoles();

			if(LOG.isDebugEnabled()) {
				LOG.debug(toString(hiveOpType, inputHObjs, outputHObjs, context, sessionContext));
			}

            //处理hive Cli中DFS命令
			if(hiveOpType == HiveOperationType.DFS) {
				handleDfsCommand(hiveOpType, inputHObjs, user, auditHandler);

				return;
			}

			if(RangerPerfTracer.isPerfTraceEnabled(PERF_HIVEAUTH_REQUEST_LOG)) {
				perf = RangerPerfTracer.getPerfTracer(PERF_HIVEAUTH_REQUEST_LOG, "RangerHiveAuthorizer.checkPrivileges(hiveOpType=" + hiveOpType + ")");
			}

			List<RangerHiveAccessRequest> requests = new ArrayList<RangerHiveAccessRequest>(); // 生成一个请求的 动态数组

			if(!CollectionUtils.isEmpty(inputHObjs)) {
				for(HivePrivilegeObject hiveObj : inputHObjs) {
					RangerHiveResource resource = getHiveResource(hiveOpType, hiveObj, inputHObjs, outputHObjs);

					if (resource == null) { // possible if input object/object is of a kind that we don't currently authorize
						continue;
					}

					String 	path         		= hiveObj.getObjectName();
					HiveObjectType hiveObjType  = resource.getObjectType();

                    // 判断资源标示是否是任何一种file scheme, 否则的话 s3 有另外一套授权流程
					if(hiveObjType == HiveObjectType.URI && isPathInFSScheme(path)) {
						FsAction permission = getURIAccessType(hiveOpType); //得到权限类型

						if(!isURIAccessAllowed(user, permission, path, getHiveConf())) {
							throw new HiveAccessControlException(String.format("Permission denied: user [%s] does not have [%s] privilege on [%s]", user, permission.name(), path));
						}

						continue;
					}
                    // 如果有访问路径的权限应有尽有，获取对应的访问类型
					HiveAccessType accessType = getAccessType(hiveObj, hiveOpType, hiveObjType, true);

					if(accessType == HiveAccessType.NONE) {
						continue;
					}
                    // 防止添加重复的资源请求
					if(!existsByResourceAndAccessType(requests, resource, accessType)) {
						RangerHiveAccessRequest request = new RangerHiveAccessRequest(resource, user, groups, roles, hiveOpType, accessType, context, sessionContext);
						requests.add(request);
					}
				}
			} else {
				// this should happen only for SHOWDATABASES
                // hive操作类型所能选的值详见org.apache.hadoop.hive.ql.security.authorization.plugin.HiveOperationType
				if (hiveOpType == HiveOperationType.SHOWDATABASES) {
					RangerHiveResource resource = new RangerHiveResource(HiveObjectType.DATABASE, null);
					RangerHiveAccessRequest request = new RangerHiveAccessRequest(resource, user, groups, roles, hiveOpType.name(), HiveAccessType.USE, context, sessionContext);
					requests.add(request);
				} else if ( hiveOpType ==  HiveOperationType.REPLDUMP) {
					// This happens when REPL DUMP command with null inputHObjs is sent in checkPrivileges()
					// following parsing is done for Audit info
					RangerHiveResource resource  = null;
					HiveObj hiveObj  = new HiveObj(context);
					String dbName    = hiveObj.getDatabaseName();
					String tableName = hiveObj.getTableName();
					LOG.debug("Database: " + dbName + " Table: " + tableName);
					if (!StringUtil.isEmpty(tableName)) {
						resource = new RangerHiveResource(HiveObjectType.TABLE, dbName, tableName);
					} else {
						resource = new RangerHiveResource(HiveObjectType.DATABASE, dbName, null);
					}
					//
					RangerHiveAccessRequest request = new RangerHiveAccessRequest(resource, user, groups, roles, hiveOpType.name(), HiveAccessType.REPLADMIN, context, sessionContext);
					requests.add(request);
				} else {
					if (LOG.isDebugEnabled()) {
						LOG.debug("RangerHiveAuthorizer.checkPrivileges: Unexpected operation type[" + hiveOpType + "] received with empty input objects list!");
					}
				}
			}

            // 同上述类似流程判断outputHiveObjects
			if(!CollectionUtils.isEmpty(outputHObjs)) {
				for(HivePrivilegeObject hiveObj : outputHObjs) {
					RangerHiveResource resource = getHiveResource(hiveOpType, hiveObj, inputHObjs, outputHObjs);

					if (resource == null) { // possible if input object/object is of a kind that we don't currently authorize
						continue;
					}

					String   path       = hiveObj.getObjectName();
					HiveObjectType hiveObjType  = resource.getObjectType();

					if(hiveObjType == HiveObjectType.URI  && isPathInFSScheme(path)) {
						FsAction permission = getURIAccessType(hiveOpType);

		                if(!isURIAccessAllowed(user, permission, path, getHiveConf())) {
		    				throw new HiveAccessControlException(String.format("Permission denied: user [%s] does not have [%s] privilege on [%s]", user, permission.name(), path));
		                }

						continue;
					}

					HiveAccessType accessType = getAccessType(hiveObj, hiveOpType, hiveObjType, false);

					if(accessType == HiveAccessType.NONE) {
						continue;
					}

					if(!existsByResourceAndAccessType(requests, resource, accessType)) {
						RangerHiveAccessRequest request = new RangerHiveAccessRequest(resource, user, groups, roles, hiveOpType, accessType, context, sessionContext);

						requests.add(request);
					}
				}
			} else {
				if (hiveOpType == HiveOperationType.REPLLOAD) {
					// This happens when REPL LOAD command with null inputHObjs is sent in checkPrivileges()
					// following parsing is done for Audit info
					RangerHiveResource resource = null;
					HiveObj hiveObj = new HiveObj(context);
					String dbName = hiveObj.getDatabaseName();
					String tableName = hiveObj.getTableName();
					LOG.debug("Database: " + dbName + " Table: " + tableName);
					if (!StringUtil.isEmpty(tableName)) {
						resource = new RangerHiveResource(HiveObjectType.TABLE, dbName, tableName);
					} else {
						resource = new RangerHiveResource(HiveObjectType.DATABASE, dbName, null);
					}
					RangerHiveAccessRequest request = new RangerHiveAccessRequest(resource, user, groups, roles, hiveOpType.name(), HiveAccessType.REPLADMIN, context, sessionContext);
					requests.add(request);
				}
			}
            // 开始处理所有资源访问请求
			buildRequestContextWithAllAccessedResources(requests);

			for(RangerHiveAccessRequest request : requests) {
				if (LOG.isDebugEnabled()) {
					LOG.debug("request: " + request);
				}
				RangerHiveResource resource = (RangerHiveResource)request.getResource();
				RangerAccessResult result   = null;

				if(resource.getObjectType() == HiveObjectType.COLUMN && StringUtils.contains(resource.getColumn(), COLUMN_SEP)) {
					List<RangerAccessRequest> colRequests = new ArrayList<RangerAccessRequest>();

					String[] columns = StringUtils.split(resource.getColumn(), COLUMN_SEP);

					// in case of multiple columns, original request is not sent to the plugin; hence service-def will not be set
					resource.setServiceDef(hivePlugin.getServiceDef());

					for(String column : columns) {
						if (column != null) {
							column = column.trim();
						}
						if(StringUtils.isBlank(column)) {
							continue;
						}

						RangerHiveResource colResource = new RangerHiveResource(HiveObjectType.COLUMN, resource.getDatabase(), resource.getTable(), column);
						colResource.setOwnerUser(resource.getOwnerUser());

						RangerHiveAccessRequest colRequest = request.copy();
						colRequest.setResource(colResource);

						colRequests.add(colRequest);
					}
                    //依次判断是否可以访问
					Collection<RangerAccessResult> colResults = hivePlugin.isAccessAllowed(colRequests, auditHandler);

					if(colResults != null) {
						for(RangerAccessResult colResult : colResults) {
							result = colResult;

							if(result != null && !result.getIsAllowed()) {
								break;
							}
						}
					}
				} else {
					result = hivePlugin.isAccessAllowed(request, auditHandler);
				}

				if((result == null || result.getIsAllowed()) && isBlockAccessIfRowfilterColumnMaskSpecified(hiveOpType, request)) {
					// check if row-filtering is applicable for the table/view being accessed
					HiveAccessType     savedAccessType = request.getHiveAccessType();
					RangerHiveResource tblResource     = new RangerHiveResource(HiveObjectType.TABLE, resource.getDatabase(), resource.getTable());

					request.setHiveAccessType(HiveAccessType.SELECT); // filtering/masking policies are defined only for SELECT
					request.setResource(tblResource);

					RangerAccessResult rowFilterResult = getRowFilterResult(request);

					if (isRowFilterEnabled(rowFilterResult)) {
						if(result == null) {
							result = new RangerAccessResult(RangerPolicy.POLICY_TYPE_ACCESS, rowFilterResult.getServiceName(), rowFilterResult.getServiceDef(), request);
						}

						result.setIsAllowed(false);
						result.setPolicyId(rowFilterResult.getPolicyId());
						result.setReason("User does not have access to all rows of the table");
					} else {
                        // 这里根据result来判定是否有修改hive column的权限
						// check if masking is enabled for any column in the table/view
						request.setResourceMatchingScope(RangerAccessRequest.ResourceMatchingScope.SELF_OR_DESCENDANTS);

						RangerAccessResult dataMaskResult = getDataMaskResult(request);

						if (isDataMaskEnabled(dataMaskResult)) {
							if(result == null) {
								result = new RangerAccessResult(RangerPolicy.POLICY_TYPE_ACCESS, dataMaskResult.getServiceName(), dataMaskResult.getServiceDef(), request);
							}

							result.setIsAllowed(false);
							result.setPolicyId(dataMaskResult.getPolicyId());
							result.setReason("User does not have access to unmasked column values");
						}
					}

					request.setHiveAccessType(savedAccessType);
					request.setResource(resource);

					if(result != null && !result.getIsAllowed()) {
						auditHandler.processResult(result);
					}
				}

				if(result == null || !result.getIsAllowed()) {
					String path = resource.getAsString();
					path = (path == null) ? "Unknown resource!!" : buildPathForException(path, hiveOpType);
					throw new HiveAccessControlException(String.format("Permission denied: user [%s] does not have [%s] privilege on [%s]",
														 user, request.getHiveAccessType().name(), path));
				}
			}
		} finally {
			auditHandler.flushAudit();
			RangerPerfTracer.log(perf);
		}
	}
```

2.调用isAccessAllowed()

访问决策树结构：

![AcessAllowed-Tree](https://upload-images.jianshu.io/upload_images/11810589-7770bf805ab5b1cc.png?imageMogr2/auto-orient/strip|imageView2/2/w/560)

策略优先级:

- 黑名单优先级高于白名单


- 黑名单排除优先级高于黑名单


- 白名单排除优先级高于白名单


- 决策下放：如果没有policy能决策访问，一般情况是认为没有权限拒绝访问，然而Ranger还可以选择将决策下放给系统自身的访问控制层，比如HDFS的ACL，这个和每个Ranger插件以及应用系统自己的实现有关。


```java
public Collection<RangerAccessResult> isAccessAllowed(Collection<RangerAccessRequest> requests, RangerAccessResultProcessor resultProcessor) {
		Collection<RangerAccessResult> ret          = null;
		RangerPolicyEngine             policyEngine = this.policyEngine;

		if (policyEngine != null) {
			ret = policyEngine.evaluatePolicies(requests, RangerPolicy.POLICY_TYPE_ACCESS, null);
		}

		if (CollectionUtils.isNotEmpty(ret)) {
			for (RangerChainedPlugin chainedPlugin : chainedPlugins) {
				Collection<RangerAccessResult> chainedResults = chainedPlugin.isAccessAllowed(requests);

				if (CollectionUtils.isNotEmpty(chainedResults)) {
					Iterator<RangerAccessResult> iterRet            = ret.iterator();
					Iterator<RangerAccessResult> iterChainedResults = chainedResults.iterator();

					while (iterRet.hasNext() && iterChainedResults.hasNext()) {
						RangerAccessResult result        = iterRet.next();
						RangerAccessResult chainedResult = iterChainedResults.next();

						if (result != null && chainedResult != null) {
							updateResultFromChainedResult(result, chainedResult);
						}
					}
				}
			}
		}

		if (resultProcessor != null) {
			resultProcessor.processResults(ret);
		}

		return ret;
	}
```

RangerBasePlugin.isAccessAllowed -> 

RangerPolicyEngineImpl.evaluatePolicies -> 
    
RangerPolicyEngineImpl.zoneAwareAccessEvaluationWithNoAudit -> 

RangerPolicyEngineImpl.evaluatePolicesNoAudit

```java
private RangerAccessResult evaluatePoliciesNoAudit(RangerAccessRequest request, int policyType, String zoneName, RangerPolicyRepository policyRepository, RangerPolicyRepository tagPolicyRepository) {
		if (LOG.isDebugEnabled()) {
			LOG.debug("==> RangerPolicyEngineImpl.evaluatePoliciesNoAudit(" + request + ", policyType =" + policyType + ", zoneName=" + zoneName + ")");
		}

		final Date               accessTime  = request.getAccessTime() != null ? request.getAccessTime() : new Date();
		final RangerAccessResult ret         = createAccessResult(request, policyType);
		final boolean            isSuperUser = isSuperUser(request.getUser(), request.getUserGroups());

		// for superusers, set access as allowed
		if (isSuperUser) {
			ret.setIsAllowed(true);
			ret.setIsAccessDetermined(true);
			ret.setPolicyId(-1);
			ret.setPolicyPriority(Integer.MAX_VALUE);
			ret.setReason("superuser");
		}

		evaluateTagPolicies(request, policyType, zoneName, tagPolicyRepository, ret);

		if (LOG.isDebugEnabled()) {
			if (ret.getIsAccessDetermined() && ret.getIsAuditedDetermined()) {
				if (!ret.getIsAllowed()) {
					LOG.debug("RangerPolicyEngineImpl.evaluatePoliciesNoAudit() - audit determined and access denied by a tag policy. Higher priority resource policies will be evaluated to check for allow, request=" + request + ", result=" + ret);
				} else {
					LOG.debug("RangerPolicyEngineImpl.evaluatePoliciesNoAudit() - audit determined and access allowed by a tag policy. Same or higher priority resource policies will be evaluated to check for deny, request=" + request + ", result=" + ret);
				}
			}
		}

		boolean isAllowedByTags          = ret.getIsAccessDetermined() && ret.getIsAllowed();
		boolean isDeniedByTags           = ret.getIsAccessDetermined() && !ret.getIsAllowed();
		boolean evaluateResourcePolicies = policyEngine.hasResourcePolicies(policyRepository);

		if (evaluateResourcePolicies) {
			boolean findAuditByResource = !ret.getIsAuditedDetermined();
			boolean foundInCache        = findAuditByResource && policyRepository.setAuditEnabledFromCache(request, ret);

			if (!isSuperUser) {
				ret.setIsAccessDetermined(false); // discard result by tag-policies, to evaluate resource policies for possible override
			}

			List<RangerPolicyEvaluator> evaluators = policyRepository.getLikelyMatchPolicyEvaluators(request.getResource(), policyType);

			for (RangerPolicyEvaluator evaluator : evaluators) {
				if (!evaluator.isApplicable(accessTime)) {
					continue;
				}

				if (isDeniedByTags) {
					if (ret.getPolicyPriority() >= evaluator.getPolicyPriority()) {
						ret.setIsAccessDetermined(true);
					}
				} else if (ret.getIsAllowed()) {
					if (ret.getPolicyPriority() > evaluator.getPolicyPriority()) {
						ret.setIsAccessDetermined(true);
					}
				}

				ret.incrementEvaluatedPoliciesCount();
				evaluator.evaluate(request, ret);

				if (ret.getIsAllowed()) {
					if (!evaluator.hasDeny()) { // No more deny policies left
						ret.setIsAccessDetermined(true);
					}
				}

				if (ret.getIsAuditedDetermined() && ret.getIsAccessDetermined()) {
					break;            // Break out of policy-evaluation loop
				}

			}

			if (!ret.getIsAccessDetermined()) {
				if (isDeniedByTags) {
					ret.setIsAllowed(false);
				} else if (isAllowedByTags) {
					ret.setIsAllowed(true);
				}
			}

			if (ret.getIsAllowed()) {
				ret.setIsAccessDetermined(true);
			}

			if (findAuditByResource && !foundInCache) {
				policyRepository.storeAuditEnabledInCache(request, ret);
			}
		}

		if (LOG.isDebugEnabled()) {
			LOG.debug("<== RangerPolicyEngineImpl.evaluatePoliciesNoAudit(" + request + ", policyType =" + policyType + ", zoneName=" + zoneName + "): " + ret);
		}

		return ret;
	}
```

#### 支持资源查看：

当RangerAdmin创建策略时, 用户输入需要保护其权限的资源的名称。为了方便用户输入资源名称，RangerAdmin提供了自动完成功能，该功能查找服务中与目前为止输入内容匹配的资源。RangerAdmin要求提供RangerBaseService接口的实现，实现类应该在Ranger服务类型中定义，并在RangerAdmin CLASSPATH中可用。

```java
@Override
	public Map<String,Object> validateConfig() throws Exception {
		Map<String, Object> ret = new HashMap<String, Object>();
		String 	serviceName  	    = getServiceName();
		if(LOG.isDebugEnabled()) {
			LOG.debug("==> RangerServiceHive.validateConfig Service: (" + serviceName + " )");
		}
		if ( configs != null) {
			try  {
				ret = HiveResourceMgr.connectionTest(serviceName, configs);
			} catch (HadoopException e) {
				LOG.error("<== RangerServiceHive.validateConfig Error:" + e);
				throw e;
			}
		}
		if(LOG.isDebugEnabled()) {
			LOG.debug("<== RangerServiceHive.validateConfig Response : (" + ret + " )");
		}
		return ret;
	}

	@Override
	public List<String> lookupResource(ResourceLookupContext context) throws Exception {

		List<String> ret 		   = new ArrayList<String>();
		String 	serviceName  	   = getServiceName();
		String	serviceType		   = getServiceType();
		Map<String,String> configs = getConfigs();
		if(LOG.isDebugEnabled()) {
			LOG.debug("==> RangerServiceHive.lookupResource Context: (" + context + ")");
		}
		if (context != null) {
			try {
				ret  = HiveResourceMgr.getHiveResources(serviceName, serviceType, configs,context);
			} catch (Exception e) {
				LOG.error( "<==RangerServiceHive.lookupResource Error : " + e);
				throw e;
			}
		}
		if(LOG.isDebugEnabled()) {
			LOG.debug("<== RangerServiceHive.lookupResource Response: (" + ret + ")");
		}
		return ret;
	}
```

## 参考资料

1. https://github.com/apache/ranger
2. https://blog.csdn.net/tototuzuoquan/article/details/106505018
3. https://www.jianshu.com/p/d0bf6e77bb8f
4. https://www.cnblogs.com/qiuyuesu/p/6774520.html
5. https://ieevee.com/tech/2016/05/12/ranger.html#支持组件
6. https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=53741207