#!/bin/bash
# =============================================================================
# Kubernetes Components Deployment for EKS
# =============================================================================
# 주요 컴포넌트:
# - AWS Load Balancer Controller (ALBC)
#   https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/
# - Karpenter (Node Auto-scaling)
#   https://kyverno.io/docs/installation/methods/
# - Kyverno (Policy Engine)
#   https://karpenter.sh/docs/upgrading/compatibility/
# =============================================================================

set -e

# 환경 변수 설정
CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}' | awk -F'/' '{print $2}')
ENVIRONMENT=$(echo $CLUSTER_NAME | awk -F'-' '{print $3}')
REGION="ap-northeast-2"
NODEGROUP=$(aws eks list-nodegroups --cluster-name your-cluster-name --query 'nodegroups[0]' --output text)
ACCOUNT_NUM=$(aws sts get-caller-identity --query Account --output text)

# 네임스페이스 설정
ALBC_NAMESPACE="kube-system"
KARPENTER_NAMESPACE="kube-system"
KYVERNO_NAMESPACE="kyverno"

# 컴포넌트 버전 (Helm Chart 버전)
ALBC_VERSION="1.13.2"
KARPENTER_VERSION="1.5.0"
KYVERNO_VERSION="3.4.1"

# 앱 버전 변수 초기화
ALBC_APP_VERSION=""
KARPENTER_APP_VERSION=""
KYVERNO_APP_VERSION=""

# 색상 코드
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 사용법
show_usage() {
    cat << EOF
Usage: $0

Components:
  - AWS Load Balancer Controller $ALBC_VERSION
  - Kyverno $KYVERNO_VERSION
  - Karpenter $KARPENTER_VERSION  

Prerequisites:
  - kubectl, helm, aws-cli, jq 설치
  - EKS 클러스터 연결 확인
  - 적절한 IAM 권한

EOF
    exit 1
}

# 인수 확인
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
fi

# 사전 요구사항 검증
validate_prerequisites() {
    log_info "=== 사전 요구사항 검증 ==="
    
    # kubectl 연결 확인
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Kubernetes 클러스터에 연결할 수 없습니다"
        exit 1
    fi
    
    # AWS CLI 확인
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS CLI가 구성되지 않았거나 권한이 없습니다"
        exit 1
    fi
    
    # Helm 확인
    if ! command -v helm >/dev/null 2>&1; then
        log_error "Helm이 설치되지 않았거나 PATH에 없습니다"
        exit 1
    fi
    
    # jq 확인
    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq가 설치되지 않음 - 일부 버전 감지가 작동하지 않을 수 있습니다"
    fi
    
    log_success "사전 요구사항 검증 완료"
    echo
}

# Helm 레포지토리 추가
add_helm_repositories() {
    log_info "=== Helm 레포지토리 설정 ==="
    
    # EKS 레포지토리 추가
    if ! helm repo list 2>/dev/null | grep -q "eks.*https://aws.github.io/eks-charts"; then
        helm repo add eks https://aws.github.io/eks-charts
        log_info "EKS Helm 레포지토리 추가됨"
    fi
    
    # Kyverno 레포지토리 추가
    if ! helm repo list 2>/dev/null | grep -q "kyverno.*https://kyverno.github.io/kyverno"; then
        helm repo add kyverno https://kyverno.github.io/kyverno/
        log_info "Kyverno Helm 레포지토리 추가됨"
    fi
    
    helm repo update >/dev/null 2>&1
    log_success "Helm 레포지토리 업데이트 완료"
    echo
}

# 앱 버전 조회
get_app_versions() {
    log_info "=== 컴포넌트 버전 정보 수집 ==="
    
    # ALBC 앱 버전 조회 (helm search 우선)
    ALBC_APP_VERSION=$(helm search repo eks/aws-load-balancer-controller --version "$ALBC_VERSION" --output json 2>/dev/null | jq -r '.[0].app_version' 2>/dev/null || echo "")
    
    # helm search 실패 시 helm show chart로 대체
    if [ -z "$ALBC_APP_VERSION" ] || [ "$ALBC_APP_VERSION" == "null" ]; then
        ALBC_APP_VERSION=$(helm show chart eks/aws-load-balancer-controller --version "$ALBC_VERSION" 2>/dev/null | grep "appVersion:" | sed 's/appVersion: *//g' | tr -d '"' | tr -d ' ' || echo "Unknown")
    fi
    
    # Karpenter 앱 버전 (헬름 버전과 동일하게 설정)
    KARPENTER_APP_VERSION="v${KARPENTER_VERSION}"
    
    # Kyverno 앱 버전 조회 (helm search 우선)
    KYVERNO_APP_VERSION=$(helm search repo kyverno/kyverno --version "$KYVERNO_VERSION" --output json 2>/dev/null | jq -r '.[0].app_version' 2>/dev/null || echo "")
    
    # helm search 실패 시 helm show chart로 대체
    if [ -z "$KYVERNO_APP_VERSION" ] || [ "$KYVERNO_APP_VERSION" == "null" ]; then
        KYVERNO_APP_VERSION=$(helm show chart kyverno/kyverno --version "$KYVERNO_VERSION" 2>/dev/null | grep "appVersion:" | sed 's/appVersion: *//g' | tr -d '"' | tr -d ' ' || echo "Unknown")
    fi
    
    # 최종 검증 - 빈 값이면 "Unknown"으로 설정
    [ -z "$ALBC_APP_VERSION" ] && ALBC_APP_VERSION="Unknown"
    [ -z "$KARPENTER_APP_VERSION" ] && KARPENTER_APP_VERSION="Unknown" 
    [ -z "$KYVERNO_APP_VERSION" ] && KYVERNO_APP_VERSION="Unknown"
    
    log_success "버전 정보 수집 완료"
    echo
}

# VPC ID 조회 (에러 처리 포함)
get_vpc_id() {
    local vpc_id
    vpc_id=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
    
    if [ "$vpc_id" == "None" ] || [ -z "$vpc_id" ]; then
        log_error "클러스터 VPC ID 조회 실패: $CLUSTER_NAME"
        exit 1
    fi
    
    echo "$vpc_id"
}

# AWS Load Balancer Controller 배포
deploy_albc() {
    log_info "=== AWS Load Balancer Controller 배포 ==="
    
    # VPC ID 조회
    VPC_ID=$(get_vpc_id)
    log_info "VPC ID: $VPC_ID"

    # IAM 정책 다운로드 및 교체 (앱 버전 사용)
    POLICY_VERSION="$ALBC_APP_VERSION"
    if [ "$POLICY_VERSION" == "Unknown" ] || [ -z "$POLICY_VERSION" ]; then
        POLICY_VERSION="$ALBC_VERSION"
        log_warning "앱 버전을 알 수 없어 차트 버전을 IAM 정책 다운로드에 사용"
    fi
    
    if ! curl -sf -o iam-policy.json "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${POLICY_VERSION}/docs/install/iam_policy.json"; then
        log_warning "버전 ${POLICY_VERSION}로 IAM 정책 다운로드 실패, 차트 버전 ${ALBC_VERSION}로 재시도"
        curl -sf -o iam-policy.json "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${ALBC_VERSION}/docs/install/iam_policy.json"
    fi
    
    # 정책 존재 확인 및 업데이트 또는 생성
    if aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_NUM}:policy/AWSLoadBalancerControllerIAMPolicy" >/dev/null 2>&1; then
        aws iam create-policy-version \
            --policy-arn "arn:aws:iam::${ACCOUNT_NUM}:policy/AWSLoadBalancerControllerIAMPolicy" \
            --policy-document file://iam-policy.json \
            --set-as-default >/dev/null 2>&1 && log_success "IAM 정책 업데이트 완료"
    else
        log_warning "IAM 정책이 존재하지 않습니다. 먼저 생성하거나 정책 ARN을 확인하세요."
    fi
    
    # 정책 파일 정리
    rm -f iam-policy.json
    
    # CRD 업데이트
    kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master" >/dev/null 2>&1 && log_success "CRD 업데이트 완료"
    
    # 차트 배포/업그레이드
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace "$ALBC_NAMESPACE" \
        --version "$ALBC_VERSION" \
        --set clusterName="$CLUSTER_NAME" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set tolerations[0].key=CriticalAddonsOnly \
        --set tolerations[0].operator=Exists \
        --set tolerations[0].effect=NoSchedule \
        --set region="$REGION" \
        --set vpcId="$VPC_ID" \
        --wait --timeout=300s >/dev/null 2>&1 && log_success "Helm 차트 배포 완료"
    
    log_success "AWS Load Balancer Controller 배포 완료"
    echo
}

# Kyverno 배포
deploy_kyverno() {
    log_info "=== Kyverno 배포 ==="
    
    # 차트 배포/업그레이드
    helm upgrade --install kyverno kyverno/kyverno \
        --namespace "$KYVERNO_NAMESPACE" \
        --version "$KYVERNO_VERSION" \
        --set admissionController.tolerations[0].key="CriticalAddonsOnly" \
        --set admissionController.tolerations[0].operator="Exists" \
        --set admissionController.tolerations[0].effect="NoSchedule" \
        --set admissionController.replicas=3 \
        --set backgroundController.tolerations[0].key="CriticalAddonsOnly" \
        --set backgroundController.tolerations[0].operator="Exists" \
        --set backgroundController.tolerations[0].effect="NoSchedule" \
        --set backgroundController.replicas=2 \
        --set cleanupController.tolerations[0].key="CriticalAddonsOnly" \
        --set cleanupController.tolerations[0].operator="Exists" \
        --set cleanupController.tolerations[0].effect="NoSchedule" \
        --set cleanupController.replicas=2 \
        --set reportsController.tolerations[0].key="CriticalAddonsOnly" \
        --set reportsController.tolerations[0].operator="Exists" \
        --set reportsController.tolerations[0].effect="NoSchedule" \
        --set reportsController.replicas=2 \
	--set reportsController.resources.requests.cpu=200m \
	--set reportsController.resources.requests.memory=256Mi \
        --set reportsController.resources.limits.memory=512Mi \
        --wait --timeout=600s >/dev/null 2>&1 && log_success "Helm 차트 배포 완료"
    
    log_success "Kyverno 배포 완료"
    echo
}

# Karpenter 배포
deploy_karpenter() {
    log_info "=== Karpenter 배포 ==="
    
    # CRD에 Helm 관리 라벨 및 어노테이션 추가
    kubectl label crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh nodeclaims.karpenter.sh \
        app.kubernetes.io/managed-by=Helm --overwrite >/dev/null 2>&1 || true
    
    kubectl annotate crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh nodeclaims.karpenter.sh \
        meta.helm.sh/release-name=karpenter-crd --overwrite >/dev/null 2>&1 || true
    kubectl annotate crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh nodeclaims.karpenter.sh \
        meta.helm.sh/release-namespace="$KARPENTER_NAMESPACE" --overwrite >/dev/null 2>&1 || true
    
    # Karpenter CRD 배포
    helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
        --version "$KARPENTER_VERSION" \
        --namespace "$KARPENTER_NAMESPACE" \
        --wait --timeout=300s >/dev/null 2>&1 && log_success "CRD 배포 완료"
    
    # Karpenter 컨트롤러 배포
    helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
        --version "$KARPENTER_VERSION" \
        --namespace "$KARPENTER_NAMESPACE" \
        --set settings.clusterName="$CLUSTER_NAME" \
        --set settings.interruptionQueue="$CLUSTER_NAME" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=karpenter \
        --set tolerations[0].key=CriticalAddonsOnly \
        --set tolerations[0].operator=Exists \
        --set tolerations[0].effect=NoSchedule \
        --wait --timeout=600s >/dev/null 2>&1 && log_success "컨트롤러 배포 완료"
    
    log_success "Karpenter 배포 완료"
    echo
}

# 최종 상태 확인
check_final_status() {
    log_info "=== 배포 상태 확인 ==="
    
    # AWS Load Balancer Controller 상태
    local albc_pods=$(kubectl get pods -n $ALBC_NAMESPACE -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | wc -l)
    log_info "AWS Load Balancer Controller: $albc_pods개 파드"
    
    # Kyverno 상태
    local kyverno_pods=$(kubectl get pods -n $KYVERNO_NAMESPACE --no-headers 2>/dev/null | wc -l)
    log_info "Kyverno: $kyverno_pods개 파드"
    
    # Karpenter 상태
    local karpenter_pods=$(kubectl get pods -n $KARPENTER_NAMESPACE -l app.kubernetes.io/name=karpenter --no-headers 2>/dev/null | wc -l)
    log_info "Karpenter: $karpenter_pods개 파드"
    
    echo
    log_info "상세 상태 확인 명령어:"
    log_info "  kubectl get pods -n $ALBC_NAMESPACE -l app.kubernetes.io/name=aws-load-balancer-controller"
    log_info "  kubectl get pods -n $KYVERNO_NAMESPACE"
    log_info "  kubectl get pods -n $KARPENTER_NAMESPACE -l app.kubernetes.io/name=karpenter"
    echo
}

# 메인 배포 함수
deploy_components() {
    log_info "=== Kubernetes 컴포넌트 배포 시작 ==="
    
    # Helm 레포지토리 추가
    add_helm_repositories
    
    # 앱 버전 조회
    get_app_versions
    
    # 배포 설정 표시
    echo "=============================================="
    echo "배포 설정:"
    echo "클러스터: $CLUSTER_NAME"
    echo "환경: $ENVIRONMENT"
    echo "리전: $REGION"
    echo "AWS Load Balancer Controller: $ALBC_VERSION ($ALBC_APP_VERSION)"
    echo "Karpenter: $KARPENTER_VERSION ($KARPENTER_APP_VERSION)"
    echo "Kyverno: $KYVERNO_VERSION ($KYVERNO_APP_VERSION)"
    echo "=============================================="
    echo
    
    # 확인 요청
    read -p "배포를 진행하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "배포가 사용자에 의해 취소되었습니다"
        exit 0
    fi
    
    # 컴포넌트 배포
    deploy_albc
    deploy_kyverno
    deploy_karpenter
    check_final_status
    
    log_success "=== 모든 컴포넌트 배포 완료 ==="
}

# 메인 실행
main() {
    echo
    log_info "========================================="
    log_info "Kubernetes 컴포넌트 배포 스크립트"
    log_info "========================================="
    echo
    
    validate_prerequisites
    deploy_components
    
    echo
    log_success "배포가 성공적으로 완료되었습니다!"
    echo
}

# 스크립트 실행
main "$@"
