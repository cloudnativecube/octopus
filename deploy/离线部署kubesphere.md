## Deploy KubeSphere on k8s
### 准备离线docker镜像
在有网络环境的机器下载docker镜像
```
docker pull kubesphere/ks-installer:v3.0.0
docker pull csiplugin/snapshot-controller:v2.0.1
docker pull mirrorgooglecontainers/defaultbackend-amd64:1.4
docker pull kubesphere/kube-state-metrics:v1.9.6
docker pull kubesphere/node-exporter:ks-v0.18.1
docker pull kubesphere/kube-rbac-proxy:v0.4.1
docker pull kubesphere/notification-manager-operator:v0.1.0
docker pull kubesphere/prometheus-operator:v0.38.3
docker pull kubesphere/ks-apiserver:v3.0.0
docker pull kubesphere/ks-console:v3.0.0
docker pull kubesphere/ks-controller-manager:v3.0.0
docker pull osixia/openldap:1.3.0
docker pull redis:5.0.5-alpine
docker pull jimmidyson/configmap-reload:v0.3.0
docker pull prom/alertmanager:v0.21.0
docker pull kubesphere/notification-manager:v0.1.0
docker pull prom/prometheus:v2.20.1
docker pull kubesphere/prometheus-config-reloader:v0.38.3
docker pull kubesphere/kubectl:v1.0.0
```
然后通过docker save和load在目标节点导入安装所需docker镜像  
### 准备default storage class
这里使用local类型存储  
#### 创建storageclass
kubectl apply -f storageclass.yaml
```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```
#### 创建待使用pv
创建目录：  
mkdir /pvc/disks/pv1 -p  
mkdir /pvc/disks/pv2 -p  
mkdir /pvc/disks/pv3 -p  
创建pv：  
kubectl apply -f pv1.yaml  
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv1
spec:
  capacity:
    storage: 2Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /pvc/disks/pv1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - centos03
```
kubectl apply -f pv2.yaml  
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv1
spec:
  capacity:
    storage: 2Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /pvc/disks/pv2
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - centos03
```
kubectl apply -f pv3.yaml  
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv1
spec:
  capacity:
    storage: 20Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /pvc/disks/pv3
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - centos03
```
#### 设置default storageclass
kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'  

### 安装kubesphere
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.0.0/kubesphere-installer.yaml  
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.0.0/cluster-configuration.yaml  

#### 查看安装日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f  
#### 检查安装
kubectl get pod --all-namespaces  
如果所有pod都正常启动后，查看服务端口：  
kubectl get svc/ks-console -n kubesphere-system  
#### 访问web
http://10.0.0.13:30880/  
默认账号密码：admin/P@88w0rd
#### 遇到的问题
因为k8s版本是1.19，和ks的兼容有点问题，在同步admin账号时会报错，需要执行以下命令：  
kubectl apply -f https://raw.githubusercontent.com/kubesphere/ks-installer/2c4b479ec65110f7910f913734b3d069409d72a8/roles/ks-core/prepare/files/ks-init/users.iam.kubesphere.io.yaml  
kubectl apply -f https://raw.githubusercontent.com/kubesphere/ks-installer/2c4b479ec65110f7910f913734b3d069409d72a8/roles/ks-core/prepare/files/ks-init/webhook-secret.yaml  
kubectl -n kubesphere-system rollout restart deploy ks-controller-manager  
