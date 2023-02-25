locals {
  vpc_cidr               = "10.22.0.0/16"
  secondary_vpc_cidr     = "100.66.0.0/16"
  primary_priv_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]
  secondary_priv_subnets = [for k, v in local.azs : cidrsubnet(local.secondary_vpc_cidr, 8, k + 10)]
  public_subnets         = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]

  private_subnet_ids        = length(module.aws_vpc.private_subnets) > 0 ? slice(module.aws_vpc.private_subnets, 0, 3) : []
  primary_private_subnet_id = length(module.aws_vpc.private_subnets) > 0 ? slice(module.aws_vpc.private_subnets, 0, 1) : []
  pod_subnet_ids            = length(module.aws_vpc.private_subnets) > 0 ? slice(module.aws_vpc.private_subnets, 3, 6) : []
}

module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"
  
  # version = "3.19.0"

  name                  = var.environment_name
  cidr                  = local.vpc_cidr
  secondary_cidr_blocks = [local.secondary_vpc_cidr]
  azs                   = local.azs

  public_subnets = local.public_subnets
  private_subnets = concat(
    local.primary_priv_subnets,
    local.secondary_priv_subnets
  )
  # 这种方式会拉起6个 NAT Gateway
  # TODO 目前只需要主私有子网通过 NAT Gateway 出去
  # private_subnets = local.primary_priv_subnets 
  
  # enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  # single_nat_gateway   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment_name}" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment_name}" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
    "karpenter.sh/discovery"                        = "true"
    # "karpenter.sh/discovery"                        = var.environment_name
  }

  tags = local.tags
}

resource "aws_eip" "eip_01" {
  vpc = true
}

resource "aws_eip" "eip_02" {
  vpc = true
}

resource "aws_eip" "eip_03" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway_01" {
  allocation_id = aws_eip.eip_01.id
  subnet_id     = module.aws_vpc.public_subnets[0]

  tags = {
    Name = "${var.environment_name}-nat-gateway-az1"
  }

  depends_on = [module.aws_vpc]
}

resource "aws_nat_gateway" "nat_gateway_02" {
  allocation_id = aws_eip.eip_02.id
  subnet_id     = module.aws_vpc.public_subnets[1]

  tags = {
    Name = "${var.environment_name}-nat-gateway-az2"
  }

  depends_on = [module.aws_vpc]
}

resource "aws_nat_gateway" "nat_gateway_03" {
  allocation_id = aws_eip.eip_03.id
  subnet_id     = module.aws_vpc.public_subnets[2]

  tags = {
    Name = "${var.environment_name}-nat-gateway-az3"
  }

  depends_on = [module.aws_vpc]
}


data "aws_route_tables" "private_route_table_az1" {
  vpc_id = module.aws_vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*private-${module.aws_vpc.azs[0]}"]
  }
  
}

resource "aws_route" "private_subnet_nat_gateway_az1_1" {
  route_table_id            = tolist(data.aws_route_tables.private_route_table_az1.ids)[0]
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = "${aws_nat_gateway.nat_gateway_01.id}"
  depends_on = [module.aws_vpc, aws_nat_gateway.nat_gateway_01, aws_nat_gateway.nat_gateway_02, aws_nat_gateway.nat_gateway_03]
}

resource "aws_route" "private_subnet_nat_gateway_az1_2" {
  route_table_id            = tolist(data.aws_route_tables.private_route_table_az1.ids)[1]
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = "${aws_nat_gateway.nat_gateway_01.id}"
  depends_on = [module.aws_vpc, aws_nat_gateway.nat_gateway_01, aws_nat_gateway.nat_gateway_02, aws_nat_gateway.nat_gateway_03]
}


data "aws_route_tables" "private_route_table_az2" {
  vpc_id = module.aws_vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*private-${module.aws_vpc.azs[1]}"]
  }

  depends_on = [module.aws_vpc]
}

resource "aws_route" "private_subnet_nat_gateway_az2_1" {
  route_table_id            = tolist(data.aws_route_tables.private_route_table_az2.ids)[0]
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = "${aws_nat_gateway.nat_gateway_02.id}"
  
  depends_on = [module.aws_vpc, aws_nat_gateway.nat_gateway_01, aws_nat_gateway.nat_gateway_02, aws_nat_gateway.nat_gateway_03]
}

resource "aws_route" "private_subnet_nat_gateway_az2_2" {
  route_table_id            = tolist(data.aws_route_tables.private_route_table_az2.ids)[1]
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = "${aws_nat_gateway.nat_gateway_02.id}"
  
  depends_on = [module.aws_vpc, aws_nat_gateway.nat_gateway_01, aws_nat_gateway.nat_gateway_02, aws_nat_gateway.nat_gateway_03]
}


data "aws_route_tables" "private_route_table_az3" {
  vpc_id = module.aws_vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*private-${module.aws_vpc.azs[2]}"]
  }

  depends_on = [module.aws_vpc]
}

resource "aws_route" "private_subnet_nat_gateway_az3_1" {
  route_table_id            = tolist(data.aws_route_tables.private_route_table_az3.ids)[0]
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = "${aws_nat_gateway.nat_gateway_03.id}"
  
  depends_on = [module.aws_vpc, aws_nat_gateway.nat_gateway_01, aws_nat_gateway.nat_gateway_02, aws_nat_gateway.nat_gateway_03]
}

resource "aws_route" "private_subnet_nat_gateway_az3_2" {
  route_table_id            = tolist(data.aws_route_tables.private_route_table_az3.ids)[1]
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = "${aws_nat_gateway.nat_gateway_03.id}"
  
  depends_on = [module.aws_vpc, aws_nat_gateway.nat_gateway_01, aws_nat_gateway.nat_gateway_02, aws_nat_gateway.nat_gateway_03]
}


data "aws_route_tables" "rtb_all" {
  vpc_id = module.aws_vpc.vpc_id
  
  depends_on = [module.aws_vpc]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.aws_vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  route_table_ids   = data.aws_route_tables.rtb_all.ids
  
  depends_on = [module.aws_vpc]
}


module "external_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "eks-external-sg"
  description = "Security group for external"
  vpc_id      = module.aws_vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8081
      to_port     = 8081
      protocol    = "tcp"
      description = "Flink UI ports"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = -1
      to_port     = -1
      protocol    = "tcp"
      description = "All internal traffic"
      cidr_blocks = local.vpc_cidr
    },
    {
      from_port   = -1
      to_port     = -1
      protocol    = "tcp"
      description = "All pod traffic"
      cidr_blocks = local.secondary_vpc_cidr
    }    
  ]
  
  depends_on = [module.aws_vpc]

}