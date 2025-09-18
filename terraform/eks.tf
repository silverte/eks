################################################################################
# EKS Module
# reference: https://github.com/terraform-aws-modules/terraform-aws-eks
#            https://github.com/aws-ia/terraform-aws-eks-blueprints
#            https://github.com/aws-ia/terraform-aws-eks-blueprints-addon
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31.4"
  create  = var.create_eks_cluster

  create_kms_key                = false
  enable_kms_key_rotation       = false
  kms_key_enable_default_policy = false
  cluster_encryption_config     = {}

  cluster_name                     = "eks-${var.service}-${var.environment}"
  cluster_version                  = var.cluster_version
  attach_cluster_encryption_policy = false

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access
  cluster_security_group_name              = "scg-${var.service}-${var.environment}-eks-cluster"
  cluster_security_group_description       = "EKS cluster security group"
  cluster_security_group_use_name_prefix   = false
  cluster_security_group_tags = merge(
    local.tags,
    {
      "Name" = "scg-${var.service}-${var.environment}-eks-cluster"
    },
  )

  bootstrap_self_managed_addons = false
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
        # Network Policy
        enableNetworkPolicy : "true",
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    aws-efs-csi-driver = {
      most_recent              = true
      service_account_role_arn = try(module.efs_csi_irsa_role[0].iam_role_arn, "")
    }
    # aws-mountpoint-s3-csi-driver = {
    #   most_recent              = true
    #   service_account_role_arn = try(module.mountpoint_s3_csi_irsa_role[0].iam_role_arn, "")
    # }
    metrics-server = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc_prd.vpc_id
  subnet_ids               = module.vpc_prd.private_subnets
  control_plane_subnet_ids = module.vpc_prd.intra_subnets

  node_security_group_name            = "scg-${var.service}-${var.environment}-node"
  node_security_group_description     = "EKS node security group"
  node_security_group_use_name_prefix = false
  node_security_group_tags = merge(
    local.tags,
    {
      "karpenter.sh/discovery" = "eks-${var.service}-${var.environment}",
      "Name"                   = "scg-${var.service}-${var.environment}-eks-node"
    },
  )

  eks_managed_node_groups = {
    management = {
      ami_type         = "AL2023_ARM_64_STANDARD"
      name             = "eksng-${var.service}-${var.environment}-mgmt"
      use_name_prefix  = false
      instance_types   = ["c7g.large"]
      capacity_type    = "ON_DEMAND"
      user_data_script = file("${path.module}/eks-user-data.sh")

      lanch_template_name             = "ekslt-${var.environment}-mgmt"
      launch_template_use_name_prefix = false
      launch_template_tags = merge(
        local.tags,
        {
          "Name" = "ekslt-${var.service}-${var.environment}-mgmt"
        }
      )

      min_size     = 1
      max_size     = 2
      desired_size = 2

      ebs_optimized           = false
      disable_api_termination = false
      enable_monitoring       = false

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      taints = {
        addons = {
          key    = "CriticalAddonsOnly"
          effect = "NO_SCHEDULE"
        },
      }
    }
  }

  tags = merge(
    local.tags,
    {
      "Name"                   = "eks-${var.service}-${var.environment}"
      "karpenter.sh/discovery" = "eks-${var.service}-${var.environment}"
    }
  )
}

module "efs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  count  = var.create_eks_cluster ? 1 : 0

  role_name             = "role-${var.service}-${var.environment}-efs-csi-driver"
  attach_efs_csi_policy = true
  tags = merge(
    local.tags,
    {
      "Name" = "role-${var.service}-${var.environment}-efs-csi-driver"
    }
  )

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}

# module "mountpoint_s3_csi_irsa_role" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   count  = var.create_eks_cluster ? 1 : 0

#   role_name = "role-${var.service}-${var.environment}-s3-csi-driver"
#   tags = merge(
#     local.tags,
#     {
#       "Name" = "role-${var.service}-${var.environment}-s3-csi-driver"
#     }
#   )
#   attach_mountpoint_s3_csi_policy = true
#   mountpoint_s3_csi_bucket_arns   = ["arn:aws:s3:::s3-${var.service}-${var.environment}-cm-contents", "arn:aws:s3:::s3-${var.service}-${var.environment}-cm-files", "arn:aws:s3:::s3-${var.service}-${var.environment}-fo-static"]
#   mountpoint_s3_csi_path_arns     = ["arn:aws:s3:::s3-e${var.service}-${var.environment}-contents/*", "arn:aws:s3:::s3-${var.service}-${var.environment}-cm-files/*", "arn:aws:s3:::s3-${var.service}-${var.environment}-fo-static/*"]

#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:s3-csi-driver-sa"]
#     }
#   }
# }
