# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = var.create_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = var.create_vpc ? module.vpc[0].private_subnets : data.aws_subnets.existing_private[0].ids
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = var.create_vpc ? module.vpc[0].public_subnets : []
}

# EKS Outputs
output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = var.create_eks_cluster ? module.eks[0].cluster_id : null
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = var.create_eks_cluster ? module.eks[0].cluster_endpoint : null
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = var.create_eks_cluster ? module.eks[0].cluster_security_group_id : null
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = var.create_eks_cluster ? module.eks[0].oidc_provider_arn : null
}