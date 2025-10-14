terraform {
  # Set minimum required versions for providers using lazy matching
  required_version = ">= 1.9.7"

  # Configure the S3 backend
  backend "s3" {
    bucket = "s3-born2k-prd-terraform-state"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }
}

provider "aws" {
  region = local.region
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}
