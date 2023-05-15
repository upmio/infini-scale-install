# 部署 carina

本文档目标是指导安装基于LVM本地持久化卷目录动态供应程序 [carina](https://github.com/carina-io/carina) ，为工作负载节点的有状态服务提供持久化存储。

## 快速安装指南

### 1. 检查本地磁盘设备

**注意⚠️：每个数据节点都必须保证VolumeGroup 存在，才能部署 carina。**

在LVM PV的工作节点，创建对应与VG_NAME同名的VolumeGroup，用于供应Storageclass的本地PV资源。

**dev_name 是磁盘设备名称，例如 /dev/sdb。**

### 3. 设置必要的环境变量

CARINA_CONTROLLER_NODE_NAMES：指定控制节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CARINA_DATA_NODE_NAMES：指定工作负载节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CARINA_SSD_DEV_NAMES：指定本地SSD设备名称集合，磁盘设备名称可以使用","作为分隔符，表示多个磁盘设备名称。

CARINA_HDD_DEV_NAMES：指定本地HDD设备名称集合，磁盘设备名称可以使用","作为分隔符，表示多个磁盘设备名称。

```console
export CARINA_CONTROLLER_NODE_NAMES="control-plan01"
export CARINA_DATA_NODE_NAMES="node01,node02,node03"
export CARINA_SSD_DEV_NAMES="/dev/sdb"
export CARINA_HDD_DEV_NAMES="/dev/sdc"
```

### 4. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/carina/install_el7.sh | sh -
```

等几分钟。 如果所有 carina  pod 都在运行，则 carina 将成功安装。

```console
kubectl get --namespace kube-system pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall carina-csi-driver --namespace kube-system
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
