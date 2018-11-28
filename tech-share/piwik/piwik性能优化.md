# piwik性能优化

## 定时归档

由于使用的piwik的官方镜像，不能在容器内执行定时任务，可以在宿主机直接设置定时任务如下：

```
0 3 * * * /bin/sh /data/caec-piwik.sh 2>/dev/null
*/1 * * * * /opt/instlpackage_for7/start-agent.sh

1 0,6,12,18 * * * docker exec -i matomo /bin/sh -c 'php /var/www/html/console core:archive --url=https://tongji.changan.com.cn:8080/index.php' >> /home/piwik-archive.log
```

## 内存优化
修改 global.ini.php文件 内存配置：
```
minimum_memory_limit = 2048
minimum_memory_limit_when_archiving = 8196
```

修改后基本可以支持每日3w pv