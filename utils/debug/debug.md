
1. default_secret_name

│ Starting from version 1.24.0 Kubernetes does not automatically generate a token for service accounts, in this case,
│ "default_secret_name" will be empty

不启用：
- enable_aws_load_balancer_controller
- enable_aws_for_fluentbit
- enable_self_managed_aws_ebs_csi_driver

2. installer.sh 
文件内容修改需特别谨慎 


3. Cloud9 权限问题

```shell
aws ec2 describe-iam-instance-profile-associations --filters Name=instance-id,Values=i-xxx
```

解绑：
```shell
aws ec2 disassociate-iam-instance-profile --association-id xxx
```

4. Karpenter

Failed to get lease: leases.coordination.k8s.io "xxx.ap-south-1.compute.internal" not found
- 检查权限
    - k get cm aws-auth -n kube-system -o yaml   
- 检查安全组
  
```shell
journalctl -xefu kubelet
```

5. kubectl 权限问题

通过 TF 拉起的集群，执行某些 eksctl 命令后，会导致鉴权失效，报一下错误
```shell
error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"
```

可以通过 eksctl 更新配置
```shell
eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME
```

6. credentials 问题

```
couldn't get current server API group list: the server has asked for the client to provide credentials

error: You must be logged in to the server (the server has asked for the client to provide credentials)
```

```
eksctl utils associate-iam-oidc-provider --cluster=$EKS_CLUSTER_NAME
```

7. 并行度问题

注意检查版本，自定义版本是 1.13.6，如果版本不一致，并行度设置不会生效。


8. KDS 分片配置

注意分片配置与 Flink 作业的联动。
