# 部署 openkruise

本文档目标是指导安装多集群管理程序 [openkruise](https://github.com/openkruise/kruise) 。

## 外置数据库-快速安装 openkruise 

### 1. 确定登录kubernetes 

使用 kubectl 确定目前连接的集群。

```console
kubectl cluster-info
```

### 2. 设置必要的环境变量

KRUISE_CONTROLLER_NODE_NAMES：指定安装 clusterpedia-controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

```console
export KRUISE_CONTROLLER_NODE_NAMES="openkruise-control-plan01"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/openkruise/install_el7.sh | sh -
```

等待几分钟。 如果所有 openkruise pod 都在运行，则 openkruise 将成功安装。

```console
kubectl get --namespace kruise-system pods -w
```

## 使用 Helm 卸载 openkruise

```console
# Helm
helm uninstall kruise --namespace kruise-system
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
