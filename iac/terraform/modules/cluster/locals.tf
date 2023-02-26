locals {
  tags           = var.tags
  azs            = slice(data.aws_availability_zones.available.names, 0, 3)
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.id
}