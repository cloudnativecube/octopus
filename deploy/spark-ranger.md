# spark-ranger

## Build

```
mvn clean package -Pspark-2.4 -Pranger-2.0 -DskipTests
```

*Currently, available profiles are:*

*Spark: -Pspark-2.3, -Pspark-2.4*

*Ranger: -Pranger-1.0, -Pranger-1.1, -Pranger-1.2 -Pranger-2.0*

```
删除jar的'META-INF/.SF' 'META-INF/.RSA' 'META-INF/*SF'文件  
```



## Usage

### Installation

```
Place the spark-ranger-1.0-SNAPSHOT.jar into /home/servers/spark-2.4.7/jars.
```

### Configurations

Create **ranger-spark-security.xml** in **/home/servers/spark-2.4.7/conf** and add the following configurations for pointing to the right ranger admin server

```
<configuration>

    <property>
        <name>ranger.plugin.spark.policy.rest.url</name>
        <value>http://10.0.0.11:6080</value>
    </property>

    <property>
        <name>ranger.plugin.spark.service.name</name>
        <value>hivedev</value>
    </property>

    <property>
        <name>ranger.plugin.spark.policy.cache.dir</name>
        <value>./hivedev/policycache</value>
    </property>

    <property>
        <name>ranger.plugin.spark.policy.pollIntervalMs</name>
        <value>5000</value>
    </property>

    <property>
        <name>ranger.plugin.spark.policy.source.impl</name>
        <value>org.apache.ranger.admin.client.RangerAdminRESTClient</value>
    </property>

</configuration>
```

Create **ranger-spark-audit.xml** in **/home/servers/spark-2.4.7/conf** and add the following configurations to enable/disable auditing.

```
<configuration>

    <property>
        <name>xasecure.audit.is.enabled</name>
        <value>true</value>
    </property>

    <property>
        <name>xasecure.audit.destination.db</name>
        <value>false</value>
    </property>

    <property>
        <name>xasecure.audit.destination.db.jdbc.driver</name>
        <value>com.mysql.jdbc.Driver</value>
    </property>

    <property>
        <name>xasecure.audit.destination.db.jdbc.url</name>
        <value>jdbc:mysql://10.0.0.11/ranger</value>
    </property>

    <property>
        <name>xasecure.audit.destination.db.password</name>
        <value>2020root</value>
    </property>

    <property>
        <name>xasecure.audit.destination.db.user</name>
        <value>rangeradmin</value>
    </property>

</configuration>
```



#### Enable plugin via spark extensions

```
添加
spark.sql.extensions=org.apache.ranger.authorization.spark.authorizer.RangerSparkSQLExtension
到
/home/servers/spark-2.4.7/conf/spark-defaults.conf
```

