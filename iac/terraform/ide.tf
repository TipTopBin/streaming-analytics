locals {
  environment_variables = <<EOT
AWS_ACCOUNT_ID=${data.aws_caller_identity.current.account_id}
AWS_DEFAULT_REGION=${data.aws_region.current.name}
EKS_CLUSTER_NAME=${try(module.cluster.eks_cluster_id, "")}
EKS_DEFAULT_MNG_NAME=${try(split(":", module.cluster.eks_cluster_nodegroup_name)[1], "")}
EKS_DEFAULT_MNG_MIN=${module.cluster.eks_cluster_nodegroup_size_min}
EKS_DEFAULT_MNG_MAX=${module.cluster.eks_cluster_nodegroup_size_max}
EKS_DEFAULT_MNG_DESIRED=${module.cluster.eks_cluster_nodegroup_size_desired}
EFS_ID=${module.cluster.efsid}
EKS_TAINTED_MNG_NAME=${try(split(":", module.cluster.eks_cluster_tainted_nodegroup_name)[1], "")}
# ADOT_IAM_ROLE=${try(module.cluster.adot_iam_role, "")}
VPC_ID=${module.cluster.vpc_id}
EKS_CLUSTER_SECURITY_GROUP_ID=${try(module.cluster.eks_cluster_security_group_id, "")}
PRIMARY_SUBNET_1=${module.cluster.private_subnet_ids[0]}
PRIMARY_SUBNET_2=${module.cluster.private_subnet_ids[1]}
PRIMARY_SUBNET_3=${module.cluster.private_subnet_ids[2]}
SECONDARY_SUBNET_1=${module.cluster.private_subnet_ids[3]}
SECONDARY_SUBNET_2=${module.cluster.private_subnet_ids[4]}
SECONDARY_SUBNET_3=${module.cluster.private_subnet_ids[5]}
MANAGED_NODE_GROUP_IAM_ROLE_ARN=${try(module.cluster.eks_cluster_managed_node_group_iam_role_arns[0], "")}
AZ1=${module.cluster.azs[0]}
AZ2=${module.cluster.azs[1]}
AZ3=${module.cluster.azs[2]}
# ADOT_IAM_ROLE_CI=${try(module.cluster.adot_iam_role_ci, "")}
OIDC_PROVIDER=${try(module.cluster.oidc_provider, "")}
VPC_ID=${module.cluster.vpc_id}
VPC_CIDR=${module.cluster.vpc_cidr}
VPC_PRIVATE_SUBNET_ID_0=${module.cluster.private_subnet_ids[0]}
VPC_PRIVATE_SUBNET_ID_1=${module.cluster.private_subnet_ids[1]}
VPC_PRIVATE_SUBNET_ID_2=${module.cluster.private_subnet_ids[2]}
# Add by Robin
AWS_REGION=${data.aws_region.current.name}
EKS_VPC_ID=${module.cluster.vpc_id}
EKS_CONTROLPLANE_SG=${try(module.cluster.eks_cluster_security_group_id, "")}
EKS_SHAREDNODE_SG=${try(module.cluster.eks_additional_security_group_id, "")}
EKS_PUB_SUBNET_01=${module.cluster.public_subnet_ids[0]}
EKS_PUB_SUBNET_02=${module.cluster.public_subnet_ids[1]}
EKS_PUB_SUBNET_03=${module.cluster.public_subnet_ids[2]}
EKS_PRI_SUBNET_01=${module.cluster.private_subnet_ids[0]}
EKS_PRI_SUBNET_02=${module.cluster.private_subnet_ids[1]}
EKS_PRI_SUBNET_03=${module.cluster.private_subnet_ids[2]}
EMR_VIRTUAL_CLUSTER_NAME=${module.cluster.emr_eks_spark_name}
EMR_VIRTUAL_CLUSTER_ID=${split("/", module.cluster.emr_eks_spark_arn)[2]}
EMR_VIRTUAL_CLUSTER_ARN=${module.cluster.emr_eks_spark_arn}
EMR_EKS_EXECUTION_ARN=${module.cluster.emr_on_eks_role_arn[0]}
EOT

  bootstrap_script = <<EOF
set -e



mkdir -p /graviton-university
rm -rf /graviton-university/streaming-analytics
git clone https://github.com/DATACNTOP/streaming-analytics.git /graviton-university/streaming-analytics
(cd /graviton-university/streaming-analytics && git checkout ${var.repository_ref})

(cd /graviton-university/streaming-analytics/environment && bash ./installer.sh)

bash -c "aws cloud9 update-environment --environment-id $CLOUD9_ENVIRONMENT_ID --managed-credentials-action DISABLE || true"

chown ec2-user -R /graviton-university
chmod +x /graviton-university/streaming-analytics/environment/bin/*
cp /graviton-university/streaming-analytics/environment/bin/* /usr/local/bin

sudo -H -u ec2-user bash -c "ln -sf /graviton-university/streaming-analytics ~/environment/streaming-analytics"



if [[ ! -d "/home/ec2-user/.bashrc.d" ]]; then
  sudo -H -u ec2-user bash -c "mkdir -p ~/.bashrc.d"
  sudo -H -u ec2-user bash -c "touch ~/.bashrc.d/dummy.bash"

  sudo -H -u ec2-user bash -c "echo 'for file in ~/.bashrc.d/*.bash; do source \"\$file\"; done' >> ~/.bashrc"
fi

sudo -H -u ec2-user bash -c "echo 'aws cloud9 update-environment --environment-id $CLOUD9_ENVIRONMENT_ID --managed-credentials-action DISABLE &> /dev/null || true' > ~/.bashrc.d/c9.bash"

sudo -H -u ec2-user bash -c "echo 'export AWS_PAGER=\"\"' > ~/.bashrc.d/aws.bash"

sudo -H -u ec2-user bash -c "echo 'aws eks update-kubeconfig --name ${module.cluster.eks_cluster_id} > /dev/null' > ~/.bashrc.d/kubeconfig.bash"

cat << EOT > /home/ec2-user/.bashrc.d/env.bash
set -a
${local.environment_variables}
set +a
EOT

chown ec2-user /home/ec2-user/.bashrc.d/env.bash

sudo -H -u ec2-user bash -c 'git config --global user.email "you@graviton-university.com"'
sudo -H -u ec2-user bash -c 'git config --global user.name "Graviton University Learner"'
EOF
}


# sudo -H -u ec2-user bash -c "git clone https://github.com/DATACNTOP/emr-on-eks-benchmark.git ~/environment/emr-on-eks-benchmark"


# rm -rf /tmp/graviton-university
# git clone https://github.com/DATACNTOP/streaming-analytics.git /tmp/graviton-university
# (cd /tmp/graviton-university && git checkout ${var.repository_ref})

# (cd /tmp/graviton-university/environment && bash ./installer.sh)

# bash -c "aws cloud9 update-environment --environment-id $CLOUD9_ENVIRONMENT_ID --managed-credentials-action DISABLE || true"

# mkdir -p /workspace
# cp -R /tmp/graviton-university/environment/workspace/* /workspace
# cp -R /workspace /workspace-backup
# chown ec2-user -R /workspace
# chmod +x /tmp/graviton-university/environment/bin/*
# cp /tmp/graviton-university/environment/bin/* /usr/local/bin

# rm -rf /tmp/graviton-university

# sudo -H -u ec2-user bash -c "ln -sf /workspace ~/environment/workspace"

# sudo rm -f /home/ec2-user/.ssh/gitops_ssh.pem

# sudo -H -u ec2-user bash -c "aws ssm get-parameter --name ${module.cluster.gitops_ssh_ssm_name} --with-decryption --query 'Parameter.Value' --region ${data.aws_region.current.name} --output text > ~/.ssh/gitops_ssh.pem"
# chmod 400 /home/ec2-user/.ssh/gitops_ssh.pem

# cat << EOT > /home/ec2-user/.ssh/config
# Host git-codecommit.*.amazonaws.com
#   User ${module.cluster.gitops_ssh_iam_user}
#   IdentityFile ~/.ssh/gitops_ssh.pem
# EOT
# chown ec2-user /home/ec2-user/.ssh/config
# chmod 600 /home/ec2-user/.ssh/config

# sudo -H -u ec2-user bash -c "ssh-keyscan -H git-codecommit.${data.aws_region.current.name}.amazonaws.com >> ~/.ssh/known_hosts"

module "ide" {
  source = "./modules/ide"

  environment_name = module.cluster.eks_cluster_id
  subnet_id        = module.cluster.public_subnet_ids[0]
  cloud9_owner     = var.cloud9_owner

  additional_cloud9_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  additional_cloud9_policies = [
    jsondecode(templatefile("${path.module}/templates/iam_policy.json", {
      cluster_name = module.cluster.eks_cluster_id,
      cluster_arn  = module.cluster.eks_cluster_arn,
      nodegroup    = module.cluster.eks_cluster_nodegroup
      region       = data.aws_region.current.name
      account_id   = data.aws_caller_identity.current.account_id
    }))
  ]

  bootstrap_script = local.bootstrap_script
}
