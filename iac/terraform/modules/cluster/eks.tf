locals {
  default_mng_min  = 1
  default_mng_max  = 6
  default_mng_size = 1
  eks_node_policies = ["AmazonEC2ContainerRegistryReadOnly", "AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy", "AmazonSSMManagedInstanceCore"]
}

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.16.0"

  tags = local.tags

  vpc_id             = module.aws_vpc.vpc_id
  private_subnet_ids = local.private_subnet_ids
  public_subnet_ids  = module.aws_vpc.public_subnets

  cluster_name    = var.environment_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  cluster_security_group_additional_rules = {
    ingress_from_cloud9_host = {
      description = "Ingress from Cloud9 Host"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [module.aws_vpc.vpc_cidr_block]
    }
  }

  cluster_kms_key_additional_admin_arns = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]

  map_roles = var.map_roles

  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Recommended outbound traffic for Node groups
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    # Allows Control Plane Nodes to talk to Worker nodes on Karpenter ports.
    # This can be extended further to specific port based on the requirement for others Add-on e.g., metrics-server 4443, spark-operator 8080, etc.
    # Change this according to your security requirements if needed
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Nodegroup for Karpenter"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }

    ingress_nodes_load_balancer_controller_port = {
      description                   = "Cluster API to Nodegroup for Load Balancer Controller"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    }

    ingress_nodes_metric_server_port = {
      description                   = "Cluster API to Nodegroup for Metric Server"
      protocol                      = "tcp"
      from_port                     = 4443
      to_port                       = 4443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # Add karpenter.sh/discovery tag so that we can use this as securityGroupSelector in karpenter provisioner
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.environment_name
    # "karpenter.sh/discovery" = var.environment_name
  }

  managed_node_groups = {
    mg_5 = {
      node_group_name = "managed-ondemand"
      # IAM Roles for Nodegroup
      create_iam_role = false
      iam_role_arn    = aws_iam_role.eks_node_role.arn # iam_role_arn will be used if create_iam_role=false  
      instance_types  = ["m5.xlarge"]
      subnet_ids      = local.private_subnet_ids
      min_size        = local.default_mng_min
      max_size        = local.default_mng_max
      desired_size    = local.default_mng_size

      ami_type        = "AL2_x86_64"
      release_version = var.ami_release_version

      k8s_labels = {
        workshop-default = "yes"
        blocker          = sha1(aws_eks_addon.vpc_cni.id)
      }
    }

    # # List of map_roles
    # map_roles          = [
    #   {
    #     rolearn  = "arn:aws:iam::<aws-account-id>:role/<role-name>"     # The ARN of the IAM role
    #     username = "karpenter-role"                                           # The user name within Kubernetes to map to the IAM role
    #     groups   = ["system:masters"]                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
    #   }
    # ]
  
    # system = {
    #   node_group_name = "managed-system"
    #   iam_role_arn    = aws_iam_role.eks_node_role.arn
    #   instance_types  = ["m5.xlarge"]
    #   subnet_ids      = local.primary_private_subnet_id
    #   min_size        = 1
    #   max_size        = 2
    #   desired_size    = 1

    #   ami_type        = "AL2_x86_64"
    #   release_version = var.ami_release_version

    #   k8s_taints = [{ key = "systemComponent", value = "true", effect = "NO_SCHEDULE" }]

    #   k8s_labels = {
    #     workshop-system = "yes"
    #     blocker         = sha1(aws_eks_addon.vpc_cni.id)
    #   }
    # }

    # mg_tainted = {
    #   node_group_name = "managed-ondemand-tainted"
    #   iam_role_arn    = aws_iam_role.eks_node_role.arn
    #   instance_types  = ["m5.large"]
    #   subnet_ids      = local.private_subnet_ids
    #   min_size        = 0
    #   max_size        = 1
    #   desired_size    = 0


    #   ami_type        = "AL2_x86_64"
    #   release_version = var.ami_release_version

    #   k8s_labels = {
    #     workshop-default = "no"
    #     blocker          = sha1(aws_eks_addon.vpc_cni.id)
    #     tainted          = "yes"
    #   }
    # }
  }

  # fargate_profiles = {
  #   checkout_profile = {
  #     fargate_profile_name = "checkout-profile"
  #     fargate_profile_namespaces = [{
  #       namespace = "checkout"
  #       k8s_labels = {
  #         fargate = "yes"
  #       }
  #     }]
  #     subnet_ids = local.private_subnet_ids
  #   }
  # }
  
  
  enable_emr_on_eks = true
  
  emr_on_eks_teams = {
    emr-eks-spark = {
      namespace               = "emr-spark"
      job_execution_role      = "emr-eks-spark"
      # Only add admin for debug usage
      additional_iam_policies = [aws_iam_policy.emr_on_eks.arn, "arn:aws:iam::aws:policy/AdministratorAccess"]
    }
    
    # emr-eks-flink = {
    #   namespace               = "emr-flink"
    #   job_execution_role      = "emr-eks-flink"
    #   additional_iam_policies = [aws_iam_policy.emr_on_eks.arn]
    # }
  }

}

#---------------------------------------------------------------
# Create EMR on EKS Virtual Cluster
#---------------------------------------------------------------
resource "aws_emrcontainers_virtual_cluster" "emr_eks_spark" {
  name = format("%s-%s", module.eks_blueprints.eks_cluster_id, "emr-spark")

  container_provider {
    id   = module.eks_blueprints.eks_cluster_id
    type = "EKS"

    info {
      eks_info {
        namespace = "emr-spark"
      }
    }
  }
}

resource "aws_security_group_rule" "dns_udp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [module.aws_vpc.vpc_cidr_block]
  security_group_id = module.eks_blueprints.cluster_primary_security_group_id
}

resource "aws_security_group_rule" "dns_tcp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = [module.aws_vpc.vpc_cidr_block]
  security_group_id = module.eks_blueprints.cluster_primary_security_group_id
}

# Build kubeconfig for use with null resource to modify aws-node daemonset
locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = module.eks_blueprints.eks_cluster_id
      cluster = {
        certificate-authority-data = module.eks_blueprints.eks_cluster_certificate_authority_data
        server                     = module.eks_blueprints.eks_cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = module.eks_blueprints.eks_cluster_id
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.cluster.token
      }
    }]
  })
}

resource "null_resource" "kubectl_set_env" {
  triggers = {
    cluster_arns = module.eks_blueprints.eks_cluster_arn
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
    command = <<-EOT
      sleep 30
      kubectl set env daemonset aws-node -n kube-system POD_SECURITY_GROUP_ENFORCING_MODE=standard --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      sleep 10
    EOT
  }
}


resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_node_role_managed" {
  for_each = toset(local.eks_node_policies)

  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
  role       = aws_iam_role.eks_node_role.name
}

# Only for test
resource "aws_iam_role_policy_attachment" "eks_node_role_admin" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.eks_node_role.name
}


resource "aws_iam_instance_profile" "eks_node_instance_profile" {
  name = "eks-node-instance-profile"
  role = aws_iam_role.eks_node_role.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}
