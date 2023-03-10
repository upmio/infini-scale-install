# 部署 cert-manager

本文档目标是指导安装证书管理工具 [cert-manager](https://github.com/cert-manager/cert-manager) 。

## 快速安装指南

### 运行安装脚本

**注意：如果找不到 Helm3，将自动安装。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/cert-manager/install_el7.sh | sh -
```

等几分钟。 如果所有 cert-manager  pod 都在运行，则 cert-manager 将成功安装。

```console
watch kubectl get --namespace cert-manager pods
```

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
