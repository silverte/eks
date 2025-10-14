variable "create_eks_cluster" {
  description = "Controls if EKS cluster should be created"
  type        = bool
  default     = true
}

variable "service" {
  description = "Service name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Indicates whether or not to add the cluster creator as an administrator"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of the VPC where to create security group"
  type        = string
}

variable "private_subnets" {
  description = "A list of private subnet IDs"
  type        = list(string)
}

variable "intra_subnets" {
  description = "A list of intra subnet IDs"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}