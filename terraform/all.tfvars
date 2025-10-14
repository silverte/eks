# Full Deployment (VPC + EKS)
create_vpc         = true
create_eks_cluster = true

# Common
region      = "ap-northeast-2"
service     = "born2k"
environment = "prd"
owners      = "silvrete@sk.com"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
intra_subnets      = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

enable_nat_gateway     = true
single_nat_gateway     = false
one_nat_gateway_per_az = true
enable_vpn_gateway     = false

# EKS Configuration
cluster_version                          = "1.31"
enable_cluster_creator_admin_permissions = true
cluster_endpoint_public_access           = true