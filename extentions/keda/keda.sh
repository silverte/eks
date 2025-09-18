#!/bin/bash

export CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}')
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export NAMESPACE="kube-system"
export REGION="ap-northeast-2"
export ENVIRONMENT="prd"

#####################################################################################
# KEDA
# https://keda.sh/
#####################################################################################

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace $NAMESPACE \
              --set tolerations[0].key=CriticalAddonsOnly \
              --set tolerations[0].operator=Exists \
              --set tolerations[0].effect=NoSchedule
