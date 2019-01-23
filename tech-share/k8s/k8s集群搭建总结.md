# k8s集群搭建总结

> 使用kubeadm搭建高可用k8s集群，并编写ansible脚本方便以后进行自动化部署，目前k8s版本为1.13.1,参考[官方文档](https://kubernetes.io/docs/setup/independent/high-availabilit/)

## 准备工作

- 集群结构
- 节点规划

  ```yml
  haproxy:
  - 122.22.71.12
  - 122.22.71.13

  keepalived:
  - 122.22.71.12
  - 122.22.71.13
  - 122.22.71.100(vip)

  etcd:
  - 122.22.71.24
  - 122.22.71.25
  - 122.22.71.26

  master:
  - 122.22.71.12
  - 122.22.71.13

  nodes:
  - xx.xx.xx.xx
  ```

- 初始化环境

  1. 各个节点间网络连通
  2. 设置每个节点hostname
      ```shell
      hostnamectl set-hostname master-1
      ```
  3. 关闭swap(保证kubelet正常运行)

      ```shell
      swapoff -a
      sed -i 's/.*swap.*/#&/' /etc/fstab
      ```
  4. 关闭防火墙
      ```shell
      systemctl stop firewalld && systemctl disable firewalld
      ```
  5. 关闭selinux
      ```shell
      setenforce 0
      sed -i "s/^SELINUX\=enforcing/SELINUX\=disabled/g" /etc/selinux/config
      ```
  6. 设置内核参数
      ```shell
      echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.d/k8s.conf
      sysctl -p /etc/sysctl.d/k8s.conf
      ```
  7. 安装kubelet kubectl kubeadm

     添加kubernetes yum仓库
     ```shell
     cat > kubernetes.repo <<EOF
     [kubernetes]
     name=Kubernetes
     baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
     enabled=1
     gpgcheck=1
     repo_gpgcheck=1
     gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
     EOF
     ```

     执行yum安装
     ```shell
     yum install kubelet-1.13.1-0.x86_64 kubectl-1.13.1-0.x86_64 kubeadm-1.13.1-0.x86_64
     ```
     可以通过 `yum list kubelet --show-duplicates`查看已有版本。
  
   8. 安装容器运行时，推荐使用`docker`

   9. 导入kubernetes各组件的docker镜像
       ```yaml
       masters:
       - k8s.gcr.io/kube-apiserver:v1.13.1
       - k8s.gcr.io/kube-controller-manager:v1.13.1
       - k8s.gcr.io/kube-scheduler:v1.13.1
       - k8s.gcr.io/kube-proxy:v1.13.1
       - k8s.gcr.io/coredns:1.2.6
       - k8s.gcr.io/pause:3.1
       - quay.io/coreos/flannel:v0.10.0-amd64

       nodes:
       - k8s.gcr.io/kube-proxy:v1.13.1
       - k8s.gcr.io/pause:3.1
       - quay.io/coreos/flannel:v0.10.0-amd64
       ```

- 部署中间件
  
  - haproxy (为api做负载均衡，监听`4443`端口，将请求分发到masters的`6443`端口)
  - keepalived(vip `122.22.71.100`)
  - etcd


## 部署masters

- 部署第一个master
1. 添加kubeadm初始化配置文件
    ```shell
    cat > kubernetes-conf.yml << EOF
    apiVersion: kubeadm.k8s.io/v1beta1
    kind: ClusterConfiguration
    kubernetesVersion: v1.13.1
    apiServer:
      certSANs:
      - "122.22.71.100"
    controlPlaneEndpoint: "122.22.71.100:4443"
    etcd:
      external:
        endpoints:
        - "http://122.22.71.24:2379"
        - "http://122.22.71.25:2379"
        - "http://122.22.71.26:2379"
    
    networking:
      podSubnet: 10.244.0.0/16
    EOF
    ```

2. 执行初始化命令
    ```shell
    kubeadm  init --config kubernetes-config.yml
    ```
    执行成功后会出现类似，后面master及node加入集群都会用到

    ```shell
    kubeadm join 122.22.71.100:4443 --token kofqgw.2rr65q3dz3gwe5ky --discovery-token-ca-cert-hash sha256:2e39ac95d00434c1012a0a7555fdb86daac6614fbb78c4cc5a8a1b01a55f1954
    ```

3. 使当前用户可以使用kubectl命令
    ```shell
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

4. 安装网络插件 (这里使用的flannel)
    ```shell
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    ```
    这时候使用 `kubectl get node` 可以看到一个ready状态的master节点

- 安装其他master节点

1. 复制文件
   
   复制第一个master节点的 `/etc/kubernetes/pki` 及 `/etc/kubernetes/admin.conf` 到当前主机的对应路径。

2. 执行加入集群命令
    
    ```shell
    kubeadm join 122.22.71.100:4443 --token kofqgw.2rr65q3dz3gwe5ky --discovery-token-ca-cert-hash sha256:2e39ac95d00434c1012a0a7555fdb86daac6614fbb78c4cc5a8a1b01a55f1954 --experimental-control-plane
    ```
    对比node加入集群的命令多了`--experimental-control-plane`，这个参数在以后k8s版本可能会变化。

## 部署nodes

1. 执行加入集群命令

    ```shell
    kubeadm join 122.22.71.100:4443 --token kofqgw.2rr65q3dz3gwe5ky --discovery-token-ca-cert-hash sha256:2e39ac95d00434c1012a0a7555fdb86daac6614fbb78c4cc5a8a1b01a55f1954
    ```

## ansible脚本部署