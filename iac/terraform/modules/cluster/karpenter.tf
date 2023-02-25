# https://karpenter.sh/v0.23.0/getting-started/getting-started-with-terraform/
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 19.5"
#   version = "18.31.0"

  cluster_name = module.eks_blueprints.eks_cluster_id

  # controller 本身权限
  irsa_oidc_provider_arn          = module.eks_blueprints.eks_oidc_provider_arn
  # irsa_namespace_service_accounts = ["karpenter:karpenter"]
  # create_irsa = true # 默认创建的角色，权限有问题
  
  # 拉起的节点权限
  # Since Karpenter is running on an EKS Managed Node group,
  # we can re-use the role that was created for the node group
  create_iam_role = false
  iam_role_arn = aws_iam_role.eks_node_role.arn # 注意做好协同，复用托管节点组的角色更简单；如果是独立的，还需要手动更新 aws-auth
  # iam_role_arn    = module.eks.eks_managed_node_groups["ondemand-x86-initial"].iam_role_arn
}

# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest/submodules/iam-role-for-service-accounts-eks
# module "karpenter_irsa_role" {
#   source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   # role_name                          = "karpenter_controller"
#   attach_karpenter_controller_policy = true

#   karpenter_controller_cluster_id         = module.eks.cluster_id
#   # karpenter_controller_node_iam_role_arns = [module.eks.eks_managed_node_groups["default"].iam_role_arn]
#   # attach_vpc_cni_policy = true
#   # vpc_cni_enable_ipv4   = true

#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["karpenter:karpenter"]
#       # namespace_service_accounts = ["default:my-app", "canary:my-app"]
#     }
#   }
# }

resource "aws_iam_role_policy_attachment" "karpenter_controller_role_policy" {
  role       = module.karpenter.irsa_name
  policy_arn = join("", aws_iam_policy.karpenter.*.arn)
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  # repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  # repository_password = data.aws_ecrpublic_authorization_token.token.password
  # repository_username = local.ecr_pub_username
  # repository_password = local.ecr_pub_password
  chart               = "karpenter"
  version             = var.karpenter_version

  set {
    name  = "settings.aws.clusterName"
    value = module.eks_blueprints.eks_cluster_id
  }

  # set {
  #   name  = "settings.aws.clusterEndpoint"
  #   value = module.eks_blueprints.eks_cluster_endpoint
  # }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }
  
  set {
    name  = "logLevel"
    value = "debug"
  }  
  
  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller_role_policy,
    kubectl_manifest.eni_config,
    module.eks_blueprints
  ]
}


data "aws_iam_policy_document" "karpenter_policy" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions = [
              # Write Operations
              "ec2:CreateFleet",
              "ec2:CreateLaunchTemplate",
              "ec2:CreateTags",
              "ec2:DeleteLaunchTemplate",
              "ec2:RunInstances",
              "ec2:TerminateInstances",
              "sqs:DeleteMessage",
              # Read Operations
              "ec2:Describe*",
              "pricing:Get*",
              "ssm:Get*",
              "sqs:Get*",
              "sqs:Receive*",
              "iam:PassRole"
    ]
  }
}

resource "aws_iam_policy" "karpenter" {
  name        = "karpenter-policy"
  path        = "/"
  description = "Accesses for karpenter controller"
  policy      = join("", data.aws_iam_policy_document.karpenter_policy.*.json)
}