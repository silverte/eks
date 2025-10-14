################################################################################
# Root Module - VPC + EKS
################################################################################

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  count  = var.create_vpc ? 1 : 0

  service     = var.service
  environment = var.environment

  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  intra_subnets       = var.intra_subnets

  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az
  enable_vpn_gateway     = var.enable_vpn_gateway

  tags = local.tags
}

# Data source for existing VPC (when not creating new VPC)
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.existing_vpc_id
}

data "aws_subnets" "existing_private" {
  count = var.create_vpc ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
  tags = {
    Type = "private"
  }
}

data "aws_subnets" "existing_intra" {
  count = var.create_vpc ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
  tags = {
    Type = "intra"
  }
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  count  = var.create_eks_cluster ? 1 : 0

  service     = var.service
  environment = var.environment

  cluster_version                          = var.cluster_version
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access

  # Use VPC from module or existing VPC
  vpc_id          = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
  private_subnets = var.create_vpc ? module.vpc[0].private_subnets : data.aws_subnets.existing_private[0].ids
  intra_subnets   = var.create_vpc ? module.vpc[0].intra_subnets : data.aws_subnets.existing_intra[0].ids

  tags = local.tags

  depends_on = [module.vpc]
}