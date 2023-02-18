if [ $# -eq 0 ]
  then
    echo "Please provide CloudformationStackName"
    return
fi

# 配置环境变量，方便后续操作
echo "==============================================="
echo "  Update CloudFormation Outputs to ENVs ......"
echo "==============================================="
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)

test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set

echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bashrc
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bashrc
aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws configure set region $AWS_REGION

source ~/.bashrc
aws sts get-caller-identity

# 将CloudFormation的Output保存到环境变量，然后进一步记录到 `.bashrc`
export $(aws cloudformation describe-stacks --stack-name $1 --output text --query 'Stacks[0].Outputs[].join(`=`, [join(`_`, [`CF`, `OUT`, OutputKey]), OutputValue ])' --region $AWS_REGION)
echo "export EKS_VPC_ID=\"$CF_OUT_VpcId\"" >> ~/.bashrc
echo "export EKS_CONTROLPLANE_SG=\"$CF_OUT_ControlPlaneSecurityGroup\"" >> ~/.bashrc
echo "export EKS_SHAREDNODE_SG=\"$CF_OUT_SharedNodeSecurityGroup\"" >> ~/.bashrc
echo "export EKS_CUSTOMNETWORK_SG=\"$CF_OUT_CustomNetworkSecurityGroup\"" >> ~/.bashrc
echo "export EKS_EXTERNAL_SG=\"$CF_OUT_ExternalSecurityGroup\"" >> ~/.bashrc
echo "export EKS_PUB_SUBNET_01=\"$CF_OUT_PublicSubnet1\"" >> ~/.bashrc
echo "export EKS_PUB_SUBNET_02=\"$CF_OUT_PublicSubnet2\"" >> ~/.bashrc
echo "export EKS_PUB_SUBNET_03=\"$CF_OUT_PublicSubnet3\"" >> ~/.bashrc
echo "export EKS_PRI_SUBNET_01=\"$CF_OUT_PrivateSubnet1\"" >> ~/.bashrc
echo "export EKS_PRI_SUBNET_02=\"$CF_OUT_PrivateSubnet2\"" >> ~/.bashrc
echo "export EKS_PRI_SUBNET_03=\"$CF_OUT_PrivateSubnet3\"" >> ~/.bashrc
echo "export EKS_POD_SUBNET_01=\"$CF_OUT_PodSubnet1\"" >> ~/.bashrc
echo "export EKS_POD_SUBNET_02=\"$CF_OUT_PodSubnet2\"" >> ~/.bashrc
echo "export EKS_POD_SUBNET_03=\"$CF_OUT_PodSubnet3\"" >> ~/.bashrc
echo "export EKS_KEY_ARN=\"$CF_OUT_EKSKeyArn\"" >> ~/.bashrc
echo "export EKS_ADMIN_ROLE=\"$CF_OUT_EKSAdminRole\"" >> ~/.bashrc



source ~/.bashrc