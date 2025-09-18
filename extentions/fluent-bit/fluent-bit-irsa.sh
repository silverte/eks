#!/bin/bash

export CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}')
export ENVIRONMENT=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}' | awk -F'-' '{print $3}')
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export NAMESPACE="kube-system"
export REGION="ap-northeast-2"

#####################################################################################
# AWS for Fluent Bit IRSA
# https://github.com/aws/aws-for-fluent-bit
#####################################################################################
SERVICE_ACCOUNT_NAME="fluent-bit"
SERVICE_ACCOUNT_NAMESPACE="logging"
FLUENT_BIT_POLICY_NAME="policy-esp-${ENVIRONMENT}-aws-for-fluent-bit"
FLUENT_BIT_POLICY_FILE="policy-esp-${ENVIRONMENT}-aws-for-fluent-bit.json"
FLUENT_BIT_ROLE_NAME="role-esp-${ENVIRONMENT}-aws-for-fluent-bit"
S3_BUCKET="s3-esp-${ENVIRONMENT}-app-logs"

cat > $FLUENT_BIT_POLICY_FILE <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": [
        "arn:aws:s3:::$S3_BUCKET",
        "arn:aws:s3:::$S3_BUCKET/*"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name $FLUENT_BIT_POLICY_NAME \
  --policy-document file://$FLUENT_BIT_POLICY_FILE

eksctl create iamserviceaccount \
  --name $SERVICE_ACCOUNT_NAME \
  --namespace $SERVICE_ACCOUNT_NAMESPACE \
  --override-existing-serviceaccounts \
  --role-name $FLUENT_BIT_ROLE_NAME \
  --cluster $CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$FLUENT_BIT_POLICY_NAME \
  --approve \
  --region $REGION

rm -f $FLUENT_BIT_POLICY_FILE
