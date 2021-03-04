## Clickhouse基于docker编译

**请安装docker**

参照docker官网此处不再赘述，但编译过程需要消耗大内存和cpu,请尽量分配足够多的资源。

**制作编译镜像**

在目录ClickHouse/docker/builder下执行
```
make image
```

**开始编译**

注意：开始编译前请注意修改Dockerfile文件，master分支的Dockerfile已经是修正过的，但是比较老的分支可能需要将Dockerfile中所安装的包是否包含：
```
 python3 
 python3-lxml 
 python3-requests 
 python3-termcolor
```

若不是python3请修改成python3

在目录ClickHouse/docker/builder下执行

```
make build
```

**参考**

https://github.com/ClickHouse/ClickHouse/tree/master/docker/builder