## gitlab集成sonarqube代码检查 ##
### gitlab-runner 安装
gitlab-runner 提供多种[安装方式](https://docs.gitlab.com/runner/install/index.html)，这里使用rpm包进项[安装](https://packages.gitlab.com/runner/gitlab-runner)
### gitlab-runner 注册
需要将gitlab-runner注册在gitlab，在gitlab-runner安装主机上执行命令gitlab-runner register，[这里](https://docs.gitlab.com/runner/register/index.html)有完整注册方式。值得注意的是executor的选择，
这里选择了docker方式，这样可以在ci的时候使用镜像来作为集成环境。这里将使用一个[sonar-scanner的镜像](https://hub.docker.com/r/ciricihq/gitlab-sonar-scanner/)。
### sonarqube 安装gitlab插件
下载[gitlab插件](https://github.com/gabrie-allaigre/sonar-gitlab-plugin)，放入${SONAR_HOME}/extensions/plugins，重启sonarqube。<br/>
进入sonarqube通用配置，选择gitlab，配置GitLab url、GitLab User Token(在gitlab user setting获取)
### 在项目中添加.gitlab-ci.yml
在项目最外层目录添加.gitlab-ci.yml文件，内容如下<br/>

```yaml
stages:
  - analysis

sonarqube:
  tags:
    - docker
  stage: analysis
  image: ciricihq/gitlab-sonar-scanner:2.1.0
  variables:
    SONAR_URL: http://10.64.26.49:9000
    SONAR_ANALYSIS_MODE: publish
  script:
  - gitlab-sonar-scanner
```
这里值得注意的是执行ci的时候会去拉取镜像，如果没有连接外网可能会执行失败，可以选择将镜像放入私有仓库；或者将镜像放到本地，并修改gitlab-runner配置文件config.toml，在[runners.docker]下添加```pull_policy:if-not-present```。<br/>
另外，SONAR_ANALYSIS_MODE 还有issues模式。

### 在项目中添加sonar-project.properties文件
在项目最外层目录添加sonar-project.properties文件，内容如下<br/>
```
sonar.projectKey=k1
sonar.projectName=test1
sonar.java.binaries=.
sonar.sources=.
sonar.gitlab.project_id=http://git.changan.com/53195/test1.git
```
### 总结
代码的质量检测是项目开发中的重要一环，现在，每次提交时，都会使用sonarqube进行代码验证
