# gitlab搭建文档

> 使用ldap进行登录验证

环境：

```
host：10.64.2x.xx
操作系统：CentOS Linux release 7.0.1406
docker版本：17.05.0-ce
gitlab镜像：gitlab/gitlab-ce:10.1.0
ldap镜像：osixia/openldap:1.1.10
ldapadmin镜像：osixia/phpldapadmin:0.7.1
```

### 搭建ldap

直接使用osixia/openldap的镜像，省去很多配置工作

执行命令：
```
docker run --name ldap-service -p 389:389 -p 636:636 --volume /home/data/slapd/database:/var/lib/ldap --volume /home/data/slapd/config:/etc/ldap/slapd.d --detach osixia/openldap:1.1.10
```

这个镜像支持通过一些有用的环境变量，对ldap进行配置

```
LDAP_ORGANISATION: Organisation name. Defaults to Example Inc.
LDAP_DOMAIN: Ldap domain. Defaults to example.org
LDAP_BASE_DN: Ldap base DN. If empty automatically set from LDAP_DOMAIN value. Defaults to (empty)
LDAP_ADMIN_PASSWORD Ldap Admin password. Defaults to admin
LDAP_CONFIG_PASSWORD Ldap Config password. Defaults to config
LDAP_READONLY_USER Add a read only user. Defaults to false
LDAP_READONLY_USER_USERNAME Read only user username. Defaults to readonly
LDAP_READONLY_USER_PASSWORD Read only user password. Defaults to readonly
LDAP_RFC2307BIS_SCHEMA Use rfc2307bis schema instead of nis schema. Defaults to false

（eg:  --env LDAP_READONLY_USER=true）
```

并且可以通过yaml文件进行设置
参数格式：

```
LDAP_ADMIN_PASSWORD: 123456

```
通过文件挂载方式导入
`--volume /data/ldap/environment:/container/environment/01-custom` 或
`--volume /data/ldap/environment/my-env.yaml:/container/environment/01-custom/env.yaml`

注意：
名为`*.startup.yaml`的文件在容器生成后会被删除，可以将密码等保密信息放入这里；
容器中默认有`/container/environment/99-custom`路径，这里的数字99的意思类似于优先级，数值越小，优先级越高，所以`01-custom`路径里的参数文件会有更高的优先级

参考：[https://github.com/osixia/docker-openldap](https://github.com/osixia/docker-openldap)

### 搭建 phpldapadmin（非必要，可以另外找客户端，而且该客户端有中文显示的问题）

执行命令：
```
docker run -p 6443:443 --env PHPLDAPADMIN_LDAP_HOSTS=ldap.example.com --name phpldapadmin-service --hostname phpldapadmin-service --link ldap-service:ldap-host --env PHPLDAPADMIN_LDAP_HOSTS=ldap-host --detach osixia/phpldapadmin:0.7.1
```

访问方式
```
Addr: https://10.64.2x.xx:6443/index.php
Login DN: cn=admin,dc=example,dc=org"
Password: admin
```

### 搭建gitlab

使用官方gitlab镜像非常方便，执行命令：
```
docker run --detach --hostname gitlab.example.com --env GITLAB_OMNIBUS_CONFIG="external_url 'http://10.64.1x.xx'; gitlab_rails['gitlab_shell_ssh_portv'] = '122'" --publish 443:443 --publish 80:80 --publish 122:22 --name gitlab-ce --restart always --volume /u01/gitlab/config:/etc/gitlab --volume /u01/gitlab/logs:/var/log/gitlab --volume /u01/gitlab/data:/var/opt/gitlab 10.64.250.16/changan/gitlab-ce:10.1.0
```

修改配置文件/u01/gitlab/config/gitlab.rb，添加内容：
```
external_url 'http://git.changan.com'
gitlab_rails['gitlab_default_can_create_group'] = false
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
  main: # 'main' is the GitLab 'provider ID' of this LDAP server
    label: 'LDAP'
    host: '10.64.2x.xx'
    port: 389
    uid: 'cn'
    bind_dn: 'cn=admin,dc=example,dc=org'
    password: 'admin'
    encryption: 'plain' # "start_tls" or "simple_tls" or "plain"
    active_directory: true
    allow_username_or_email_login: true
    block_auto_created_users: false
    base: 'dc=example,dc=org'
    user_filter: ''
    attributes:
      username: ['uid', 'userid', 'sAMAccountName']
      email:    ['mail', 'email', 'userPrincipalName']
      name:       'cn'
      first_name: 'givenName'
      last_name:  'sn'
EOS
gitlab_rails['gitlab_shell_ssh_port'] = 122
```
然后进入gitlab容器执行`gitlab-ctl reconfigure`

参考:
https://docs.gitlab.com/omnibus/docker/
https://docs.gitlab.com/ee/administration/auth/ldap.html
