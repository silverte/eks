#!/bin/bash

export CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}')
export ENVIRONMENT=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}' | awk -F'-' '{print $3}')
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export NAMESPACE="kube-system"
export REGION="ap-northeast-2"

#####################################################################################
# AWS Load Balancer Controller
# https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/lbc-helm.html#lbc-helm-install
#####################################################################################
IAM_POLICY_VERSION="v2.13.2"
ALBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"


# Check if the IAM policy already exists
existing_policy_arn=$(aws iam list-policies --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text)
if [ -z "$existing_policy_arn" ]; then
    # IAM Policy for AWS Load Balancer Controller
    curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${IAM_POLICY_VERSION}/docs/install/iam_policy.json

    # Create IAM Policy for AWS Load Balancer Controller
    aws iam create-policy \
        --policy-name $ALBC_POLICY_NAME \
        --policy-document file://iam_policy.json
    echo "Policy ${ALBC_POLICY_NAME} has been created."
else
    echo "Policy ${ALBC_POLICY_NAME} already exists. Skipping creation."
fi

# Create Service Account for AWS Load Balancer Controller
eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --namespace=${NAMESPACE} \
  --name=aws-load-balancer-controller \
  --role-name "role-esp-${ENVIRONMENT}-albc" \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
                             --namespace ${NAMESPACE} \
                             --set clusterName=${CLUSTER_NAME} \
                             --set serviceAccount.create=false \
                             --set serviceAccount.name=aws-load-balancer-controller \
                             --set tolerations[0].key=CriticalAddonsOnly \
                             --set tolerations[0].operator=Exists \
                             --set tolerations[0].effect=NoSchedule \
                             --set region=$REGION \
                             --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.vpcId' --output text)

