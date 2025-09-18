#!/bin/bash
export CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}')
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export NAMESPACE="velero"
export REGION="ap-northeast-2"
export ENVIRONMENT="prd"
export OIDC_ISSUER=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||')

# IAM Policy 생성 (Velero S3 권한)
cat > velero-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload",
                "s3:CreateBucket"
            ],
            "Resource": [
                "arn:aws:s3:::s3-esp-${ENVIRONMENT}-eks-backup",
                "arn:aws:s3:::s3-esp-${ENVIRONMENT}-eks-backup/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Trust Policy 생성
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_ISSUER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_ISSUER}:sub": "system:serviceaccount:velero:velero",
          "${OIDC_ISSUER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# IAM Policy 생성
aws iam create-policy \
  --policy-name policy-esp-${ENVIRONMENT}-velero-backup \
  --policy-document file://velero-policy.json

# IAM 역할 생성
aws iam create-role \
  --role-name role-esp-${ENVIRONMENT}-velero \
  --assume-role-policy-document file://trust-policy.json

# 정책 연결
aws iam attach-role-policy \
  --role-name role-esp-${ENVIRONMENT}-velero \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/policy-esp-${ENVIRONMENT}-velero-backup

# Velero 먼저 설치 (기본 ServiceAccount 생성됨)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.1 \
  --bucket s3-esp-${ENVIRONMENT}-eks-backup \
  --backup-location-config region=${REGION} \
  --no-secret

# 생성된 ServiceAccount에 IRSA Annotation 추가
kubectl annotate serviceaccount velero -n velero \
  eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/role-esp-${ENVIRONMENT}-velero

# Velero Pod 재시작 (Annotation 적용)
kubectl rollout restart deployment velero -n velero
