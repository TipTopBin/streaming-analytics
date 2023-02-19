################################################################################
# Networking
################################################################################
data "aws_eks_addon_version" "latest" {
  for_each = toset(["vpc-cni"])

  addon_name         = each.value
  kubernetes_version = var.cluster_version
  most_recent        = true
}

# resource "aws_eks_addon" "vpc_cni" {
#   cluster_name         = module.eks_blueprints.eks_cluster_id
#   addon_name           = "vpc-cni"
#   addon_version        = data.aws_eks_addon_version.latest["vpc-cni"].version
#   resolve_conflicts    = "OVERWRITE"
#   configuration_values = "{\"env\":{\"ENABLE_PREFIX_DELEGATION\":\"true\", \"ENABLE_POD_ENI\":\"true\"}}"

#   depends_on = [
#     null_resource.kubectl_set_env
#   ]
# }

resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = module.eks_blueprints.eks_cluster_id
  addon_name        = "vpc-cni"
  resolve_conflicts = "OVERWRITE"
  addon_version     = data.aws_eks_addon_version.latest["vpc-cni"].version

  configuration_values = jsonencode({
    env = {
      # Reference https://aws.github.io/aws-eks-best-practices/reliability/docs/networkmanagement/#cni-custom-networking
      AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
      ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"

      # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  tags = local.tags
}


resource "kubectl_manifest" "eni_config" {
  # for_each = zipmap(local.azs, slice(module.vpc.private_subnets, 3, 6))
  for_each = zipmap(local.azs, slice(local.pod_subnet_ids, 0, 3))

  yaml_body = yamlencode({
    apiVersion = "crd.k8s.amazonaws.com/v1alpha1"
    kind       = "ENIConfig"
    metadata = {
      name = each.key
    }
    spec = {
      securityGroups = [
        module.eks_blueprints.cluster_primary_security_group_id,
        module.eks_blueprints.cluster_security_group_id,
      ]
      subnet = each.value
    }
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name      = module.eks_blueprints.eks_cluster_id
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"
  
  depends_on = [
    module.eks_blueprints,
    aws_eks_addon.vpc_cni,
    kubectl_manifest.eni_config
  ]  
}


################################################################################
# Networking
################################################################################

resource "aws_eks_addon" "aws-ebs-csi-driver" {
#   cluster_name      = module.eks_blueprints.cluster_name
  cluster_name      = var.environment_name
  addon_name        = "aws-ebs-csi-driver"
  resolve_conflicts = "OVERWRITE"
  
  depends_on = [
    module.eks_blueprints,
    aws_eks_addon.vpc_cni,
    kubectl_manifest.eni_config
  ]    
}