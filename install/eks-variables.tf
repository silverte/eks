# EKS Cluster Version
variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.31"
}

# EKS Cluster endpoint public access (True or False)
variable "cluster_endpoint_public_access" {
  description = "cluster endpoint public access"
  type        = bool
  default     = false
}

# EKS Cluster admin permissions (True or False)
variable "enable_cluster_creator_admin_permissions" {
  description = "cluster admin permissions"
  type        = bool
  default     = true
}

# Whether to create an EKS cluster (True or False)
variable "create_eks_cluster" {
  description = "Whether to create an EKS cluster"
  type        = bool
  default     = false
}
