# Gitlab CI 小结

>核心的想法是把项目构建成docker镜像，上传至镜像仓库，然后发布到主机上
构建和上传镜像就是ci，发布到主机就是cd


### gitlab-runner
gitlab-runner 使用rpm包安装，注册的时候excutor选择了docker，这样可以使用镜像作为打包发布的工具，避免了在gitlab-runner宿主机上部署过多的工具，也方便gitlab-runner迁移（拉取使用的镜像还是比较方便）。
注册后，需要修改 config.toml
```toml
[[runners]]
  name = "docker"
  url = "http://gitlab.example.com"
  token = "d84347f5afdb7b1838182d87cfdb1b"
  executor = "docker"
  [runners.docker]
    host = "tcp://10.64.xx.46:2376"
    tls_cert_path = "/home/gitlab-runner/certs"
    tls_verify = true
    image = "10.64.250.16/changan/gitlab-sonar-scanner:2.1.0"
    privileged = false
    disable_cache = false
    volumes = ["/cache","/var/run/docker.sock:/var/run/docker.sock","/home/gitlab-runner/.ssh:/root/.ssh"]
    pull_policy = "if-not-present"
    shm_size = 0
  [runners.cache]
```
  
- *tls_cert_path*： 由于docker后端http接口开启了tls验证，需要指明tls认证文件路径
- *volume*：
  - 将/var/run/docker.sock映射进去，就可以使用docker拉取的镜像
  - 将/home/gitlab-runner/.ssh映射进去，可以使用gitlab-runner用户的ssh私钥
- *pull_policy*： 设置镜像拉取策略，默认'总是拉取'

### 作为工具的镜像

由于需要ci的项目有spring boot框架和vuejs框架的项目，于是就build了两个工具镜像

docker build -f dockerfile -t gradle:dind .

```dockerfile
FROM docker.io/gradle:4.7.0-jdk8-alpine

USER root

RUN apk add --no-cache docker
```

docker build -f dockerfile -t node:dind .

```dockerfile
FROM docker.io/node:8-alpine

USER root

RUN apk add --no-cache docker
```

发布的时候，用到了docker提供的api（python），所以基于python镜像，打包了一个发布用的工具镜像

docker build -f ./dockerfile -t python:deploy .

```dockerfile
FROM docker.io/python:2.7-alpine

USER root

RUN apk add --no-cache git\
    && apk add --no-cache openssh\
    && pip install docker
```

### .gitlab_ci.yml文件

集成、发布的流程

```yaml
variables:
    SERVICE: consult
    IMG_NAME: 10.64.250.16/titanotp/${SERVICE}:${CI_COMMIT_REF_SLUG}.${CI_PIPELINE_ID}
    
cache:
  paths:
    - build

stages:
  - build
  - ship
  - deploy

build:
  tags:
    - gradle_v4
  image: gradle:dind
  stage: build
  script:
  - gradle build -x test
  
ship:
  tags:
    - gradle_v4
  stage: ship
  image: gradle:dind
  script:
  - ls -l build/libs
  - docker build -f dockerfile -t ${IMG_NAME} .
  - docker login 10.64.250.16 -u admin -p KtmAdv^1290
  - docker push ${IMG_NAME}
  - docker rmi ${IMG_NAME}
  
deploy:
  tags:
    - docker
  stage: deploy
  image: python:deploy
  variables:
    CD_REPO: ssh://git@git.changan.com:122/titanotp/CD_pyScript.git
    HOSTS: "10.64.26.41,10.64.26.42"
  script:
  - echo ${IMG_NAME}
  - git clone ${CD_REPO}
  - cd CD_pyScript
  - python  cd.py -o ${HOSTS} -s ${SERVICE} -i ${IMG_NAME}
  when: manual
```

#### 发布脚本
在delploy的任务中，拉取了CD_pyScript仓库，目录结构为
```yaml
certs.d
  - 10.64.26.41
    - ca.pem
    - cert.pem
    - key.pem
  - 10.64.26.42
    - ca.pem
    - cert.pem
    - key.pem
compose.d
  - consult.json
cd.py
```
cert.d 目录下保存的是各个主机上docker damon的http接口认证文件

compose.d 则保存了各个服务的容器配置，后面就会提到

在上面deploy任务中，执行了cd.py脚本

```python
# coding=utf-8
import docker
import argparse
import sys
import json


class DeploymentClass(object):
    def __init__(self, host, service, image):
        self.host = host
        self.service = service
        self.image = image

    def get_client(self):
        #    global client
        cert_path = "./certs.d/" + self.host
        envs = {
            'DOCKER_HOST': 'https://' + self.host + ':2376',
            'DOCKER_TLS_VERIFY': cert_path,
            'DOCKER_CERT_PATH': cert_path
        }
        client = docker.from_env(environment=envs)
        return client

    def get_depoly_info(self):
        json_file = './compose.d/' + self.service + '.json'
        with open(json_file) as f:
            data = json.load(f)
            kwargs = data[self.host]
        return kwargs

    def pull_image(self):
        client = self.get_client()
        try:
            client.login(username='ichangan', password='Ichangan123', registry='10.64.250.16/titanotp')
            client.images.pull(self.image)
        except docker.errors.APIError:
            # print docker.errors.APIError
            print "pull image error. Image:" + self.image + " may not exist, or check the disk space."
            sys.exit(1)
        else:
            print "pull image" + self.image + " succeed."

    def container_remove(self):
        client = self.get_client()
        info = self.get_depoly_info()
        try:
            container = client.containers.get(info['name'])
            if container.status == "running":
                try:
                    container.stop()
                except docker.errors.APIError:
                    print "The container stops failing"
                    sys.exit(97)
                else:
                    print "The container has stopped"
            try:
                rm_args = {'force': True}
                container.remove(**rm_args)
            except docker.errors.APIError:
                print "delete container failed"
                #        sys.exit(95)
            else:
                print "delete container: " + info['name'] + " succeed"
        except docker.errors.NotFound:
            print "container not found."
            pass
            # sys.exit(96)
        except docker.errors.APIError:
            print "Failed to get container information."

    def container_run(self):
        client = self.get_client()
        info = self.get_depoly_info()
        try:
            self.pull_image()
            client.containers.run(self.image,  **info)
        except docker.errors.ImageNotFound:
            print "image not found"
            sys.exit(98)
        except docker.errors.APIError, e:
            print "Container creation failed"
            print str(e)
            sys.exit(99)
        else:
            print "The container: " + info['name'] + " runs successfully."

    def clean_old_image(self):
        client = self.get_client()
        image_name = self.image.split(':', 1)[0]
        image_tag = self.image.split(':', 1)[1]
        container_images = []
        print "checking image:" + image_name
        try:
            image_list = client.images.list()  # 列出所有的镜像
            container_list = client.containers.list()  # 只会列出正在使用的容器
            for c in container_list:
                container_image = c.attrs['Config']['Image']
                if container_image not in container_images:
                    container_images.append(container_image)
            for i in image_list:
                checking_image_name = i.tags[0].split(':', 1)[0]
                checking_image_tag = i.tags[0].split(':', 1)[1]
                if checking_image_name == image_name and checking_image_tag != image_tag:
                    image_to_remove = i.tags[0]
                    if image_to_remove not in container_images:
                        print "removing: " + image_to_remove
                        client.images.remove(image_to_remove, {"force": True})
        except docker.errors.APIError:
            print "Failed to clean " + self.service + "'s redandent images"
            #        sys.exit(95)
            pass
        except IndexError:
            print "check the images on this host,there maybe some images with <none> tag"
        else:
            print "Successfully clean the redandent images"

    def exec_deploy(self):
        self.container_remove()
        self.container_run()
        self.clean_old_image()


def get_args():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('--hosts', '-o', required="true",
                        help='target ip address or hostname. Example: 10.64.13.82')
    parser.add_argument('--service', '-s', required="true",
                        help='service name. Example: member-service')
    parser.add_argument('--image', '-i', required="true",
                        help='tag name. Example: 10.64.250.16/titanotp/consult:master.134')
    return parser.parse_args()


def main():
    args = get_args()
    hosts = args.hosts.split(',')
    service = args.service
    image = args.image
    print(hosts, service, image)
    for host in hosts:
        job = DeploymentClass(host, service, image)
        job.exec_deploy()


if __name__ == '__main__':
    main()
```
执行该脚本的时候，需要传入
- *HOSTS*：发布的host ip地址，以逗号分隔多个ip
- *SERVICE*：发布的服务名称
- *IMG_NAME*：ci时构建的镜像

脚本会根据 SERVICE的值去获取一个json文件，该json文件中是[容器的配置](https://docker-py.readthedocs.io/en/stable/containers.html)

consult.json

```json
{
	"10.64.26.41": {
        "name": "consult",
        "detach": true,
        "network_mode": "default",
        "privileged": true,
        "log_config": {
            "type": "journald"
        },
        "restart_policy": {
            "Name": "always"
        },
        "ports": {
            "8080/tcp": "8080"
        },
        "environment": {
            "PRO_IP": "10.64.26.41",
            "PRO_ENV": "prod",
            "PRO_PORT":"8080",
            "spring.profiles.active": "prod"
        }
    },
    "10.64.26.42": {
        "name": "consult",
        "detach": true,
        "network_mode": "default",
        "privileged": true,
        "log_config": {
            "type": "journald"
        },
        "restart_policy": {
            "Name": "always"
        },
        "ports": {
            "8080/tcp": "8080"
        },
        "environment": {
            "PRO_IP": "10.64.26.42",
            "PRO_ENV": "prod",
            "PRO_PORT":"8080",
            "spring.profiles.active": "prod"
        }
    }
    
}
```

现在只需要将.gitlab_ci.yml文件放入项目最外层目录，每次上传代码时，都会进行构建
