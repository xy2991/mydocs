### 环境

```
host:
- 10.64.26.37
- 10.64.26.38
- 10.64.26.39

es.version: 5.6
```

### 命令

```
docker run --name es --network host -d --restart=always --privileged -e ES_HEAP_SIZE=16g -v /home/elasticsearch.d/data:/var/lib/elasticsearch  -v /home/elasticsearch.d/logs:/var/log/elasticsearch -v /home/elasticsearch.d/conf.d/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml 10.64.250.16/changan/elasticsearch:5.6.10
```

### 配置文件

elasticsearch.yml

```
cluster.name: titan-test-es
node.name: titan-test-es-1
path:
  data: /var/lib/elasticsearch
  logs: /var/log/elasticsearch
network.host: 10.64.26.37
http.cors.enabled: true
http.cors.allow-origin: "*"
discovery.zen.minimum_master_nodes: 2
discovery.zen.ping.unicast.hosts:
- 10.64.26.37:9300
- 10.64.26.38:9300 
- 10.64.26.39:9300
```

### 注意

- 先创建`/home/elasticsearch.d/data`目录并赋权为`777`
- 配置jvm内存堆栈大小: 设置环境变量ES_HEAP_SIZE=16g,不要超过32g
- 关闭swap: `swapoff -a` 并在/etc/fstab中注释掉swap挂载
- 设置系统参数: vm.max_map_count=262144