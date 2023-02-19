  #---------------------------------------
  # ENABLE EMR ON EKS
  # 1. Creates namespace
  # 2. k8s role and role binding(emr-containers user) for the above namespace
  # 3. IAM role for the team execution role
  # 4. Update AWS_AUTH config map with  emr-containers user and AWSServiceRoleForAmazonEMRContainers role
  # 5. Create a trust relationship between the job execution role and the identity of the EMR managed service account
  #---------------------------------------
# { # 需跟 EKS 模块放在一起
  

#   enable_emr_on_eks = true
#   emr_on_eks_teams = {
#     emr-eks-spark = {
#       namespace               = "emr-spark"
#       job_execution_role      = "emr-eks-spark"
#       additional_iam_policies = [aws_iam_policy.emr_on_eks.arn]
#     }
#     emr-eks-flink = {
#       namespace               = "emr-flink"
#       job_execution_role      = "emr-eks-flink"
#       additional_iam_policies = [aws_iam_policy.emr_on_eks.arn]
#     }
#   }
#   tags = local.tags
# }

resource "kubernetes_namespace" "emr_spark" {
  metadata {
    annotations = {
      name = local.emr_eks_spark["namespace"]
    }

    labels = {
      job-type = "spark"
    }

    name = local.emr_eks_spark["namespace"]
  }
}

resource "kubernetes_role" "emr_containers" {
  metadata {
    name      = local.emr_service_name
    namespace = kubernetes_namespace.emr_spark.id
  }

  # Debug
  rule {
    verbs      = ["*"]
    api_groups = ["*"]
    resources  = ["*"]
  }  
}

resource "kubernetes_role_binding" "emr_containers" {
  metadata {
    name      = local.emr_service_name
    namespace = kubernetes_namespace.emr_spark.id
  }

  subject {
    kind = "User"
    name = local.emr_service_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = local.emr_service_name
  }
}


#---------------------------------------------------------------
# Example IAM policies for EMR job execution
#---------------------------------------------------------------
resource "aws_iam_role" "emr_eks_spark_execution" {
  name                  = format("%s-%s", var.eks_cluster_id, local.emr_eks_spark["job_execution_role"])
  assume_role_policy    = data.aws_iam_policy_document.emr_assume_role.json
  # force_detach_policies = true
  # path                  = var.iam_role_path
  # permissions_boundary  = var.iam_role_permissions_boundary
  # tags                  = var.tags
}

resource "aws_iam_role_policy_attachment" "emr_eks_spark_execution_attach" {
  role       = aws_iam_role.emr_eks_spark_execution.name
  policy_arn = join("", aws_iam_policy.emr_eks_spark_policy.*.arn)
}

resource "aws_iam_policy" "emr_eks_spark_policy" {
  name        = format("%s-%s", var.eks_cluster_id, "emr-job-iam-policies")
  description = "IAM policy for EMR on EKS Job execution"
  path        = "/"
  policy      = data.aws_iam_policy_document.emr_on_eks.json
}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "emr_eks_spark_policy_doc" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:s3:::*"]

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"]

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
  }
}

data "aws_iam_policy_document" "emr_assume_role" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}



#---------------------------------------------------------------
# Create EMR on EKS Virtual Cluster
#---------------------------------------------------------------
resource "aws_emrcontainers_virtual_cluster" "emr-eks-spark" {
  name = format("%s-%s", module.eks_blueprints.eks_cluster_id, "emr-eks-spark")

  container_provider {
    id   = module.eks_blueprints.eks_cluster_id
    type = "EKS"

    info {
      eks_info {
        namespace = local.emr_eks_spark["namespace"]
      }
    }
  }
}