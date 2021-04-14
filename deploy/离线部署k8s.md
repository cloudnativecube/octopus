
## 安装docker
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-18.09.7-3.el7.x86_64.rpm  
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-18.09.7-3.el7.x86_64.rpm  
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.2-3.el7.x86_64.rpm  
wget http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.107-1.el7_6.noarch.rpm  
rpm -ivh *.rpm  
修改cgoupdriver为systemd与k8b保持一致，vim /etc/docker/daemon.json  
```
{
  "registry-mirrors": ["https://registry.docker-cn.com"],

  "exec-opts": ["native.cgroupdriver=systemd"]

}
```
systemctl  daemon-reload  
systemctl  restart docker  
设置开机启动  systemctl enable docker  

## 安装k8s
### 关闭 防火墙、SeLinux、swap  
systemctl stop firewalld  
systemctl disable firewalld  
setenforce 0  
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config  
swapoff -a  
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables  
### 安装kubeadm/kubectl/kubelet  
在有网络的服务器上下载需要的rpm安装包 
```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo

[kubernetes]

name=Kubernetes

baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64

enabled=1

gpgcheck=0

repo_gpgcheck=0

gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg

http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg

EOF
```
yum install --downloadonly --downloaddir=/root/offline_install_k8s/k8s/1.19/ kubelet-1.19.0-0 kubeadm-1.19.0-0 kubectl-1.19.0-0 --disableexcludes=kubernetes 
cp到目标机器进行安装  
rpm -ivh *.rpm  
### 获取k8s所需的docker镜像
kubeadm config images list  
```
k8s.gcr.io/kube-apiserver:v1.19.0
k8s.gcr.io/kube-controller-manager:v1.19.0
k8s.gcr.io/kube-scheduler:v1.19.0
k8s.gcr.io/kube-proxy:v1.19.0
k8s.gcr.io/pause:3.2
k8s.gcr.io/etcd:3.4.9-1
k8s.gcr.io/coredns:1.7.0
```
编写脚本，从阿里云下载镜像  
cat pull-images.sh  
```
#!/bin/bash

images=(
kube-apiserver:v1.19.0
kube-controller-manager:v1.19.0
kube-scheduler:v1.19.0
kube-proxy:v1.19.0
pause:3.2
etcd:3.4.9-1
coredns:1.7.0
)
for imageName in ${images[@]};
do
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName}
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName} k8s.gcr.io/${imageName}
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName}
done
```
编写脚本打包镜像  
cat save-images.sh  
```
#!/bin/bash

images=(
kube-apiserver:v1.19.0
kube-controller-manager:v1.19.0
kube-scheduler:v1.19.0
kube-proxy:v1.19.0
pause:3.2
etcd:3.4.9-1
coredns:1.7.0
)
for imageName in ${images[@]};
do
docker save -o `echo ${imageName}|awk -F ':' '{print $1}'`.tar k8s.gcr.io/${imageName}
done
```
在安装节点分别导入离线镜像  
docker load -i xxx(将离线镜像一一导入)  
### 初始化master节点
kubeadm init --apiserver-advertise-address 10.0.0.13 --apiserver-bind-port 6443 --kubernetes-version 1.19.0 --pod-network-cidr 10.244.0.0/16 --service-cidr 10.1.0.0/16  
```
Your Kubernetes control-plane has initialized successfully!
To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.0.13:6443 --token 6so4km.p13vr6rwpp33cwpk \
    --discovery-token-ca-cert-hash sha256:7ad8fa68caadf926fae196d5a6102849a2b312a74ca8bd8e42c02ac4dbe34daa
```
### 安装calico
保存离线镜像  
cat save-caclico-images.sh  
```
#!/bin/bash

images=(
typha:v3.10.4
cni:v3.10.4
cni:v3.10.4
pod2daemon-flexvol:v3.10.4
node:v3.10.4
kube-controllers:v3.10.4
)
for imageName in ${images[@]};
do
docker save -o `echo ${imageName}|awk -F ':' '{print $1}'`.tar docker.io/calico/${imageName}
done
```
安装上面描述的方法docker load 导入calico离线镜像  
启动calico 
kubectl apply -f https://docs.projectcalico.org/v3.10/manifests/calico-typha.yaml  
### 查看集群状态
kubectl get pod -n kube-system  
```
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-7854b85cf7-b7llz   1/1     Running   0          7h
calico-node-4tqfg                          1/1     Running   3          7h
calico-typha-849f7d5c9f-bpp4w              1/1     Running   0          7h
coredns-f9fd979d6-9rq4f                    1/1     Running   0          20h
coredns-f9fd979d6-ggc8j                    1/1     Running   0          20h
etcd-centos03                              1/1     Running   0          20h
kube-apiserver-centos03                    1/1     Running   0          20h
kube-controller-manager-centos03           1/1     Running   0          20h
kube-proxy-l9fvn                           1/1     Running   0          20h
kube-scheduler-centos03                    1/1     Running   0          20h
```
### 去除master污点
kubectl taint nodes centos03 node-role.kubernetes.io/master-
