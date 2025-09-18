# Generic Variables
region      = "us-west-2"
service     = "born2k"
environment = "prd"
owners      = "silvrete@sk.com"
accounts = {
}

# VPC Prd Variables
create_vpc_prd          = true
cidr_prd                = "10.3.0.0/18"
public_subnets_prd      = ["10.3.33.192/28", "10.3.33.208/28"]
elb_subnets_prd         = ["10.3.33.128/27", "10.3.33.160/27"]
app_subnets_prd         = ["10.3.0.0/20", "10.3.16.0/20"]
database_subnets_prd    = ["10.3.32.0/25", "10.3.32.128/25"]
endpoint_subnets_prd    = ["10.3.33.0/26", "10.3.33.64/26"]
enable_nat_gateway_prd  = true
single_nat_gateway_prd  = true
enable_vpc_flow_log_prd = false

# EKS Variables
create_eks_cluster                       = true
cluster_version                          = "1.33"
cluster_endpoint_public_access           = true
enable_cluster_creator_admin_permissions = true
