#!/bin/bash
# KEDA ScaledObject에 HPA behavior 일괄 추가 스크립트

echo "=== KEDA ScaledObject Behavior 패치 시작 ==="

SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

# 함수: ScaledObject 패치
patch_scaledobject() {
    local namespace=$1
    local name=$2
    
    echo "처리 중: $namespace/$name"
    
    # 1. ScaledObject 존재 여부 확인
    if ! kubectl get scaledobject -n "$namespace" "$name" >/dev/null 2>&1; then
        echo "  실패: ScaledObject가 존재하지 않음"
        ((FAIL_COUNT++))
        return 0  # 0으로 반환하여 스크립트 계속 진행
    fi
    
    # 2. 기존 behavior 설정 확인 (더 안전한 방법)
    local existing_behavior=""
    existing_behavior=$(kubectl get scaledobject -n "$namespace" "$name" -o jsonpath='{.spec.advanced.horizontalPodAutoscalerConfig.behavior.scaleUp.stabilizationWindowSeconds}' 2>/dev/null || echo "")
    
    # 3. null이나 빈 값이 아닌 실제 값이 있는지 확인
    if [ -n "$existing_behavior" ] && [ "$existing_behavior" != "null" ] && [ "$existing_behavior" != "<no value>" ]; then
        echo "  스킵: 이미 behavior 설정됨 (stabilizationWindow: ${existing_behavior}초)"
        ((SKIP_COUNT++))
        return 0
    fi
    
    # 4. 패치 적용
    echo "  패치 적용 중..."
    
    local patch_result
    if patch_result=$(kubectl patch scaledobject -n "$namespace" "$name" --type='merge' -p='{
      "spec": {
        "advanced": {
          "horizontalPodAutoscalerConfig": {
            "behavior": {
              "scaleUp": {
                "stabilizationWindowSeconds": 60,
                "policies": [
                  {
                    "type": "Pods",
                    "value": 2,
                    "periodSeconds": 60
                  }
                ]
              }
            }
          }
        }
      }
    }' 2>&1); then
        echo "  성공: 패치 적용 완료"
        ((SUCCESS_COUNT++))
        
        # 5. 적용 결과 검증
        sleep 1
        local verification=""
        verification=$(kubectl get scaledobject -n "$namespace" "$name" -o jsonpath='{.spec.advanced.horizontalPodAutoscalerConfig.behavior.scaleUp.stabilizationWindowSeconds}' 2>/dev/null || echo "")
        if [ "$verification" = "60" ]; then
            echo "  검증: 설정이 정상 적용됨 ✓"
        else
            echo "  경고: 설정 검증 실패 (값: $verification)"
        fi
    else
        echo "  실패: $patch_result"
        ((FAIL_COUNT++))
    fi
    
    return 0  # 항상 0 반환하여 다음 항목 계속 처리
}

# 메인 실행부
echo "대상 ScaledObject 목록:"
kubectl get scaledobject -A --no-headers | awk '{print "- " $1 "/" $2}'
echo ""

# 각 ScaledObject 처리 (while 루프 대신 for 루프 사용)
for line in $(kubectl get scaledobject -A --no-headers | awk '{print $1":"$2}'); do
    if [ -n "$line" ]; then
        namespace=$(echo "$line" | cut -d':' -f1)
        name=$(echo "$line" | cut -d':' -f2)
        
        if [ -n "$namespace" ] && [ -n "$name" ]; then
            patch_scaledobject "$namespace" "$name"
            echo ""  # 가독성을 위한 빈 줄
        fi
    fi
done

# 최종 결과 출력
echo "=== 패치 완료 ==="
echo "✓ 성공: $SUCCESS_COUNT개"
echo "- 스킵: $SKIP_COUNT개"
echo "✗ 실패: $FAIL_COUNT개"
echo ""
echo "적용된 설정:"
echo "  - stabilizationWindowSeconds: 60초"
echo "  - policies: 1분마다 최대 2개 Pod씩 증가"
echo ""
echo "=== 확인 명령어 ==="
echo "# 특정 ScaledObject 확인"
echo "kubectl describe scaledobject -n esp-hcas-prd hpas-bo-ui-hpa | grep -A 15 'Horizontal Pod Autoscaler Config'"
echo ""
echo "# 전체 behavior 설정 확인"
echo "kubectl get scaledobject -A -o jsonpath='{range .items[*]}{.metadata.namespace}{\"\\t\"}{.metadata.name}{\"\\t\"}{.spec.advanced.horizontalPodAutoscalerConfig.behavior.scaleUp.stabilizationWindowSeconds}{\"\\n\"}{end}' | column -t"
