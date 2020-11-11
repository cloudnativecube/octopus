#!/bin/sh
source ./octopus.env

if [ $# == 0 ];then
	echo "$0 zookeeper"

	echo "$0 hdfs"
	echo "$0 yarn"
	echo "$0 jobhistory : start yarn job history server"

	echo "$0 metastore : start hive metastore"
	echo "$0 hiveserver2 : start hive server2"

	echo "$0 thriftserver : start spark triftserver"
	echo "$0 historyserver : start spark history server"

	echo "$0 hbase"

	echo "$0 es"
	echo "$0 kibana"

	echo "$0 solr"
	echo "$0 knox"
	echo "$0 ranger-admin"
	echo "$0 ranger-usersync"
	exit 0
fi

octopus_home=/home/servers/
cd $octopus_home

if [ $1 == "zookeeper" ];then
	ansible -i hosts.inv all -mscript -a "./zk-start.sh"
fi

if [ $1 == "hdfs" ];then
	cd $hadoop_home && sbin/start-dfs.sh
fi

if [ $1 == "yarn" ];then
	cd $hadoop_home && sbin/start-yarn.sh
fi

if [ $1 == "jobhistory" ];then
	ansible -i hosts.inv all -mscript -a "./jobhistory-start.sh"
fi

if [ $1 == "metastore" ];then
        cd $hive_home && nohup hive --service metastore 2>&1 > metastore.log &
fi

if [ $1 == "hiveserver2" ];then
        cd $hive_home && nohup hive --service hiveserver2 2>&1 > hiveserver2.log &
fi

if [ $1 == "spark" ];then
	cd $spark_home && sbin/start-history-server.sh
fi

if [ $1 == "es" ];then
        ansible -i hosts.inv all -mscript -a "./es-start.sh"
fi

if [ $1 == "kibana" ];then
	cd $kibana_home && nohup bin/kibana 2>&1 > kibana.log &
fi

if [ $1 == "solr" ];then
	cd $solr_home && bin/solr start -force -cloud
fi

if [ $1 == "knox" ];then
	cd $knox_home && bin/ldap.sh start && sudo -uhadoop bin/gateway.sh start
fi

if [ $1 == "ranger-admin" ];then
	cd $ranger_home && ranger-admin start
fi

if [ $1 == "ranger-usersync" ];then
	cd $ranger_home && ranger-usersync start
fi
