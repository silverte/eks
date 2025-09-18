#!/bin/bash

# 환경변수 설정 (기본값 포함)
NAMESPACE="${NAMESPACE:-esp-fo-prd}"
DEPLOYMENT="${DEPLOYMENT:-fo-customer-green-app-prd}"
HPA_NAME="${HPA_NAME:-keda-hpa-fo-customer-green-hpa}"
STRESS_CPU="${STRESS_CPU:-4}"
STRESS_LOAD="${STRESS_LOAD:-70}"

# 색상 코드
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 사용법 출력
show_usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  start    부하 생성 시작"
    echo "  stop     부하 생성 중지"
    echo "  status   현재 상태 확인"
    echo "  monitor  실시간 모니터링"
    echo "  help     도움말 표시"
    echo ""
    echo "환경변수:"
    echo "  NAMESPACE    (기본: default)"
    echo "  DEPLOYMENT   (기본: nginx-deployment)"
    echo "  HPA_NAME     (기본: keda-hpa-nginx)"
    echo "  STRESS_CPU   (기본: 4)"
    echo "  STRESS_LOAD  (기본: 70)"
    echo ""
    echo "예제:"
    echo "  $0 start"
    echo "  $0 stop"
    echo "  $0 monitor"
    echo "  STRESS_CPU=4 $0 start"
}

# 현재 상태 확인
check_status() {
    echo -e "\n=== 현재 상태 확인 ==="
    warning "네임스페이스: $NAMESPACE"
    warning "Deployment: $DEPLOYMENT"
    warning "HPA: $HPA_NAME"
    
    echo -e "\nDeployment 상태:"
    kubectl get deployment $DEPLOYMENT -n $NAMESPACE 2>/dev/null || error "Deployment를 찾을 수 없습니다."
    
    echo -e "\nPod 상태:"
    kubectl get pods -n $NAMESPACE -l amdp.io/app=fo-customer-green 2>/dev/null || echo "Pod를 찾을 수 없습니다."
    
    echo -e "\nHPA 상태:"
    kubectl get hpa $HPA_NAME -n $NAMESPACE 2>/dev/null || error "HPA를 찾을 수 없습니다."
    
    echo -e "\nCPU 사용률:"
    kubectl top pods -n $NAMESPACE -l app=nginx 2>/dev/null || warning "메트릭 수집 중..."
    
    # stress 컨테이너 환경변수 확인
    echo -e "\nStress 설정 확인:"
    local pod_name=$(kubectl get pods -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$pod_name" ]; then
        local stress_enabled=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.spec.containers[?(@.name=="stress")].env[?(@.name=="STRESS_ENABLED")].value}' 2>/dev/null)
        if [ "$stress_enabled" = "true" ]; then
            success "Stress가 활성화되어 있습니다."
        else
            warning "Stress가 비활성화되어 있습니다."
        fi
    fi
}

# 부하 생성 시작
start_stress() {
    echo -e "\n=== 부하 생성 시작 ==="
    warning "CPU 워커: $STRESS_CPU"
    warning "CPU 부하: $STRESS_LOAD%"
    
    log "환경변수로 stress 활성화 중..."
    
    # Deployment에서 환경변수 변경으로 부하 활성화
    kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p "{
      \"spec\": {
        \"template\": {
          \"spec\": {
            \"containers\": [
              {
                \"name\": \"stress\",
                \"env\": [
                  {\"name\": \"STRESS_ENABLED\", \"value\": \"true\"},
                  {\"name\": \"STRESS_CPU\", \"value\": \"$STRESS_CPU\"},
                  {\"name\": \"STRESS_LOAD\", \"value\": \"$STRESS_LOAD\"}
                ]
              }
            ]
          }
        }
      }
    }"
    
    if [ $? -eq 0 ]; then
        success "부하 활성화 패치 완료!"
        
        log "Pod 재시작 대기 중..."
        kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s
        
        if [ $? -eq 0 ]; then
            success "Deployment 롤아웃 완료!"
            check_status
            
            echo -e "\n부하 생성이 활성화되었습니다!"
            echo "다음 명령어로 모니터링할 수 있습니다:"
            echo "  $0 monitor"
            echo "  $0 status"
        else
            error "롤아웃이 완료되지 않았습니다."
            exit 1
        fi
    else
        error "패치 실패!"
        exit 1
    fi
}

# 부하 생성 중지
stop_stress() {
    echo -e "\n=== 부하 생성 중지 ==="
    
    log "stress 비활성화 중..."
    
    # Deployment에서 환경변수 변경으로 부하 비활성화
    kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{
      "spec": {
        "template": {
          "spec": {
            "containers": [
              {
                "name": "stress",
                "env": [
                  {"name": "STRESS_ENABLED", "value": "false"}
                ]
              }
            ]
          }
        }
      }
    }'
    
    if [ $? -eq 0 ]; then
        success "부하 비활성화 패치 완료!"
        
        log "Pod 재시작 대기 중..."
        kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s
        
        if [ $? -eq 0 ]; then
            success "Deployment 롤아웃 완료!"
            check_status
            
            echo -e "\n부하 생성이 중지되었습니다!"
        else
            error "롤아웃이 완료되지 않았습니다."
            exit 1
        fi
    else
        error "패치 실패!"
        exit 1
    fi
}

# 실시간 모니터링
monitor_stress() {
    echo -e "\n=== 실시간 모니터링 시작 ==="
    echo "Ctrl+C로 중지할 수 있습니다."
    echo ""
    
    # 모니터링 카운터
    local count=0
    
    while true; do
        clear
        echo "=== Stress HPA 모니터링 - $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "업데이트 횟수: $((++count))"
        echo ""
        
        # HPA 상태
        echo "🎯 HPA 상태:"
        kubectl get hpa $HPA_NAME -n $NAMESPACE 2>/dev/null || error "HPA를 찾을 수 없습니다."
        echo ""
        
        # Pod 상태
        echo "📦 Pod 상태:"
        kubectl get pods -n $NAMESPACE -l amdp.io/app=fo-customer-green --no-headers 2>/dev/null 
        local pod_count=$(kubectl get pods -n $NAMESPACE -l amdp.io/app=fo-customer-green --no-headers 2>/dev/null | wc -l)
        echo "총 Pod 수: $pod_count"
        echo ""
        
        # CPU 사용률
        echo "💻 CPU 사용률:"
        kubectl top pods -n $NAMESPACE -l amdp.io/app=fo-customer-green --no-headers 2>/dev/null | head -5 || warning "메트릭 수집 중..."
        echo ""
        
        # Deployment 상태
        echo "🚀 Deployment 상태:"
        kubectl get deployment $DEPLOYMENT -n $NAMESPACE --no-headers 2>/dev/null || error "Deployment를 찾을 수 없습니다."
        echo ""
        
        # Stress 상태 확인
        local pod_name=$(kubectl get pods -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ ! -z "$pod_name" ]; then
            local stress_enabled=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.spec.containers[?(@.name=="stress")].env[?(@.name=="STRESS_ENABLED")].value}' 2>/dev/null)
            if [ "$stress_enabled" = "true" ]; then
                echo "⚡ Stress 상태: 활성화"
            else
                echo "💤 Stress 상태: 비활성화"
            fi
        fi
        
        echo ""
        echo "다음 업데이트까지 10초... (Ctrl+C로 종료)"
        sleep 10
    done
}

# 메인 로직
case "${1:-help}" in
    "start")
        start_stress
        ;;
    "stop")
        stop_stress
        ;;
    "status")
        check_status
        ;;
    "monitor")
        monitor_stress
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "알 수 없는 옵션: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
