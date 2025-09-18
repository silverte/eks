#!/bin/bash
# =============================================================================
#
# EKS Upgrade Step 2: Add-ons Upgrade  
# =============================================================================

set -e

# 색상 코드
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 상태 파일 확인
if [ ! -f .upgrade-state ]; then
    log_error ".upgrade-state 파일이 없습니다. Step 1을 먼저 실행하세요."
    exit 1
fi

source ./.upgrade-state

if [ "$CONTROL_PLANE_UPGRADED" != "true" ]; then
    log_error "Step 1이 완료되지 않았습니다. Step 1을 먼저 실행하세요."
    exit 1
fi

log_info "=== Step 2: EKS Add-ons Upgrade ==="
log_info "클러스터: $CLUSTER_NAME"
log_info "Kubernetes 버전: $TARGET_VERSION"
echo

# 애드온 업그레이드
upgrade_addon() {
    local addon_name=$1
    local role_arn=$2
    
    if ! eksctl get addon --cluster $CLUSTER_NAME --region $REGION --name $addon_name >/dev/null 2>&1; then
        log_info "$addon_name 애드온이 설치되지 않음, 건너뛰기"
        return 0
    fi
    
    local current_version=$(aws eks describe-addon \
        --cluster-name $CLUSTER_NAME \
        --addon-name $addon_name \
        --region $REGION \
        --query 'addon.addonVersion' \
        --output text 2>/dev/null || echo "unknown")
    
    local latest_version=$(aws eks describe-addon-versions \
        --addon-name $addon_name \
        --kubernetes-version $TARGET_VERSION \
        --region $REGION \
        --query 'addons[0].addonVersions[0].addonVersion' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$latest_version" ]; then
        log_warning "$addon_name 최신 버전을 확인할 수 없음"
        return 1
    fi
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "$addon_name 이미 최신 버전: $current_version"
        return 0
    fi
    
    log_info "$addon_name 업데이트: $current_version → $latest_version"
    
    local cmd="eksctl update addon --name $addon_name --version $latest_version --cluster $CLUSTER_NAME --region $REGION --force"
    if [ ! -z "$role_arn" ]; then
        cmd="$cmd --service-account-role-arn $role_arn"
    fi
    
    if eval $cmd; then
        # 활성화 대기
        local timeout=300
        local elapsed=0
        while [ $elapsed -lt $timeout ]; do
            local status=$(aws eks describe-addon \
                --cluster-name $CLUSTER_NAME \
                --addon-name $addon_name \
                --region $REGION \
                --query 'addon.status' \
                --output text 2>/dev/null || echo "UNKNOWN")
            
            if [ "$status" = "ACTIVE" ]; then
                log_success "$addon_name 업그레이드 완료"
                return 0
            elif [ "$status" = "UPDATE_FAILED" ]; then
                log_error "$addon_name 업그레이드 실패"
                return 1
            fi
            
            sleep 10
            elapsed=$((elapsed + 10))
        done
        
        log_error "$addon_name 업그레이드 시간 초과"
        return 1
    else
        log_error "$addon_name 업그레이드 실패"
        return 1
    fi
}

# 메인 실행
main() {
    echo
    log_warning "Step 2에서 수행할 작업:"
    log_warning "- 모든 EKS 애드온을 Kubernetes $TARGET_VERSION 호환 버전으로 업그레이드"
    echo
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Step 2가 취소되었습니다."
        exit 0
    fi
    
    echo
    log_info "애드온 업그레이드 시작..."
    
    # 중요 순서대로 애드온 업그레이드
    FAILED_ADDONS=()
    
    # 1. 네트워킹 기본 요소
    upgrade_addon "kube-proxy" "" || FAILED_ADDONS+=("kube-proxy")
    upgrade_addon "coredns" "" || FAILED_ADDONS+=("coredns")
    upgrade_addon "vpc-cni" "" || FAILED_ADDONS+=("vpc-cni")  # force 없이
    
    # 2. 보안 및 인증
    upgrade_addon "eks-pod-identity-agent" "" || FAILED_ADDONS+=("eks-pod-identity-agent")
    
    # 3. 스토리지 드라이버
    local efs_role="arn:aws:iam::${ACCOUNT_NUM}:role/role-esp-${ENVIRONMENT}-efs-csi-driver"
    local s3_role="arn:aws:iam::${ACCOUNT_NUM}:role/role-esp-${ENVIRONMENT}-s3-csi-driver"
    
    upgrade_addon "aws-efs-csi-driver" "$efs_role" || FAILED_ADDONS+=("aws-efs-csi-driver")
    upgrade_addon "aws-mountpoint-s3-csi-driver" "$s3_role" || FAILED_ADDONS+=("aws-mountpoint-s3-csi-driver")
    
    # 결과 요약
    echo
    log_info "=== 애드온 상태 확인 ==="
    eksctl get addon --cluster $CLUSTER_NAME --region $REGION || true
    
    if [ ${#FAILED_ADDONS[@]} -gt 0 ]; then
        echo
        log_warning "실패한 애드온:"
        printf '%s\n' "${FAILED_ADDONS[@]}"
        log_warning "Step 3 진행 전에 문제를 해결하세요."
    else
        echo
        log_success "모든 애드온 업그레이드 완료"
    fi
    
    # 상태 업데이트
    echo "ADDONS_UPGRADED=true" >> .upgrade-state
    echo "UPGRADE_STEP2_TIMESTAMP=$(date +%Y%m%d%H%M%S)" >> .upgrade-state
    
    echo
    log_success "=== Step 2 완료 ==="
    log_info "다음 단계: ./eks-upgrade-step3.sh"
}

main
