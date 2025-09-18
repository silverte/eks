#!/bin/bash

NAMESPACE="${NAMESPACE:-esp-fo-prd}"
DEPLOYMENT="${DEPLOYMENT:-fo-customer-green-app-prd}"

case "${1:-help}" in
    "add")
        echo "🔧 사이드카 추가 중..."
        kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{
          "spec": {
            "template": {
              "spec": {
                "containers": [
                  {
                    "name": "stress",
                    "image": "public.ecr.aws/amazonlinux/amazonlinux:2023-minimal",
                    "command": ["/bin/bash"],
                    "args": ["-c", "microdnf update -y && microdnf install -y stress-ng procps-ng && echo \"stress-ng ready\" && if [ \"${STRESS_ENABLED:-false}\" = \"true\" ]; then stress-ng --cpu ${STRESS_CPU:-1} --cpu-load ${STRESS_LOAD:-70} --timeout 0; else while true; do sleep 60; done; fi"],
                    "env": [
                      {"name": "STRESS_ENABLED", "value": "false"},
                      {"name": "STRESS_CPU", "value": "1"},
                      {"name": "STRESS_LOAD", "value": "70"}
                    ],
                    "resources": {
                      "requests": {"cpu": "400m", "memory": "512Mi"},
                      "limits": {"memory": "512Mi"}
                    }
                  }
                ]
              }
            }
          }
        }' && echo "✅ 사이드카 추가 완료"
        ;;
    "on")
        echo "⚡ Stress 활성화 중..."
        kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p "{
          \"spec\": {
            \"template\": {
              \"spec\": {
                \"containers\": [
                  {
                    \"name\": \"stress\",
                    \"env\": [
                      {\"name\": \"STRESS_ENABLED\", \"value\": \"true\"},
                      {\"name\": \"STRESS_CPU\", \"value\": \"${STRESS_CPU:-1}\"},
                      {\"name\": \"STRESS_LOAD\", \"value\": \"${STRESS_LOAD:-70}\"}
                    ]
                  }
                ]
              }
            }
          }
        }" && echo "🔥 Stress 활성화 완료"
        ;;
    "off")
        echo "⏹️ Stress 비활성화 중..."
        kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{
          "spec": {
            "template": {
              "spec": {
                "containers": [
                  {
                    "name": "stress",
                    "env": [{"name": "STRESS_ENABLED", "value": "false"}]
                  }
                ]
              }
            }
          }
        }' && echo "💤 Stress 비활성화 완료"
        ;;
    "rm")
        echo "🗑️ 사이드카 제거 중..."
        kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type='merge' -p "{
          \"spec\": {
            \"template\": {
              \"spec\": {
                \"containers\": $(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o json | jq '[.spec.template.spec.containers[] | select(.name != "stress")]')
              }
            }
          }
        }" && echo "🧹 사이드카 제거 완료"
        ;;
    *)
        echo "사용법: $0 [add|on|off|rm]"
        echo ""
        echo "명령어:"
        echo "  add  - 사이드카 추가"
        echo "  on   - stress 활성화"
        echo "  off  - stress 비활성화"
        echo "  rm   - 사이드카 제거"
        echo ""
        echo "환경변수:"
        echo "  NAMESPACE=$NAMESPACE"
        echo "  DEPLOYMENT=$DEPLOYMENT"
        echo "  STRESS_CPU=1 (활성화시)"
        echo "  STRESS_LOAD=70 (활성화시)"
        echo ""
        echo "예제:"
        echo "  $0 add                    # 사이드카 추가"
        echo "  $0 on                     # 1개 CPU로 활성화"
        echo "  STRESS_CPU=4 $0 on        # 4개 CPU로 활성화"
        echo "  $0 off                    # 비활성화"
        echo "  $0 rm                     # 제거"
        ;;
esac

