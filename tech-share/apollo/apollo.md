Ctrip Apollo
========================

## 简介

携程开源的配置动态管理，热更新中间件

### 架构图：

![overall-architecture](./images/overall-architecture.png)

### 服务端：

#### 配置服务组

ConfigService：与客户端进行配置数据交互

MetaServer：提供服务列表

Eureka：用于ConfigService和AdminService的服务发现

#### 配置管理组

Portal：配置管理可视化，通过MetaServer连接AdminService（软负载均衡），需要数据库

AdminService：配置管理

### 客户端：

Client：获取配置信息，通过MetaServer连接ConfigService（软负载均衡）

### 配置更新流程：

![release-message-notification-design](./images/release-message-notification-design.png)

关键技术点：

1. 使用数据库表定时扫描机制发现更新的配置

2. 客户端使用长轮询和定时任务方式获取配置更新

## 优点

1. 文档丰富，提供Docker部署文档
2. 版本管理和灰度发布
3. 使用Spring Cloud分布式架构
4. 配置文件独立管理，提供内存和本地缓存
5. 在不连接配置中心的情况下提供本地开发模式
6. 有部门的概念
7. 权限管理
8. 可用LDAP和自定义登录
9. 提供properties的迁移
10. 客户端接入方式多，与Spring融合较好

## 缺点

1. 组件较多，部署相对繁琐
2. yml迁移需要一定工作量
3. 人员和部门管理功能较弱
4. 前端使用Angular，自定义修改不便

## 使用建议

可以部署使用

1. AdminService, ConfigService, Portal打为Docker镜像
2. Client使用单独脚本发布
3. Portal部门组件做定制化修改 - 使用Angular
4. Portal人员登录使用LDAP
5. Portal配置YML导入组件 - 使用Angular




