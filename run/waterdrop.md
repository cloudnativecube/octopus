# 运行waterdrop

## 开发分支

开发是基于新分支 https://github.com/cloudnativecube/waterdrop/tree/branch-v1.5.1，其中修改了依赖的spark和scala版本。

```
spark.version=2.4.7
scala.version=2.11.12
```

## 运行

### 编译

编译命令请见文档：build.md。

执行编译打包命令：

```
# sbt "-DprovidedDeps=true"  universal:packageBin
# ll target/universal/waterdrop-1.5.1.zip
```

以上生成的zip包含了bin、config、lib等所有distribution的文件。

### 提交任务

将waterdrop-1.5.1.zip拷到spark client节点上：

```
# unzip waterdrop-1.5.1.zip
# cd waterdrop-1.5.1
# cp ./config/batch.conf.template ./config/batch.conf // 编辑一个新的配置文件
# bin/start-waterdrop.sh -m yarn -e client -c ./config/batch.conf -q default
```

batch.conf.template的配置可以生成几条input测试数据，并打印到标准输出。

