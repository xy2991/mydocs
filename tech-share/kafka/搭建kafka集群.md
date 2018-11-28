### 环境

```
hosts:
- 10.64.26.31
- 10.64.26.32
- 10.64.26.33

kafka.version: 2.0.0
```

### 命令

以31节点为例，其它节点修改容器环境变量`KAFKA_ADVERTISED_HOST_NAME`

```shell
docker run -d --restart always --name kafka -p 9092:9092 -e KAFKA_ADVERTISED_HOST_NAME=10.64.26.31 -e KAFKA_ADVERTISED_PORT=9092 -e KAFKA_ZOOKEEPER_CONNECT="10.64.26.31:2181,10.64.26.32:2181,10.64.26.33:2181" -v /var/run/docker.sock:/var/run/docker.sock 10.64.250.16/changan/kafka:2.11-2.0.0
```

### 注意

- kafka集群需要先搭建zookeeper集群
