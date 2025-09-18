# generic variables defined

# AWS Region
variable "region" {
  description = "Region in which AWS Resources to be created"
  type        = string
  default     = "us-west-2"
}
# Service Name
variable "service" {
  description = "Service Name for workloads"
  type        = string
  default     = "test"
}
# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
  default     = "dev"
}
# Business Division
variable "owners" {
  description = "organization this Infrastructure belongs"
  type        = string
  default     = "born2k"
}

# Account
variable "accounts" {
  description = "AWS Accounts"
  type        = map(string)
  default     = {}
}

# Management EBS KMS key arn
variable "management_ebs_kms_key_arn" {
  description = "Management EBS KMS key arn"
  type        = string
  default     = ""
}

# Management RDS KMS key arn
variable "management_rds_kms_key_arn" {
  description = "Management RDS KMS key arn"
  type        = string
  default     = ""
}

# Map 2.0 Tag
variable "map_migrated" {
  description = "map-migrated"
  type        = string
  default     = ""
}
