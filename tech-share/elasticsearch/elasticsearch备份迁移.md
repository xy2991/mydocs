# elasticsearch 备份迁移

环境：
```
src-hosts:
10.64.26.105:9200
10.64.26.106:9200
10.64.26.107:9200

dest-hosts:
10.64.19.154:9200
10.64.19.155:9200
10.64.19.156:9200

elasticsearch镜像: 
10.64.250.16/changan/elasticsearch:2.3.3

```

### 创建nfs

elasticsearch 备份是需要在每个节点都有一个共享文件系统，这里使用的nfs。

在三台主机上安装nfs，执行

```
yum install nfs-utils -y
```
在10.64.26.105的创建一个目录，
```
mkdir /u01/elasticsearch/data/mnt
```
并在/etc/exports文件中配置其作为共享目录。

/etc/exports：
```
/u01/elasticsearch/data/mnt 10.64.26.0/24(rw,no_root_squash,no_all_squash,sync,no_wdelay)
```

启动nfs服务，并创建开机启动：
```
systemctl start nfs
systemctl enable nfs
```

将该目录挂载到另外两台主机

```
mount -t nfs 10.64.26.105:/u01/elasticsearch/data/mnt /u01/elasticsearch/data/mnt
```

### 生成elasticsearch索引快照
在elasticsearch配置文件elasticsearch.yml添加仓库路径`path.repo: ["/u01/elasticsearch/data/mnt/es_backup"]`

__创建仓库__
```
curl -X PUT http://10.64.26.105:9200/_snapshot/backups -d '{"type": "fs","settings": {"location": "/u01/elasticsearch/data/mnt/es_backup/back_test","compress": true}}'
```

__获取索引快照__

获取所有索引快照：
```
curl -X PUT http://10.64.26.105:9200/_snapshot/backups/snapshot_1
```

获取指定索引快照：
```
curl -X PUT http://10.64.26.105:9200/_snapshot/backups/snapshot_2 -d '{"indices": "index_1,index_2"}'
```

__查看索引快照__

查看所有快照
```
curl -X GET http://10.64.26.105:9200/_snapshot/backups/_all
```

查看指定快照
```
curl -X GET http://10.64.26.105:9200/_snapshot/backups/snapshot_2
```
关于更多的快照操作，可以查看[官网](https://www.elastic.co/guide/en/elasticsearch/guide/current/backing-up-your-cluster.html#_listing_information_about_snapshots)

### 从快照恢复

将之前创建的共享目录挂载到 目标es集群主机的路径下

```
mount -t nfs 10.64.26.105:/u01/elasticsearch/data/mnt /u01/elasticsearch/data/mnt
```

__在目标es集群创建仓库__

location指定为刚才挂载的路径，仓库名可以和之前不同，比如这里仓库名为`backups_dest`
```
curl -X PUT http://10.64.19.154:9200/_snapshot/backups_dest -d '{"type": "fs","settings": {"location": "/u01/elasticsearch/data/mnt/es_backup/back_test","compress": true}}'
```

这时新建仓库下的已存在之前的快照，名称也与创建时相同，恢复数据时执行命令
```
curl -X POST http://10.64.26.105:9200/_snapshot/backups_dest/snapshot_1/_restore
```

可以通过`curl -X GET http://10.64.26.105:9200/_recovery/` 查看数据恢复情况。





