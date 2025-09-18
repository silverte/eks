#!/bin/bash

export CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}')
export ENVIRONMENT=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}' | awk -F'-' '{print $3}')
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export NAMESPACE="kube-system"
export REGION="ap-northeast-2"

#####################################################################################
# Kyverno
# https://kyverno.io/
#####################################################################################
NODEGROUP="eksng-esp-${ENVIRONMENT}-mgmt"
# kyverno 레포지토리 추가
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

#Kyverno 설치
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set admissionController.nodeSelector."eks\.amazonaws\.com/nodegroup"="$NODEGROUP" \
  --set admissionController.tolerations[0].key="CriticalAddonsOnly" \
  --set admissionController.tolerations[0].operator="Exists" \
  --set admissionController.tolerations[0].effect="NoSchedule" \
  --set admissionController.replicas=3 \
  --set backgroundController.nodeSelector."eks\.amazonaws\.com/nodegroup"="$NODEGROUP" \
  --set backgroundController.tolerations[0].key="CriticalAddonsOnly" \
  --set backgroundController.tolerations[0].operator="Exists" \
  --set backgroundController.tolerations[0].effect="NoSchedule" \
  --set backgroundController.replicas=2 \
  --set cleanupController.nodeSelector."eks\.amazonaws\.com/nodegroup"="$NODEGROUP" \
  --set cleanupController.tolerations[0].key="CriticalAddonsOnly" \
  --set cleanupController.tolerations[0].operator="Exists" \
  --set cleanupController.tolerations[0].effect="NoSchedule" \
  --set cleanupController.replicas=2 \
  --set reportsController.nodeSelector."eks\.amazonaws\.com/nodegroup"="$NODEGROUP" \
  --set reportsController.tolerations[0].key="CriticalAddonsOnly" \
  --set reportsController.tolerations[0].operator="Exists" \
  --set reportsController.tolerations[0].effect="NoSchedule" \
  --set reportsController.replicas=2
