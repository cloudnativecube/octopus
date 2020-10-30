#!/bin/sh
octopus_home=/home/servers/
cd $octopus_home/zookeeper-3.6.2/ && bin/zkServer.sh --config $octopus_home/zookeeper-3.6.2/conf/zoo.cfg start
