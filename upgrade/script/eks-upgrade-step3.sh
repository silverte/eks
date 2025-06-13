#!/bin/bash
# =============================================================================
# EKS Upgrade Step 3: Node Upgrade
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
    log_error ".upgrade-state 파일이 없습니다. Step 1, 2를 먼저 실행하세요."
    exit 1
fi

source ./.upgrade-state

if [ "$ADDONS_UPGRADED" != "true" ]; then
    log_error "Step 2가 완료되지 않았습니다. Step 2를 먼저 실행하세요."
    exit 1
fi

log_info "=== Step 3: Node Groups & Karpenter Node Upgrade ==="
log_info "클러스터: $CLUSTER_NAME"
log_info "Kubernetes 버전: $TARGET_VERSION"
echo

# Karpenter 확인
check_karpenter() {
    kubectl get deployment -n kube-system karpenter >/dev/null 2>&1
}

# 노드 그룹 업그레이드
upgrade_nodegroups() {
    log_info "=== 노드 그룹 업그레이드 ==="

    local nodegroups=$(aws eks list-nodegroups \
        --cluster-name $CLUSTER_NAME \
        --region $REGION \
        --query "nodegroups[]" \
        --output text)

    if [ -z "$nodegroups" ]; then
        log_info "노드 그룹이 없음, 건너뛰기"
        return 0
    fi

    log_info "발견된 노드 그룹: $nodegroups"

    for nodegroup in $nodegroups; do
        local current_version=$(aws eks describe-nodegroup \
            --cluster-name $CLUSTER_NAME \
            --nodegroup-name $nodegroup \
            --region $REGION \
            --query 'nodegroup.version' \
            --output text 2>/dev/null || echo "unknown")

        if [ "$current_version" = "$TARGET_VERSION" ]; then
            log_success "노드 그룹 $nodegroup 이미 대상 버전: $TARGET_VERSION"
        else
            log_info "노드 그룹 업그레이드: $nodegroup ($current_version → $TARGET_VERSION)"

            eksctl upgrade nodegroup \
                --cluster $CLUSTER_NAME \
                --name $nodegroup \
                --kubernetes-version $TARGET_VERSION \
                --region $REGION

            aws eks wait nodegroup-active \
                --cluster-name $CLUSTER_NAME \
                --nodegroup-name $nodegroup \
                --region $REGION

            log_success "노드 그룹 $nodegroup 업그레이드 완료"
        fi
    done

    log_success "노드 그룹 업그레이드 완료"
    echo
}
# Karpenter 노드 교체
rotate_karpenter_nodes() {
    log_info "=== Karpenter 노드 교체 ==="

    if ! check_karpenter; then
        log_info "Karpenter가 설치되지 않음, 노드 교체 건너뛰기"
        return 0
    fi

    local nodepools=$(kubectl get nodepools.karpenter.sh -o name 2>/dev/null || echo "")
    if [ -z "$nodepools" ]; then
        log_info "NodePool이 없음, 건너뛰기"
        return 0
    fi

    # Step 1에서 비활성화한 drift를 다시 활성화
    log_info "Karpenter drift 활성화"
    kubectl annotate nodes -l karpenter.sh/nodepool karpenter.sh/do-not-disrupt- --overwrite 2>/dev/null || true

    # NodePool 설정 복원 (백업이 있는 경우)
    for nodepool in $nodepools; do
        local nodepool_name=$(echo $nodepool | cut -d'/' -f2)
        local backup_file="./karpenter-backup/nodepool-$nodepool_name.yaml"

        if [ -f "$backup_file" ]; then
            log_info "NodePool $nodepool_name 설정 복원 중..."
            # 중요한 설정만 선택적으로 복원
            local backup_expire_after=$(grep -A5 "expireAfter:" "$backup_file" | grep "expireAfter:" | awk '{print $2}' | tr -d '"')
            if [ ! -z "$backup_expire_after" ] && [ "$backup_expire_after" != "720h" ]; then
                kubectl patch nodepool $nodepool_name --type='merge' \
                    -p "{\"spec\":{\"template\":{\"spec\":{\"expireAfter\":\"$backup_expire_after\"}}}}" 2>/dev/null || true
            fi
        fi

        # drift 트리거를 위한 어노테이션 추가
        local ec2nodeclass=$(kubectl get nodepool $nodepool_name -o jsonpath='{.spec.template.spec.nodeClassRef.name}' 2>/dev/null)
        if [ ! -z "$ec2nodeclass" ]; then
            kubectl annotate ec2nodeclass.karpenter.k8s.aws $ec2nodeclass \
                karpenter.sh/drift-timestamp="$(date +%Y%m%d%H%M%S)" --overwrite
        fi
    done

    # 노드 교체 진행 모니터링
    log_info "노드 교체 진행 상황 모니터링 (최대 15분)"
    local max_wait=900
    local wait_time=0

    while [ $wait_time -lt $max_wait ]; do
        local old_nodes=$(kubectl get nodes -l karpenter.sh/nodepool -o json 2>/dev/null | \
            jq -r ".items[] | select(.status.nodeInfo.kubeletVersion | test(\"$TARGET_VERSION\") | not) | .metadata.name" 2>/dev/null | wc -l)

        if [ "$old_nodes" -eq 0 ]; then
            log_success "모든 Karpenter 노드가 $TARGET_VERSION으로 업데이트됨"
            break
        fi

        log_info "  대기 중... 남은 구버전 노드: $old_nodes"
        sleep 30
        wait_time=$((wait_time + 30))
    done

    if [ $wait_time -ge $max_wait ]; then
        log_warning "시간 초과: 일부 노드가 아직 업데이트되지 않았을 수 있음"
        log_info "수동으로 확인: kubectl get nodes -l karpenter.sh/nodepool"
    fi

    log_success "Karpenter 노드 교체 완료"
    echo
}

# 최종 상태 확인
check_final_status() {
    log_info "=== 최종 업그레이드 상태 확인 ==="

    # 클러스터 버전
    local cluster_version=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.version' --output text)
    log_info "클러스터 버전: $cluster_version"

    # 노드 버전 분포
    log_info "노드 버전 분포:"
    kubectl get nodes -o json | jq -r '.items[] | "\(.status.nodeInfo.kubeletVersion)"' | sort | uniq -c | while read count version; do
        log_info "  $version: $count개 노드"
    done

    # 애드온 상태
    echo
    log_info "애드온 최종 상태:"
    eksctl get addon --cluster $CLUSTER_NAME --region $REGION 2>/dev/null || log_warning "애드온 정보 조회 실패"

    echo
}

# 정리 작업
cleanup() {
    log_info "=== 정리 작업 ==="

    if [ -d "./karpenter-backup" ]; then
        log_info "Karpenter 백업 파일 정리"
        rm -rf ./karpenter-backup
    fi

    log_info "업그레이드 상태 파일 정리"
    rm -f .upgrade-state

    log_success "정리 작업 완료"
}

# 메인 실행
main() {
    echo
    log_warning "Step 3에서 수행할 작업:"
    log_warning "1. 노드 그룹 업그레이드 (있는 경우)"
    log_warning "2. Karpenter drift 활성화 및 노드 교체"
    log_warning "⚠️  이 작업은 파드 중단을 발생시킵니다."
    echo
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Step 3이 취소되었습니다."
        exit 0
    fi

    echo
    local start_time=$(date +%s)

    upgrade_nodegroups
    rotate_karpenter_nodes
    check_final_status
    cleanup

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo
    log_success "=== EKS 클러스터 업그레이드 완료 ==="
    log_success "클러스터 $CLUSTER_NAME이 Kubernetes $TARGET_VERSION으로 업그레이드되었습니다"
    log_info "총 소요 시간: ${minutes}분 ${seconds}초"
}

main