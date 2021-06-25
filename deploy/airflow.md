# airflow

## 安装

### sqlite3

sqlite要求3.15以上版本，这里使用3.36版本。

```
$ wget https://sqlite.org/2021/sqlite-autoconf-3360000.tar.gz
$ tar zxvf sqlite-autoconf-3360000.tar.gz
$ cd sqlite-autoconf-3360000
$ ./confugre && make && make install
$ mv /usr/bin/sqlite3 /usr/bin/sqlite3.7 //如果有旧的版本，则重命名
$ ln -s /usr/local/bin/sqlite3 /usr/bin/sqlite3
```

在使用airflow命令之前，要引用sqlite库文件所在目录：

```
export LD_LIBRARY_PATH=/usr/local/lib
```

### airflow

1.安装

官方文档：https://airflow.apache.org/docs/apache-airflow/stable/start/local.html

使用hadoop用户安装airflow，因为airflow要调用spark-submit。

```
$ cd /export/airflow/venv //这是预先创建的python虚拟目录
$ export AIRFLOW_HOME=~/airflow //这里对应的就是/home/hadoop/airflow
$ AIRFLOW_VERSION=2.1.0
$ PYTHON_VERSION="$(python --version | cut -d " " -f 2 | cut -d "." -f 1-2)" // For example: 3.7
$ CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
$ wget $CONSTRAINT_URL
$ pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint constraints-3.7.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

pip install在执行过程中可能由于网速问题经常失败，请换个pip源尝试。

2.初始化

```
$ airflow db init
$ airflow users create \
    --username admin \
    --firstname Peter \
    --lastname Parker \
    --role Admin \
    --email spiderman@superhero.org //设置密码为admin
```

3.启动

 以前台方式启动服务：

```
# airflow webserver --port 8081
# airflow scheduler
```

以后台方式启动，写在脚本里：

```
// 脚本webserver.sh
#!/bin/sh
export AIRFLOW_HOME=/home/hadoop/airflow
export LD_LIBRARY_PATH=/usr/local/lib
airflow webserver --port 8081 -D --stderr ./webserver.err.log --stdout ./webserver.out.log

// 脚本scheduler.sh
#!/bin/sh
export AIRFLOW_HOME=/home/hadoop/airflow
export LD_LIBRARY_PATH=/usr/local/lib
airflow scheduler -D --stderr ./scheduler.err.log --stdout ./scheduler.out.log
```

打开url：http://centos00:8081 ，用户名/密码：admin/admin。

## 运行spark任务

### 配置connection

在web页面：Admin>Connections>spark_default，配置spark connection。

默认安装的airflow没有Spark类型的Conn Type，所以要手动安装spark provider：

```
$ pip install apache-airflow-providers-apache-spark
```

参考：

- providers列表：https://airflow.apache.org/docs/apache-airflow-providers/packages-ref.html

- spark provider文档：https://airflow.apache.org/docs/apache-airflow-providers-apache-spark/stable/index.html

### 编写dag代码

把dag文件拷贝到~/airflow/dags里之后，要运行airflow scheduler命令才能在`DAGs`页面上看到dag：

```
$ cp lib/python3.7/site-packages/airflow/providers/apache/spark/example_dags/example_spark_dag.py ~/airflow/dags
```

只要airflow scheduler一直运行，~/airflow/dags里的文件就会自动加载。

参考：

- spark operator api文档：https://airflow.apache.org/docs/apache-airflow-providers-apache-spark/stable/_api/airflow/providers/apache/spark/index.html

### 调度任务

在界面上触发spark任务，或者以命令行方式触发：

```
$ airflow tasks test example_spark_operator submit_job 20210623
```

## airflow常用配置

配置文件：/home/hadoop/airflow/airflow.cfg。

不加载example operator：

```
load_examples = False
```

## airflow常用命令

参考：https://airflow.apache.org/docs/apache-airflow/stable/cli-and-env-variables-ref.html