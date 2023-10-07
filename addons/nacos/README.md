# helm deploy nacos

## 1. 前提条件

- [部署 kubernetes](https://github.com/kubernetes-sigs/kubespray)
- [安装 helm](https://helm.sh/docs/helm/helm_install/)
- [部署 openebs-lvmlocalpv](https://github.com/upmio/infini-scale-install/tree/main/addons/openebs-lvmlocalpv)

## 2. 设置必要的环境变量

- MYSQL_STORAGECLASS_NAME: 指定Storageclass名称, 使用 kubectl get storageclasses 获取可用的 Storageclass 名称;
- MYSQL_PVC_SIZE_G: 指定持久化卷的大小，单位为Gi;
- MYSQL_NODE_NAMES: 指定安装MySQL pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

```bash
export MYSQL_STORAGECLASS_NAME="openebs-lvmsc-hdd"
export MYSQL_PVC_SIZE_G="5"
export MYSQL_NODE_NAMES="kube-node01"
```

## 3. 运行安装脚本
> 注意⚠️：如果找不到 Helm3，将自动安装。

> 注意⚠️：安装脚本会对指定节点进行添加label的操作。

## 4. 运行安装脚本

```bash
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/nacos/install_el7.sh | sh -
```

等几分钟。 如果所有  pod 都在运行，则 nacos & mysql 将成功安装：

```bash
$ kubectl get all -n nacos
NAME                      READY   STATUS      RESTARTS        AGE
pod/nacos-0               1/1     Running     6 (6m14s ago)   12m
pod/nacos-init-db-6t2kc   0/1     Completed   3               12m
pod/nacos-mysql-0         1/1     Running     0               12m

NAME                           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
service/nacos                  ClusterIP   10.179.16.36   <none>        9848/TCP,8848/TCP,9849/TCP   12m
service/nacos-headless         ClusterIP   None           <none>        9848/TCP,8848/TCP,9849/TCP   12m
service/nacos-mysql            ClusterIP   10.179.39.6    <none>        3306/TCP                     12m
service/nacos-mysql-headless   ClusterIP   None           <none>        3306/TCP                     12m

NAME                           READY   AGE
statefulset.apps/nacos         1/1     12m
statefulset.apps/nacos-mysql   1/1     12m

NAME                      COMPLETIONS   DURATION   AGE
job.batch/nacos-init-db   1/1           6m46s      12m
```

## 5. nodeport 配置

```bash
$ kubectl edit service/nacos -n nacos
.....
spec:
  clusterIP: 10.179.16.36   #删除
  clusterIPs:               #删除
  - 10.179.16.36            #删除
  internalTrafficPolicy: Cluster   #删除
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: client-rpc
    port: 9848
    protocol: TCP
    targetPort: client-rpc
    nodePort: 31031        #添加
  - name: http
    port: 8848
    protocol: TCP
    targetPort: http
    nodePort: 30031       #添加
  - name: raft-rpc
    port: 9849
    protocol: TCP
    targetPort: raft-rpc
    nodePort: 31032       #添加
  selector:
    app.kubernetes.io/instance: nacos
    app.kubernetes.io/name: nacos
  sessionAffinity: None
  type: NodePort          #修改
....
```

```bash
$ kubectl get svc  -n nacos    
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                                        AGE
nacos                  NodePort    10.179.16.36   <none>        9848:31031/TCP,8848:30031/TCP,9849:31032/TCP   18m
```

## 6. 访问界面

http://192.168.26.21:30031/nacos


## 7. 使用 Helm 卸载 Charts

```bash
helm uninstall nacos -n nacos
```

License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).

