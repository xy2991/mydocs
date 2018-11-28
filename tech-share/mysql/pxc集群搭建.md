部署环境

```yaml
host: 
- node1: 10.64.26.151
- node2: 10.64.26.152
- node3: 10.64.26.153

docker image: 10.64.250.16/percona/percona-xtradb-cluster:5.7
```

在三个节点执行

```shell
node1=10.64.26.151
node2=10.64.26.152
node3=10.64.26.153

env="--restart=always --net=host -e TZ=Asia/Shanghai -e MYSQL_ROOT_PASSWORD=1qaz@WSX -e XTRABACKUP_PASSWORD=1qaz@WSX -e CLUSTER_NAME=mysqlcluster -v /u01/mysql:/var/lib/mysql"
```

在node1执行

```shell
docker run -d --name mysql -e CLUSTER_JOIN='' $env 10.64.250.16/percona/percona-xtradb-cluster:5.7
```

在node2执行

```shell
docker run -d --name mysql -e CLUSTER_JOIN="$node1" $env 10.64.250.16/percona/percona-xtradb-cluster:5.7
```

在node1执行

```shell
docker run -d --name mysql -e CLUSTER_JOIN="$node2" $env 10.64.250.16/percona/percona-xtradb-cluster:5.7
```