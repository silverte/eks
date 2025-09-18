#!/bin/bash
export ENVIRONMENT=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}'| awk -F'/' '{print $2}' | awk -F'-' '{print $3}')

NAMESPACES=(
  esp-fo-${ENVIRONMENT}
  esp-hims-${ENVIRONMENT}
  esp-if-${ENVIRONMENT}
  esp-hcas-${ENVIRONMENT}
  esp-hpas-${ENVIRONMENT}
)

for ns in "${NAMESPACES[@]}"; do
  echo "Processing namespace: $ns"
  deployments=$(kubectl get deploy -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

  for deploy in $deployments; do
    filename="${deploy}-${ns}-scaledobject.yaml"
    echo "Generating: $filename"

    cat <<EOF > "$filename"
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: ${deploy}-cron-scaler
  namespace: ${ns}
spec:
  scaleTargetRef:
    name: ${deploy}
  minReplicaCount: 0
  maxReplicaCount: 2
  triggers:
    - type: cron
      metadata:
        timezone: Asia/Seoul
        start: 00 08 * * *
        end: 00 23 * * *
        desiredReplicas: "2"
EOF

  done
done
