#!/bin/bash

# EKS Terraform Deployment Script
# Usage: ./deploy.sh [vpc-only|eks-only|all]

set -e

DEPLOYMENT_TYPE=${1:-all}

case $DEPLOYMENT_TYPE in
  vpc-only)
    echo "🚀 Deploying VPC only..."
    terraform plan -var-file="vpc-only.tfvars"
    terraform apply -var-file="vpc-only.tfvars" -auto-approve
    ;;
  eks-only)
    echo "🚀 Deploying EKS only..."
    echo "⚠️  Make sure to update existing_vpc_id in eks-only.tfvars"
    terraform plan -var-file="eks-only.tfvars"
    terraform apply -var-file="eks-only.tfvars" -auto-approve
    ;;
  all)
    echo "🚀 Deploying VPC + EKS..."
    terraform plan -var-file="all.tfvars"
    terraform apply -var-file="all.tfvars" -auto-approve
    ;;
  *)
    echo "❌ Invalid deployment type: $DEPLOYMENT_TYPE"
    echo "Usage: $0 [vpc-only|eks-only|all]"
    exit 1
    ;;
esac

echo "✅ Deployment completed successfully!"