#!/bin/bash
REGION=$(aws configure get region)

# S3 버킷 생성
aws s3api create-bucket --bucket s3-born2k-prd-terraform-state --region ${REGION} --create-bucket-configuration LocationConstraint=${REGION}

# DynamoDB 생성(lock)
aws dynamodb create-table \
    --table-name terraform-lock-table \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
    --region ${REGION}