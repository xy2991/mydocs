# 多主节点k8s集群创建

> 为了使k8s集群更加健壮可靠，消除单点故障，适应生产环境，需要创建多主节点集群。同时，在1.11版本中，kubeadm也提供了高可用集群部署的方式，使得创建变得更加容易。

---

tips:
  - 最好先[升级系统内核](https://blog.csdn.net/nciasd/article/details/51490146)至最新的[稳定版本](https://www.kernel.org/)
  - 本次安装参考[官网文档](https://v1-11.docs.kubernetes.io/docs/setup/independent/high-availability/)
  - 其他

---

### 环境
```yaml
hosts:
  k8s-m1: 10.64.26.20
  k8s-m2: 10.64.26.21
  k8s-m3: 10.64.26.22
  k8s-n1: 10.64.26.23
  k8s-n2: 10.64.26.24
  k8s-n3: 10.64.26.25

vip:
  api: 10.64.26.159

images:
  master:
  - 10.64.250.16/changan/keepalived:1.4.4
  - 10.64.250.16/changan/haproxy:1.7.9 
  - k8s.gcr.io/etcd-amd64:3.2.18
  - k8s.gcr.io/kube-apiserver-amd64:v1.11.1
  - k8s.gcr.io/kube-controller-manager-amd64:v1.11.1
  - k8s.gcr.io/kube-scheduler-amd64:v1.11.1
  - k8s.gcr.io/kube-proxy-amd64:v1.11.1
  - k8s.gcr.io/coredns:1.1.3 
  - k8s.gcr.io/pause:3.1
  - quay.io/coreos/flannel:v0.10.0-amd64
  worker:
  - k8s.gcr.io/kube-proxy-amd64:v1.11.1
  - k8s.gcr.io/pause:3.1
  - quay.io/coreos/flannel:v0.10.0-amd64
```

> tips: 这些镜像可以在墙外服务器上拉下来，使用`docker save`保存为tar文件，再推送到部署节点。

## 部署主节点


