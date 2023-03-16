# 部署 clusternet Parnet Cluster

本文档目标是指导安装多集群管理程序 [clusternet](https://github.com/clusternet/clusternet) 。

## 快速安装clusternet Parnet Cluster

### 1. 设置必要的环境变量

CLUSTERNET_CONTROLLER_NODE_NAMES：指定安装clusternet controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

```console
export CLUSTERNET_CONTROLLER_NODE_NAMES="clusternet-control-plan01"
```

### 2. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/clusternet/install_parent_el7.sh | sh -
```

等几分钟。 如果所有 carina  pod 都在运行，则 carina 将成功安装。

```console
kubectl get --namespace clusternet-system pods -w
```

## 使用 Helm 卸载 Parnet cluster Charts

```console
# Helm
helm uninstall clusternet-hub --namespace clusternet-system
helm uninstall clusternet-scheduler --namespace clusternet-system
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
