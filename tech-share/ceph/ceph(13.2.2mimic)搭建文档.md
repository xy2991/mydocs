# ceph(13.2.2mimic)搭建文档

> ceph 是一个广为使用的分布式存储系统，这里使用ceph-deploy进行部署。参考[官方文档](http://docs.ceph.com/docs/master/start/)

### 环境

```yaml
admin: 192.168.186.156
node1: 192.168.186.158
node2: 192.168.186.159
node3: 192.168.186.160
```
> 会在admin节点上对其他节点进行部署操作。

### 准备工作


- 升级内核(每个节点)

1. 执行`uname -r`查看内核版本，如不符合[推荐内核版本](http://docs.ceph.com/docs/master/start/os-recommendations/)，可以按照以下步骤升级。
2. [参考文档](https://blog.csdn.net/nciasd/article/details/51490146)

- 写入/etc/hosts(每个节点)
    
    ```
    192.168.186.156  admin
    192.168.186.158  node1
    192.168.186.159  node2
    192.168.186.160  node3
    ```

- 安装ceph-deploy(仅admin节点)
  
1. 添加yum源，写入ceph-deploy.repo
    ```
    [ceph-noarch]
    name=Ceph noarch packages
    baseurl=https://download.ceph.com/rpm-{ceph-stable-release}/el7/noarch
    enabled=1
    gpgcheck=1
    type=rpm-md
    gpgkey=https://download.ceph.com/keys/release.asc
    ```
2. 执行 `yum install ceph-deploy`

- 安装时间同步工具(每个节点)

1. 这里推荐chrony，执行`yum install chrony && systemctl enable chronyd`

- 创建ceph用户(每个节点)

1. 创建新用户
  
    ```shell
    sudo useradd -d /home/cephuser -m cephuser
    sudo passwd cephuser
    ```
2. 赋予用户sudo权限
   
   ```
   echo "cephuser ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephuser
   sudo chmod 0440 /etc/sudoers.d/cephuser
   ```

- admin节点免密登录其他节点

1. 为cephuser用户生成ssh秘钥

    ```shell
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
    cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

    ssh-copy-id cephuser@node1
    ssh-copy-id cephuser@node2
    ssh-copy-id cephuser@node3
    ```

- 关闭防火墙及selinux

    ```
    systemctl stop firewalld && setenforce 0

    永久修改selinux，/etc/selinux/config中改为`SELINUX=disabled`
    ```

- 确保 包管理工具已经安装了priority/preferences包并启用

    ```
    yum install yum-plugin-priorities
    ```

### 新建存储集群

1. 在admin节点，切换为cephuser，在其主目录下创建目录并进入
   ```
   mkdir my-cluster && cd my-cluster
   ```

2. 创建集群 
   ```
   ceph-deploy new node1 node2 node3
   ```
   执行后会生成新集群的ceph.conf、ceph.mon.keyring和log文件。

3. 安装ceph包 
   ```
   ceph-deploy install node1 node2 node3
   ```
   这一步有几次报错yum源没有设置优先级，可以手动写入`/etc/yum.repos.d/ceph.repo`

    ```
    [Ceph]
    name=Ceph packages for $basearch
    baseurl=http://download.ceph.com/rpm-mimic/el7/$basearch
    enabled=1
    gpgcheck=1
    type=rpm-md
    gpgkey=https://download.ceph.com/keys/release.asc
    priority=1

    [Ceph-noarch]
    name=Ceph noarch packages
    baseurl=http://download.ceph.com/rpm-mimic/el7/noarch
    enabled=1
    gpgcheck=1
    type=rpm-md
    gpgkey=https://download.ceph.com/keys/release.asc
    priority=1

    [ceph-source]
    name=Ceph source packages
    baseurl=http://download.ceph.com/rpm-mimic/el7/SRPMS
    enabled=1
    gpgcheck=1
    type=rpm-md
    gpgkey=https://download.ceph.com/keys/release.asc
    priority=1`
    ```

4. 部署monitor并收集keys
    ```
    ceph-deploy mon create-initial
    ```
    执行后在目录下应该会有以下keyrings:
    ```
    ceph.client.admin.keyring
    ceph.bootstrap-mgr.keyring
    ceph.bootstrap-osd.keyring
    ceph.bootstrap-mds.keyring
    ceph.bootstrap-rgw.keyring
    ceph.bootstrap-rbd.keyring
    ceph.bootstrap-rbd-mirror.keyring
    ```
5. 将ceph.client.admin.keyring 和ceph.conf复制到所有节点，以便在各个节点可以使用ceph命令
    ```
    ceph-deploy admin node1 node2 node3
    ```

6. 部署manager
    ```
    ceph-deploy mgr create node1 node2 node3
    ```

7. 添加osd（这里luminous和mimic是有区别的，可以查看[luminous文档](http://docs.ceph.com/docs/luminous/start/quick-ceph-deploy/#create-a-cluster)）

    ```shell
    ceph-deploy osd create --data /dev/sdb node1
    ceph-deploy osd create --data /dev/sdb node2
    ceph-deploy osd create --data /dev/sdb node3
    ```

8. 检查ceph集群健康
    ```
    ssh node1 sudo ceph health
    ssh node1 sudo ceph -s
    ```

### 使用cephFS

1. 新建mds

    ```
    ceph-deploy mds create node1
    ```
    这个命令等同于`ceph-deploy mds create node1:node1`,之前碰到过执行上面命令不能创建mds的情况，可以试一下下面这个命令并把冒号后面`node1`改为其他名字。

2. 查看mds状态

    ```
    ssh node1 sudo ceph mds stat
    ```
    这时候应该可以看到类似`.1 up:standby`的输出，如果没有看到，可以再执行一下
    ```
    ssh node1 sudo ps -ef|grep ceph-mds
    ```
    确认有没有mds服务启动。

3. 创建cephFS(在ceph节点上执行，比如node1)

    ```
    ceph osd pool create cephfs_data <pg_num>
    ceph osd pool create cephfs_metadata <pg_num>
    ceph fs new <fs_name> cephfs_metadata cephfs_data
    ```
    pg_num 是指 placement groups的个数，对于ceph存储集群是一个很重要的配置，可以参考[setting the number of placement groups](http://docs.ceph.com/docs/master/rados/operations/placement-groups/)

4. 获取admin key

    ```
    cat ceph.client.admin.keyring
    ```
    可以看到类似
    ```
    [client.admin]
    key = AQCj2YpRiAe6CxAA7/ETt7Hcl9IyxyYciVs47w==
    ```
    在挂载的时候，我们回需要key值`AQCj2YpRiAe6CxAA7/ETt7Hcl9IyxyYciVs47w==`

5. 挂载cephFS

    - 首先挂载主机的内核也需要[符合要求](http://docs.ceph.com/docs/master/start/os-recommendations/)，另外，也需要安装ceph包，这里可以参考前文内容。
    - 内核驱动方式挂载

        ```
        mount -t ceph node1,node2,node3:6789:/ /mnt/mycephfs -o name=admin,secret=AQCj2YpRiAe6CxAA7/ETt7Hcl9IyxyYciVs47w==
        ```

6. ceph 的admin key 也可以写到文件中来引用，另外，ceph提供了FUSE的方式挂载目录，详细可以查看[官网](http://docs.ceph.com/docs/master/start/quick-cephfs/#create-a-secret-file)