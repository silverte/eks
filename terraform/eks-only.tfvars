# EKS Only Deployment (using existing VPC)
create_vpc         = false
create_eks_cluster = true

# Common
region      = "ap-northeast-2"
service     = "born2k"
environment = "prd"
owners      = "silvrete@sk.com"

# Existing VPC (replace with actual VPC ID)
existing_vpc_id = "vpc-xxxxxxxxx"

# EKS Configuration
cluster_version                          = "1.31"
enable_cluster_creator_admin_permissions = true
cluster_endpoint_public_access           = true