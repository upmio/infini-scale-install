# 部署 clusternet

本文档目标是指导安装多集群管理程序 [clusternet](https://github.com/clusternet/clusternet) 。

## 快速安装clusternet Parent Cluster

### 1. 确定登录kubernetes 

使用 kubectl 确定目前连接的集群是 Parent Cluster。

```console
kubectl cluster-info
```

**注意⚠️：运行在 Parent Cluster 中的 kube-apiserver 应该配置标志 --aggregator-reject-forwarding-redirect=false。**

### 2. 设置必要的环境变量

CLUSTERNET_CONTROLLER_NODE_NAMES：指定安装clusternet-controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

```console
export CLUSTERNET_CONTROLLER_NODE_NAMES="clusternet-control-plan01"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/clusternet/install_parent_el7.sh | sh -
```

运行脚本结束后会输出 registrationToken ，需要记录下，用于 clusternet-agent 部署时的必要信息
registrationToken：用于 clusternet-agent 安装时需要连接的注册令牌

输出样例如下：
```console
[Info][2023-03-16T16:44:19+0800]: token Created!
[Info][2023-03-16T16:44:19+0800]: registrationToken=3bbf21.02056c07afc35cc3. PLEASE REMEMBER THIS.
```

等待几分钟。 如果所有 clusternet-controller pod 都在运行，则 clusternet 将成功安装。

```console
kubectl get --namespace clusternet-system pods -w
```

## 使用 Helm 卸载 Parent cluster Charts

```console
# Helm
helm uninstall clusternet-hub --namespace clusternet-system
helm uninstall clusternet-scheduler --namespace clusternet-system
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## 快速安装clusternet Child Cluster

### 1. 确定登录kubernetes

使用 kubectl 确定目前连接的集群是 Child Cluster。

```console
kubectl cluster-info
```

### 2. 设置必要的环境变量

CLUSTERNET_PARENT_URL：连接 Parent cluster 的URL

CLUSTERNET_REGISTRATION_TOKEN：连接 Parent cluster 的安全令牌

CLUSTERNET_AGENT_NODE_NAMES：指定安装 clusternet-agent pod 的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERNET_REG_NAME：集群的注册名称，名称中不能包含```.``` ```_```

CLUSTERNET_REG_NAMESPACE：集群的注册namespace，名称中不能包含```.``` ```_```

```console
export CLUSTERNET_PARENT_URL="https://xxxx:6443"
export CLUSTERNET_REGISTRATION_TOKEN="xxxxxx.xxxxxxxxxxxxxx"
export CLUSTERNET_AGENT_NODE_NAMES="clusternet-agent01"
export CLUSTERNET_REG_NAME="mycluster"
export CLUSTERNET_REG_NAMESPACE="mycluster-ns"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/clusternet/install_child_el7.sh | sh -
```

等待几分钟。 如果所有 clusternet-agent pod 都在运行，则 clusternet 将成功安装。

```console
kubectl get --namespace clusternet-system pods -w
```

## 使用 Helm 卸载 Child cluster Charts

```console
# Helm
helm uninstall clusternet-agent --namespace clusternet-system
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
