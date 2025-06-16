#!/bin/bash
# =============================================================================
# EKS Upgrade Step 1: Control Plane & AMI Pinning
# =============================================================================

set -e

# 환경 변수 설정
CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}' | awk -F'/' '{print $2}')
ENVIRONMENT=$(echo $CLUSTER_NAME | awk -F'-' '{print $3}')
REGION="ap-northeast-2"
ACCOUNT_NUM=$(aws sts get-caller-identity --query Account --output text)

# 색상 코드
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 사용법
show_usage() {
    cat << EOF
Usage: $0 <KUBERNETES_VERSION>

Step 1: EKS Control Plane Upgrade & AMI Pinning
- 컨트롤 플레인을 안전하게 업그레이드
- Karpenter AMI 버전을 고정하여 drift 방지
- 멱등성 보장: 동일 버전 재실행 시 안전 처리

Examples:
  $0 1.33

EOF
    exit 1
}

# 인수 확인
if [ $# -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
fi

TARGET_VERSION=$1

# 버전 형식 검증
if [[ ! $TARGET_VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
    log_error "잘못된 버전 형식입니다. 예: 1.33"
    exit 1
fi

# 현재 버전 확인
CURRENT_VERSION=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.version' --output text)

log_info "=== Step 1: EKS Control Plane Upgrade ==="
log_info "클러스터: $CLUSTER_NAME"
log_info "환경: $ENVIRONMENT"
log_info "현재 버전: $CURRENT_VERSION"
log_info "대상 버전: $TARGET_VERSION"
echo

# Karpenter 확인
check_karpenter() {
    kubectl get deployment -n kube-system karpenter >/dev/null 2>&1
}

# 최신 AMI 버전 조회
get_latest_ami_version() {
    local k8s_version=$1
    local ami_family=$2
    local arch=$3

    local ssm_path="/aws/service/eks/optimized-ami/${k8s_version}/${ami_family}/${arch}/standard/recommended"
    local ami_info=$(aws ssm get-parameters --names "$ssm_path" --region "$REGION" --query 'Parameters[0].Value' --output text 2>/dev/null)

    if [ $? -eq 0 ] && [ ! -z "$ami_info" ]; then
        local ami_name=$(echo "$ami_info" | jq -r '.image_name' 2>/dev/null)
        local version=$(echo "$ami_name" | grep -o 'v[0-9]\{8\}' | head -1)
        echo "$version"
        return 0
    fi
    return 1
}

# AMI 버전 고정
pin_ami_versions() {
    log_info "=== AMI 버전 고정 ==="

    if ! check_karpenter; then
        log_info "Karpenter가 설치되지 않음, AMI 고정 건너뛰기"
        return 0
    fi

    local nodeclasses=$(kubectl get ec2nodeclass -o name 2>/dev/null || echo "")
    if [ -z "$nodeclasses" ]; then
        log_info "EC2NodeClass가 없음, AMI 고정 건너뛰기"
        return 0
    fi

    # 백업 디렉토리 생성
    mkdir -p ./karpenter-backup

    for nodeclass in $nodeclasses; do
        local nodeclass_name=$(echo $nodeclass | cut -d'/' -f2)
        log_info "처리 중: EC2NodeClass $nodeclass_name"

        # 백업 생성
        kubectl get $nodeclass -o yaml > ./karpenter-backup/ec2nodeclass-$nodeclass_name.yaml

        local current_alias=$(kubectl get $nodeclass -o jsonpath='{.spec.amiSelectorTerms[0].alias}' 2>/dev/null)

        if [ -z "$current_alias" ] || [ "$current_alias" = "null" ]; then
            log_info "  alias가 없음, 건너뛰기"
            continue
        fi

        local ami_family=$(echo "$current_alias" | cut -d'@' -f1)
        local arch="x86_64"

        # ARM64 아키텍처 감지
        local requirements=$(kubectl get $nodeclass -o jsonpath='{.spec.requirements}' 2>/dev/null)
        if echo "$requirements" | grep -q "arm64"; then
            arch="arm64"
        fi

        case $ami_family in
            "al2023") local ami_path="amazon-linux-2023" ;;
            "al2") local ami_path="amazon-linux-2" ;;
            *)
                log_info "  지원하지 않는 AMI family: $ami_family, 건너뛰기"
                continue
                ;;
        esac

        local latest_version=$(get_latest_ami_version "$TARGET_VERSION" "$ami_path" "$arch")

        if [ $? -eq 0 ] && [ ! -z "$latest_version" ]; then
            local new_alias="${ami_family}@${latest_version}"

            if [ "$current_alias" = "$new_alias" ]; then
                log_success "  이미 올바른 버전: $current_alias"
            else
                log_info "  업데이트: $current_alias → $new_alias"
                kubectl patch $nodeclass --type='json' \
                    -p="[{\"op\": \"replace\", \"path\": \"/spec/amiSelectorTerms/0/alias\", \"value\": \"$new_alias\"}]"

                if [ $? -eq 0 ]; then
                    log_success "  AMI 버전 업데이트 완료"
                else
                    log_error "  AMI 버전 업데이트 실패"
                fi
            fi
        else
            log_warning "  AMI 버전을 확인할 수 없음, 현재 설정 유지"
        fi
    done

    log_success "AMI 버전 고정 완료"
    echo
}
# Karpenter drift 비활성화 (노드 교체 방지)
disable_karpenter_drift() {
    log_info "=== Karpenter Drift 비활성화 ==="

    if ! check_karpenter; then
        log_info "Karpenter가 설치되지 않음, drift 제어 건너뛰기"
        return 0
    fi

    local nodepools=$(kubectl get nodepools.karpenter.sh -o name 2>/dev/null || echo "")
    if [ -z "$nodepools" ]; then
        log_info "NodePool이 없음, 건너뛰기"
        return 0
    fi

    # NodePool 백업
    for nodepool in $nodepools; do
        local nodepool_name=$(echo $nodepool | cut -d'/' -f2)
        kubectl get $nodepool -o yaml > ./karpenter-backup/nodepool-$nodepool_name.yaml
    done

    # 모든 Karpenter 노드에 do-not-disrupt 어노테이션 추가
    kubectl annotate nodes -l karpenter.sh/nodepool karpenter.sh/do-not-disrupt=true --overwrite || true

    log_success "Karpenter drift 비활성화 완료 (노드 교체 방지)"
    echo
}

# 컨트롤 플레인 업그레이드
upgrade_control_plane() {
    log_info "=== 컨트롤 플레인 업그레이드 ==="

    if [ "$CURRENT_VERSION" = "$TARGET_VERSION" ]; then
        log_success "컨트롤 플레인이 이미 대상 버전입니다: $TARGET_VERSION"
        return 0
    fi

    log_info "컨트롤 플레인 업그레이드 시작: $CURRENT_VERSION → $TARGET_VERSION"

    eksctl upgrade cluster \
        --name=$CLUSTER_NAME \
        --region=$REGION \
        --version=$TARGET_VERSION \
        --approve

    log_info "컨트롤 플레인 활성화 대기 중..."
    aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION

    # 검증
    local updated_version=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.version' --output text)
    if [ "$updated_version" = "$TARGET_VERSION" ]; then
        log_success "컨트롤 플레인 업그레이드 완료: $TARGET_VERSION"
    else
        log_error "컨트롤 플레인 업그레이드 검증 실패"
        exit 1
    fi
    echo
}

# 상태 저장
save_state() {
    cat > .upgrade-state << EOF
CLUSTER_NAME=$CLUSTER_NAME
ENVIRONMENT=$ENVIRONMENT
REGION=$REGION
ACCOUNT_NUM=$ACCOUNT_NUM
TARGET_VERSION=$TARGET_VERSION
CONTROL_PLANE_UPGRADED=true
UPGRADE_STEP1_TIMESTAMP=$(date +%Y%m%d%H%M%S)
EOF
    log_info "업그레이드 상태 저장: .upgrade-state"
}

# 메인 실행
main() {
    echo
    log_warning "Step 1에서 수행할 작업:"
    log_warning "1. Karpenter AMI 버전 고정"
    log_warning "2. Karpenter drift 비활성화 (노드 교체 방지)"
    log_warning "3. EKS 컨트롤 플레인 업그레이드"
    echo
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Step 1이 취소되었습니다."
        exit 0
    fi

    echo
    pin_ami_versions
    disable_karpenter_drift
    upgrade_control_plane
    save_state

    log_success "=== Step 1 완료 ==="
    log_success "컨트롤 플레인이 Kubernetes $TARGET_VERSION으로 업그레이드되었습니다"
    echo
    log_info "다음 단계:"
    log_info "1. 클러스터 상태 확인"
    log_info "2. Step 2 실행: ./eks-upgrade-step2.sh"
    log_info "3. 애드온 업그레이드 완료 후 Step 3 실행"
}

# 실행
main