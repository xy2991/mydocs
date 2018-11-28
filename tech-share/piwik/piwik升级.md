### 环境

```
host: 10.64.18.211
```

### 命令

```
docker run -d --restart always --name matomo -p 80:80 -v /u01/piwik-config:/var/www/html/config 10.64.250.16/changan/matomo:3.5-apache
```

### 注意

- 隐私保护需要关闭