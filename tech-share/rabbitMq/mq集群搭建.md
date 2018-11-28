# RabbitMq 集群搭建

部署环境

```yaml
host: 
- node1: 10.64.26.151
- node2: 10.64.26.152
- node3: 10.64.26.153

docker image: 10.64.250.16/library/rabbitmq:management 
```

在三个节点执行

```shell
node1=10.64.26.151
node2=10.64.26.152
node3=10.64.26.153

env="--restart=always -e RABBITMQ_DEFAULT_USER=rabbit -e RABBITMQ_DEFAULT_PASS=Rabbit2Wolf --add-host node1:$node1 --add-host node2:$node2 --add-host node3:$node3 -p 5671:5671 -p 5672:5672 -p 4369:4369 -p 15671:15671 -p 15672:15672 -p 25672:25672 --memory=2048M"
```

在node1执行

```shell
docker run -d -h=node1 --name node1 $env 10.64.250.16/library/rabbitmq:management
``` 

执行 `docker exec node1 cat ~/.erlang.cookie` 获得cookie类似如下字符串

```
TTPQCHPZTROYTGGTBCIK
```

在node2执行

```shell
cookie="TTPQCHPZTROYTGGTBCIK"

docker run -d -h=node2 --name node2 $env -e RABBITMQ_ERLANG_COOKIE=${cookie} 10.64.250.16/library/rabbitmq:management

docker exec node2 bash -c "rabbitmqctl stop_app && rabbitmqctl reset && rabbitmqctl join_cluster rabbit@node1 && rabbitmqctl start_app"
```

在node3执行

```shell
cookie="TTPQCHPZTROYTGGTBCIK"

docker run -d -h=node3 --name node3 $env -e RABBITMQ_ERLANG_COOKIE=${cookie} 10.64.250.16/library/rabbitmq:management

docker exec node3 bash -c "rabbitmqctl stop_app && rabbitmqctl reset && rabbitmqctl join_cluster rabbit@node1 && rabbitmqctl start_app"
```

注意：
需要给mq容器限制内存大小 `--memory=2048M`
镜像说明 [docker store](https://store.docker.com/images/rabbitmq)
