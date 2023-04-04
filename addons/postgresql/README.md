# 部署 PostgreSQL

本文档目标是指导安装 PostgreSQL 。

## 快速安装指南

### 1. 设置必要的环境变量

POSTGRE_PWD：指定 "postgres" 管理员用户密码。

POSTGRE_USER_NAME：登录 PostgreSQL 用户名。

POSTGRE_USER_PWD：登录 PostgreSQL 用户密码。

POSTGRE_STORAGECLASS_NAME：指定Storageclass名称, 使用 ```kubectl get storageclasses ```获取可用的 Storageclass 名称。

POSTGRE_PVC_SIZE_G：指定持久化卷的大小，单位为Gi。

POSTGRE_NODE_NAMES：指定安装 PostgreSQL pod 的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

POSTGRE_PORT：指定安装 PostgreSQL 端口。

```console
export POSTGRE_PWD='password'
export POSTGRE_USER_NAME="admin"
export POSTGRE_USER_PWD='password'
export POSTGRE_STORAGECLASS_NAME="topolvm-provisioner"
export POSTGRE_PVC_SIZE_G="50"
export POSTGRE_NODE_NAMES="db-node01,db-node02,db-node03"
export POSTGRE_PORT="5432"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定 PostgreSQL pod 的节点进行添加label的操作，标签为 ```postgresql.standalone.node=enable```。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/postgresql/install_el7.sh | sh -
```

等几分钟。 如果所有 PostgreSQL pod 都在运行，则 PostgreSQL 将成功安装。

```console
kubectl get --namespace postgresql pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall postgresql --namespace postgresql
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
