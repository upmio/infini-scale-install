# 部署 topolvm

本文档目标是指导安装基于LVM本地持久化卷目录动态供应程序 [topolvm/topolvm](https://github.com/topolvm/topolvm) ，为工作负载节点的有状态服务提供持久化存储。

## 快速安装指南

### 创建VolumeGroup

在LVM PV的工作节点，创建对应与VG_NAME同名的VolumeGroup，用于供应Storageclass的本地PV资源。
**注意：dev_name 是磁盘设备名称，例如 /dev/sdb。**

```console
# BASH
vgcreate local_HDD_VG {dev_name}
```

### 设置必要的环境变量

CONTROLLER_NODE_NAMES：指定安装controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

DATA_NODE_NAMES：指定LVM PV的工作负载节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

VG_NAME：指定Storageclass对应的VolumeGroup名称。

DEVICE_CLASSES_NAME：指定设备类型名称。

```console
export CONTROLLER_NODE_NAMES="topolvm-control-plan01"
export DATA_NODE_NAMES="topolvm-control-plan01,kube-node01,kube-node02,kube-node03"
export VG_NAME="local_HDD_VG"
export DEVICE_CLASSES_NAME="ssd"
```

### 运行安装脚本

**注意：如果找不到 Helm3，将自动安装。**

**注意：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/topolvm/install_el7.sh | sh -
```

等几分钟。 如果所有 topolvm  pod 都在运行，则 topolvm 将成功安装。

```console
watch kubectl get --namespace topolvm-system pods
```

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://github.com/prometheus-community/helm-charts/blob/main/LICENSE).