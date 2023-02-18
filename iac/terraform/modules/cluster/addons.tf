################################################################################
# Addons
################################################################################
data "aws_eks_addon_version" "latest" {
  for_each = toset(["vpc-cni"])

  addon_name         = each.value
  kubernetes_version = var.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name         = module.eks_blueprints.eks_cluster_id
  addon_name           = "vpc-cni"
  addon_version        = data.aws_eks_addon_version.latest["vpc-cni"].version
  resolve_conflicts    = "OVERWRITE"
  configuration_values = "{\"env\":{\"ENABLE_PREFIX_DELEGATION\":\"true\", \"ENABLE_POD_ENI\":\"true\"}}"

  depends_on = [
    null_resource.kubectl_set_env
  ]
}

resource "aws_eks_addon" "aws-ebs-csi-driver" {
#   cluster_name      = module.eks_blueprints.cluster_name
  cluster_name      = var.environment_name
  addon_name        = "aws-ebs-csi-driver"
  resolve_conflicts = "OVERWRITE"
  
  depends_on = [
    module.eks_blueprints,
    aws_eks_addon.vpc_cni
  ]    
}