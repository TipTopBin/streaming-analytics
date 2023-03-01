
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