# 部署 Redis

本文档目标是指导安装 Redis 。

## 快速安装指南

### 1. 设置必要的环境变量

REDIS_PWD：登录 Redis 登录密码。

REDIS_NODE_NAMES：指定安装 Redis pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

```console
export REDIS_PWD='password'
export REDIS_NAMES="redis-node01"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/redis/install_el7.sh | sh -
```

等几分钟。 如果所有 mysql pod 都在运行，则 mysql 将成功安装。

```console
kubectl get --namespace redis pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall redis --namespace redis
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
