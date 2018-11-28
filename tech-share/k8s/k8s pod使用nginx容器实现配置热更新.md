# Pod热重载配置实践

> 通过configmap可以方便的修改应用的配置，但是对于有些应用本身可能还是需要重启才能更新配置，现在就需要修改完成后，自动实现重启pod中的应用container。

## 基本思路

在pod中增加一个监控配置的容器，并在该容器中启动一个web页面，同时在应用容器配置livenessprobe，监听该页面。当配置监控容器中检查到配置改变时，关闭web页面，而应用容器liveness fail掉就会重启应用容器。

## 配置监控容器

__作用:__ 提供一个web页面，供应用容器做存活检测，并检测配置是否改变，检测到改变时，便停止该web页面。

__镜像文件:__ 

```yaml
Dockerfile: |
  FROM nginx:1.15-alpine
  COPY ./checkConf.sh /home/
  COPY ./start.sh /home/
  COPY ./default.conf /etc/nginx/conf.d/default.conf
  RUN  chmod +x /home/start.sh && chmod +x /home/checkConf.sh
  EXPOSE 8021
  CMD ["/bin/sh","-c","/home/start.sh"]

checkConf.sh: |
  #!/bin/sh
  while true                                                           
  do
    sum_now=$(md5sum /home/config.d/${CONFIG_CHK_FILE}| awk '{print $1}')
  if [[ ${sum_now}x != $(cat /home/sumValue)x ]];then
    killall -9 nginx
  fi
  sleep 5
  done

start.sh: |
  #!/bin/sh
  md5sum /home/config.d/${CONFIG_CHK_FILE} | awk '{print $1}' > /home/sumValue
  nginx -g 'daemon off;' &
  /bin/sh -c /home/checkConf.sh

```

__注意:__ 这个容器本身也需要在应用容器重启之后重新启动。