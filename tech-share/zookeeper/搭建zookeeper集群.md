### 环境

```
hosts:
  zoo1: 10.64.26.31
  zoo2: 10.64.26.32
  zoo3: 10.64.26.33

zookeeper.version: 3.4.13
```

### 命令

以zoo1节点为例，其它节点稍有修改

```shell
docker run -d --restart always --hostname zoo1 --name zoo1 \
--add-host zoo1:10.64.26.31 --add-host zoo2:10.64.26.32 --add-host zoo3:10.64.26.33 \
--network host \
-e ZOO_MY_ID=1 -e ZOO_SERVERS="server.1=0.0.0.0:2888:3888 server.2=zoo2:2888:3888 server.3=zoo3:2888:3888" \
10.64.250.16/changan/zookeeper:3.4.13
```
