# 部署 infini-scale

本文档目标是指导部署 infini-scale 。

## 快速安装指南

### 1. 部署 cert-manager

**注意⚠️：cert-manager 是被依赖的服务，必须在安装 infini-scale 前完成 cert-manager 部署。**

部署方法请使用[cert-manger 部署](https://github.com/upmio/infini-scale-install/tree/main/addons/cert-manager)

### 2. 部署 MySQL

**注意⚠️：MySQL 是被依赖的服务，必须在安装 infini-scale 前完成 MySQL 部署。**

部署方法请使用[MySQL 部署](https://github.com/upmio/infini-scale-install/tree/main/addons/mysql)

### 3. 部署 Redis

**注意⚠️：Redis 是被依赖的服务，必须在安装 infini-scale 前完成 Redis 部署。**

部署方法请使用[Redis 部署](https://github.com/upmio/infini-scale-install/tree/main/addons/redis)

### 4. 设置必要的环境变量

DB_USER：指定 MySQL 数据库用户名。

DB_PWD：指定 MySQL 数据库密码。

DB_HOST：指定 MySQL 数据库主机地址。

REDIS_PWD：指定 Redis 密码。

REDIS_HOST：指定 Redis 主机地址。

INFINI_CONTROLLER_NODE_NAMES：指定安装 infini-scale controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

```console
export DB_USER="admin"
export DB_PWD="password"
export DB_HOST="mysql-0.mysql"
export REDIS_PWD="password"
export REDIS_HOST="redis.redis"
export INFINI_CONTROLLER_NODE_NAMES="infini-control-plan01"
```

### 5. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/install_el7.sh | sh -
```

等几分钟。 如果所有 infini-scale  pod 都在运行，则 infini-scale 将成功安装。

```console
kubectl get --namespace infinilabs pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall infini-scale --namespace infinilabs
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
