# kubeadm 简易搭建k8s

> kubeadm 可以较为方便地建起一个k8s集群，但是也有一些采坑的地方，记录一下

### 环境：

```yml
hosts:
  OS: CentOS Linux release 7.3.1611 (Core)
  name:
    - k8s-m1: 10.64.26.26
    - k8s-n1: 10.64.26.29 
    - k8s-n2: 10.64.26.30
kubernets: v1.10.0
docker: v1.13.1
flannel: v0.10.0
```

### 准备工作：

- __关闭防火墙:__
```shell
systemctl stop firewalld && systemctl disable firewalld
```

- __关闭selinux:__
```shell
setenforce 0 && sed -i "s/^SELINUX\=enforcing/SELINUX\=disabled/g" /etc/selinux/config
```

- __关闭swap:__
```shell
swapoff -a && sed -i 's/.*swap.*/#&/' /etc/fstab
```

- __设定/etc/hosts解析集群主机:__
```shell
cat <<EOF>> /etc/hosts
10.64.26.26 k8s-m1
10.64.26.29 k8s-n1
10.64.26.30 k8s-n2
EOF
```

- __设定主机名称:__
```shell
hostnamectl set-hostname k8s-m1 (主机重启后生效)
```

- __设置kernel参数__
```shell
cat <<EOF> /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
vm.swappiness=0
EOF
sysctl -p /etc/sysctl.d/k8s.conf
```

- __设置docker网桥mtu:__
```shell
ip link set dev docker0 mtu 1450
vi /etc/docker/daemon.json
{
    "mtu": 1450,
     ...
}
```

- __设置kubernets yum源:__
```shell
cat <<EOF> /etc/yum.repos.d/k8s.repo
[kubernetes]
name=Kubernetes
baseurl=http://172.16.1.188:8088/repository/yum-k8s-proxy/repos/kubernetes-el7-x86_64/
enabled=1
EOF
```

### 部署k8s

- __安装kubeadm和相关工具包:__
```shell
yum install -y kubeadm-1.10.0-0.x86_64 kubelet-1.10.0-0.x86_64 kubernetes-cni-0.6.0-0.x86_64 kubectl-1.10.0-0.x86_64
(worker节点不需要安装kubectl)
```

- __获取k8s相关镜像:__
```shell
k8s.gcr.io/kube-proxy-amd64:v1.10.0
k8s.gcr.io/kube-apiserver-amd64:v1.10.0
k8s.gcr.io/kube-controller-manager-amd64:v1.10.0
k8s.gcr.io/kube-scheduler-amd64:v1.10.0
k8s.gcr.io/etcd-amd64:3.1.12
k8s.gcr.io/kubernetes-dashboard-amd64:v1.8.3
quay.io/coreos/flannel:v0.10.0-amd64
k8s.gcr.io/k8s-dns-dnsmasq-nanny-amd64:1.14.8
k8s.gcr.io/k8s-dns-sidecar-amd64:1.14.8
k8s.gcr.io/k8s-dns-kube-dns-amd64:1.14.8
k8s.gcr.io/pause-amd64:3.1
10.64.250.16/changan/heapster-amd64:v1.4.2
```

- __初始化安装K8S Master:__
```shell
kubeadm init --kubernetes-version=v1.10.0 --pod-network-cidr=10.244.0.0/16
```

命令执行成功后，会出现类似
```shell
To start using your cluster, you need to run the following as a regular user:
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/
You can now join any number of machines by running the following on each node
as root:
  kubeadm join 10.64.26.26:6443 --token thczis.64adx0imeuhu23xv --discovery-token-ca-cert-hash sha256:fa7b11bb569493fd44554aab0afe55a4c051cccc492dbdfafae6efeb6ffa80e6
```
最后一行命令会用于节点加入。可以通过在master节点执行`kubeadm token list`查看token，这个token有效期24h。

根据提示，使用k8s集群前还需要执行
```shell
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
并为集群部署pod网络

- __部署flannel网络:__
```shell
mkdir -p /etc/cni/net.d/
cat <<EOF> /etc/cni/net.d/10-flannel.conf
{
  "name": "cbr0",
  "type": "flannel",
  "delegate": {
    "isDefaultGateway": true
  }
}
EOF
mkdir /usr/share/oci-umount/oci-umount.d -p
mkdir /run/flannel/
cat <<EOF> /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.1.0/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF
kubectl apply -f kube-flannel.yml
```
kube-flannel.yml文件可以从[网上](https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml)获取

- __添加worker节点:__

在worker节点执行
```shell
 kubeadm join 10.64.26.26:6443 --token thczis.64adx0imeuhu23xv --discovery-token-ca-cert-hash sha256:fa7b11bb569493fd44554aab0afe55a4c051cccc492dbdfafae6efeb6ffa80e6
```

- __验证集群是否成功:__

```shell
# 查看节点状态
kubectl get nodes
# 查看pods状态
kubectl get pods --all-namespaces
# 查看K8S集群状态
kubectl get cs
```

### 遇到的问题

- __关于cgroup__

在执行kubeadm init 之后，执行`systemctl status kubectl`查看kubectl状态发现报错
```
"/system.slice/kubelet.service": failed to get cgroup stats for "/system.slice/kubelet.service": failed to get container info for "/system.slice/kubelet.service": unknown container "/system.slice/kubelet.service"
```
在stackoverflow上找到了[解决的方法](https://stackoverflow.com/questions/46726216/kubelet-fails-to-get-cgroup-stats-for-docker-and-kubelet-services)，即在`/etc/systemd/system/kubelet.service.d/10-kubeadm.conf`添加启动参数
```
--runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice
```

- __关于iptables__

部署过flannel之后，iptables会加入一些配置，并添加flannel和cni的网桥，可以直接通过`reboot`解决

也可以执行
```
systemctl restart firewalld && systemctl stop firewalld
```
恢复iptables，然后通过`brctl`删除网桥

