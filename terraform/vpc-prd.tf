################################################################################
# VPC Module
# reference: https://github.com/terraform-aws-modules/terraform-aws-vpc
################################################################################
module "vpc_prd" {
  source     = "terraform-aws-modules/vpc/aws"
  version    = "5.13.0"
  create_vpc = var.create_vpc_prd

  # Details
  name                = "vpc-${var.service}-prd"
  cidr                = var.cidr_prd
  azs                 = local.azs
  public_subnets      = var.public_subnets_prd
  private_subnets     = var.app_subnets_prd
  intra_subnets       = var.endpoint_subnets_prd
  database_subnets    = var.database_subnets_prd
  elasticache_subnets = var.elb_subnets_prd

  manage_default_route_table    = false
  manage_default_network_acl    = false
  manage_default_security_group = false
  manage_default_vpc            = false

  # don't create Subnet Group 
  create_database_subnet_group    = false
  create_elasticache_subnet_group = false
  create_redshift_subnet_group    = false

  # Tag subnets
  public_subnet_names      = ["sub-${var.service}-prd-pub-a", "sub-${var.service}-prd-pub-c"]
  private_subnet_names     = ["sub-${var.service}-prd-app-a", "sub-${var.service}-prd-app-c"]
  database_subnet_names    = ["sub-${var.service}-prd-db-a", "sub-${var.service}-prd-db-c"]
  intra_subnet_names       = ["sub-${var.service}-prd-ep-a", "sub-${var.service}-prd-ep-c"]
  elasticache_subnet_names = ["sub-${var.service}-prd-elb-a", "sub-${var.service}-prd-elb-c"]

  # Routing
  create_database_subnet_route_table    = true
  create_elasticache_subnet_route_table = true
  create_redshift_subnet_route_table    = true

  # Tag route table
  public_route_table_tags      = { "Name" : "route-${var.service}-prd-pub" }
  private_route_table_tags     = { "Name" : "route-${var.service}-prd-app" }
  database_route_table_tags    = { "Name" : "route-${var.service}-prd-db" }
  intra_route_table_tags       = { "Name" : "route-${var.service}-prd-ep" }
  elasticache_route_table_tags = { "Name" : "route-${var.service}-prd-elb" }

  igw_tags = { "Name" : "igw-${var.service}-prd" }

  # NAT Gateways - Outbound Communication
  enable_nat_gateway = var.enable_nat_gateway_prd
  single_nat_gateway = var.single_nat_gateway_prd
  nat_gateway_tags   = { "Name" : "nat-${var.service}-prd" }
  nat_eip_tags       = { "Name" : "eip-${var.service}-prd" }

  # DNS Parameters in VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Flow logs
  enable_flow_log                                 = var.enable_vpc_flow_log_prd
  flow_log_destination_type                       = "cloud-watch-logs"
  flow_log_file_format                            = "plain-text"
  flow_log_log_format                             = "$${version} $${vpc-id} $${subnet-id} $${instance-id} $${interface-id} $${account-id} $${type} $${srcaddr} $${dstport} $${srcport} $${dstaddr} $${pkt-dstaddr} $${pkt-srcaddr} $${protocol} $${bytes} $${packets} $${start} $${end} $${action} $${tcp-flags} $${log-status}"
  flow_log_max_aggregation_interval               = 600
  vpc_flow_log_iam_role_name                      = "role-${var.service}-prd-vpc-flow-log"
  vpc_flow_log_iam_role_use_name_prefix           = false
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = 7
  flow_log_cloudwatch_log_group_name_prefix       = "vpcFlowLog"
  flow_log_cloudwatch_log_group_skip_destroy      = true
  flow_log_traffic_type                           = "ALL"
  flow_log_per_hour_partition                     = true

  vpc_flow_log_tags = merge(
    local.tags,
    {
      "Name" = "vpc-${var.service}-prd-flow-logs"
    }
  )

  elasticache_subnet_tags = {
    # Tags subnets for ALBC
    "kubernetes.io/role/internal-elb" = 1
  }

  private_subnet_tags = {
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = "eks-${var.service}-prd"
  }

  # tags for the VPC
  tags = merge(
    local.tags,
    {
      "environment" = "prd"
    }
  )
}
