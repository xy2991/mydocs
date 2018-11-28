# redis三主三从集群搭建手册

> 主要参照了[一篇文章](https://blog.csdn.net/men_wen/article/details/72853078)，但是使用了redis的docker镜像。

部署环境：

| ip | 端口|说明 |
|--|--|--|
|10.64.26.34|6397|slave|
|10.64.26.35|6397|slave|
|10.64.26.36|6397|slave|
|10.64.26.37|6397|master|
|10.64.26.38|6397|master|
|10.64.26.39|6397|master|

镜像：10.64.250.16/changan/redis:3-alpine

新建配置文件`mkdir /home/redis.d/conf/redis.conf`，六台主机配置文件一致

redis.conf:
```
port 6379
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 15000
```

容器启动命令：
```shell
docker run -d --network host --name redis-cluster \ 
-v /home/redis.d/data:/data \ 
-v /home/redis.d/conf/redis.conf:/usr/local/etc/redis/redis.conf \
10.64.250.16/changan/redis:3-alpine \ 
redis-server /usr/local/etc/redis/redis.conf
```
在任一主机执行命令添加节点
```shell
docker exec -it redis-cluster redis-cli cluster meet 10.64.26.xx 6379
```
_xx表示本机外的其他主机地址_

在主节点上执行添加slot脚本
```
/bin/bash slot_assign.sh 0 5461
```
_一共有16384个槽位，平均分配至三个主节点_

slot_assign.sh

```shell
#!/bin/bash

slot_s=$1
slot_e=$2

slot_assign()
  {   # use your cmd or func instead of sleep here. don't end with background(&)
      docker exec -i redis-m1 redis-cli cluster addslots $1
  }
  
concurrent()
 {   # from $1 to $2, (included $1,$2 itself), con-current $3 cmd
     start=$1 && end=$2 && cur_num=20
 
     # ff_file which is opened by fd 4 will be really removed after script stopped
     mkfifo   ./fifo.$$ &&  exec 4<> ./fifo.$$ && rm -f ./fifo.$$
 
     # initial fifo: write $cur_num line to $ff_file
     for ((i=$start; i<$cur_num+$start; i++)); do
         echo "init time add $i" >&4
     done
 
     for((i=$start; i<=$end; i++)); do
         read -u 4   # read from mkfifo file
         {   # REPLY is var for read
             echo -e "-- current loop: [cmd id: $i ; fifo id: $REPLY ]"
 
             slot_assign $i
             echo "real time add $(($i+$cur_num))"  1>&4 # write to $ff_file
         } & # & to backgroud each process in {}
     done
     wait    # wait all con-current cmd in { } been running over
 }

concurrent $slot_s $slot_e
```

然后查看节点
```shell
docker exec -it redis-cluster redis-cli cluster nodes
```
会看到类似下面的内容
```
47xxxxx 10.64.26.35:6379 master - 0 1526369727867 5 connected
52xxxxx 10.64.26.36:6379 master - 0 1526369731872 3 connected
e2xxxxx 10.64.26.37:6379 master - 0 1526369728868 0 connected 10923-16383
b3xxxxx 10.64.26.34:6379 master - 0 1526369729868 4 connected
43xxxxx 10.64.26.38:6379 master - 0 1526369730870 1 connected 5462-10922
b6xxxxx 10.64.26.39:6379 myself,master - 0 0 2 connected 0-5461
```
为每一个主节点添加一个从节点
```shell
docker exec -it redis-cluster redis-cli -h 10.64.26.34 -p 6379 cluster replicate e2xxxxx
```

添加完成后再次查看可以看到
```
47xxxxx 10.64.26.35:6379 slave 43xxxxx 0 1526369944208 5 connected
52xxxxx 10.64.26.36:6379 slave b6xxxxx 0 1526369947212 3 connected
e2xxxxx 10.64.26.37:6379 master - 0 1526369948213 0 connected 10923-16383
b3xxxxx 10.64.26.34:6379 slave e2xxxxx 0 1526369949214 4 connected
43xxxxx 10.64.26.38:6379 master - 0 1526369946210 1 connected 5462-10922
b6xxxxx 10.64.26.39:6379 myself,master - 0 0 2 connected 0-5461
```