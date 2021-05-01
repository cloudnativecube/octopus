## 目标
1. 把clickhosue跑在k8s里，这是实现弹性调度重要的一步；
2. 能够借助于k8s的机制，实现扩缩容；

## 选型
目前有三个候选的：[Alitnity clickhouse-operator](https://github.com/Altinity/clickhouse-operator), [senstime's clickhouse operator](https://github.com/mackwong/clickhouse-operator), [ch-operator](https://github.com/xiedeyantu/ch-operator)  
其中senstime的引用了私有代码，无法编译，忽略。第三个ch-operator应该是一个个人项目，目前正在开发中，很多基础特性尚未完成实现（比如自定义镜像）或者有bug。而Altinity是专门做clickhouse运营的云厂商，有生产环境使用经验，并且项目还比较活跃。  
因此我们应该选择Alitinity的clickhouse operator。

## 部署
1. 下载代码：`git clone https://github.com/Altinity/clickhouse-operator`，进入到该目录；
2. 创建namespace：`kubectl create ns ck`
3. 创建clickhosue operator： `kubectl apply -f deploy/operator/clickhouse-operator-install.yaml`，在kube-system里可以看到clickhouse operator的pod；
![image](https://user-images.githubusercontent.com/5690854/115701788-ba404f80-a39a-11eb-93ba-c2412cfb591f.png)

4. 准备两个operator相关镜像和ck镜像（如机器可以联网请忽略，altinity/clickhouse-operator:0.13.5, yandex/clickhouse:21.4.4.30, zookeeper:3.6.2,  步骤可参考[这里](https://github.com/cloudnativecube/octopus/blob/master/deploy/%E7%A6%BB%E7%BA%BF%E9%83%A8%E7%BD%B2k8s.md)）；
5. 准备单副本单实例的ClickhouseInstalltion CRD的yaml：
```yaml
apiVersion: "clickhouse.altinity.com/v1"
kind: "ClickHouseInstallation"
metadata:
  name: "volume-hostpath"
spec:
  defaults:
    templates:
      podTemplate: clickhouse-per-host-on-servers-with-ssd
  configuration:
    clusters:
      - name: local-storage
        layout:
          shardsCount: 1
          replicasCount: 1
  templates:
    podTemplates:
      # Specify Pod Templates with affinity

      - name: clickhouse-per-host-on-servers-with-ssd
        #zone:
        #  key: "disktype"
        #  values:
        #    - "ssd"
        podDistribution:
          - type: ClickHouseAntiAffinity
        spec:
          volumes:
            # Specify volume as path on local filesystem as a directory which will be created, if need be
            - name: local-path
              hostPath:
                path: /mnt/podvolume
                type: DirectoryOrCreate
          containers:
            - name: clickhouse-pod
              image: yandex/clickhouse-server:21.4.4.30
              volumeMounts:
                # Specify reference to volume on local filesystem
                - name: local-path
                  mountPath: /var/lib/clickhouse
```
6. 部署ck集群：`kubectl -n ck apply -f example-01.yaml`
7.  验证CK是否可用：
```bash
$ kubectl -n ck get svc
chi-volume-hostpath-local-storage-0-0   ClusterIP      None          <none>        8123/TCP,9000/TCP,9009/TCP      54m
clickhouse-volume-hostpath              LoadBalancer   10.1.41.160   <pending>     8123:32307/TCP,9000:31321/TCP   54m
```
![image](https://user-images.githubusercontent.com/5690854/115805074-cc5fd380-a416-11eb-8a00-42b24d56c81d.png)

  
8. 改为2分片2副本，先启动一个单实例的zookeeper（clickhouse-operator多个不带）；
```bash
docker run -d --name my-zookeeper --restart always -p 2281:2181 -v $(pwd)/zoo.cfg:/conf/zoo.cfg zookeeper:3.6.2
```
修改上面的yaml：主要是`shardsCount: 2`, `replicasCount: 2`，还有zookeeper地址，然后apply到线上。
```
  configuration:
    clusters:
      - name: local-storage
        layout:
          shardsCount: 1
          replicasCount: 1
    zookeeper:
      nodes:
      - host: 10.0.0.14
        port: 2281
```
  
  
注：  上面这是一个比较简单的例子，其实它还可以配置更为复杂的，更多的示例可以参考`docs/chi-examples/`


## 探究
1. 此ck operator定义了3个k8s的CRD：`ClickHouseOperatorConfiguration`, `ClickHouseInstallation`, `ClickHouseInstallationTemplate`。  
其中`ClickHouseOperatorConfiguration`是定义了此operator自身的config， `ClickHouseInstallationTemplate`是一些模板，方便复用（定义与ClickHouseInstallation一致）。
1. 跟漂移相关的问题：
    1. `/etc/clickhouse-server`下面的配置文件，可以在漂移的时候自动挂载；
    1. `/var/lib/clickhouse`下面存储了账号、配额、建表语句等诸多元数据信息，这些信息在pod漂移的时候也需要同步挂上去，所以可以考虑用类似于NFS或Cephfs这种分布式文件系统进行挂载，statefulset下的pod会绑定固定的存储volume；
    1. 有时operator不会立即更新最新的crd，原因待继续查；
