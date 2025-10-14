################################################################################
# EKS Module
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"
  create  = var.create_eks_cluster

  # KMS encryption for etcd
  create_kms_key          = true
  enable_kms_key_rotation = true
  kms_key_description     = "EKS cluster encryption key"
  kms_key_administrators  = [data.aws_caller_identity.current.arn]

  cluster_name    = "eks-${var.service}-${var.environment}"
  cluster_version = var.cluster_version

  # Security best practices
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access
  cluster_endpoint_private_access          = true
  cluster_endpoint_public_access_cidrs     = ["0.0.0.0/0"]

  # Logging configuration
  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7

  # Addon configuration with best practices
  cluster_addons = {
    coredns = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      most_recent                 = true
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
          WARM_IP_TARGET           = "5"
          MINIMUM_IP_TARGET        = "2"
        }
        enableNetworkPolicy = "true"
      })
    }
    eks-pod-identity-agent = {
      before_compute              = true
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-efs-csi-driver = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnets
  control_plane_subnet_ids = var.intra_subnets

  # Node group configuration
  eks_managed_node_groups = {
    management = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["c7g.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 3
      desired_size = 2

      disk_size = 50

      update_config = {
        max_unavailable_percentage = 25
      }

      taints = {
        addons = {
          key    = "CriticalAddonsOnly"
          effect = "NO_SCHEDULE"
        }
      }

      labels = {
        "eks.amazonaws.com/nodegroup" = "management"
      }
    }
  }

  tags = var.tags
}

data "aws_caller_identity" "current" {}