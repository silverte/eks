output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc_prd.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc_prd.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc_prd.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc_prd.public_subnets
}

output "intra_subnets" {
  description = "List of IDs of intra subnets"
  value       = module.vpc_prd.intra_subnets
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = module.vpc_prd.natgw_ids
}