# 脚本说明

- [createCert.sh](./createCert.sh): 用于生成自签ssl证书，haproxy配置可参考[示例](./intro-example/haproxy.cfg)
- [dockerEvn.sh](./dockerEvn.sh): 初始化docker配置，开放受保护2376端口，复制认证文件到jenkins等
- [img-del5.sh](./img-del5.sh): 删除冗余镜像（同仓库保留最近两个版本）
- [part.sh](./part.sh): 大容量磁盘分区时用过，可作参考。 