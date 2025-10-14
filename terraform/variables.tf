# Common Variables
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "service" {
  description = "Service name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "owners" {
  description = "Owner information"
  type        = string
  default     = "devops@company.com"
}

# Control Variables
variable "create_vpc" {
  description = "Controls if VPC should be created"
  type        = bool
  default     = true
}

variable "create_eks_cluster" {
  description = "Controls if EKS cluster should be created"
  type        = bool
  default     = true
}

# Existing VPC Variables (when create_vpc = false)
variable "existing_vpc_id" {
  description = "ID of existing VPC to use"
  type        = string
  default     = ""
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
}

variable "intra_subnets" {
  description = "A list of intra subnets"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Should be true to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Should be true to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Should be true if you want to create a new VPN Gateway resource and attach it to the VPC"
  type        = bool
  default     = false
}

# EKS Variables
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