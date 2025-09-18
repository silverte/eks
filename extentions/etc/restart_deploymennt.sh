#!/bin/bash

# 초간단 Deployment 재시작 스크립트

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 옵션 처리
DRY_RUN=false
INCLUDE_SYSTEM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run) DRY_RUN=true; shift ;;
        -a|--all) INCLUDE_SYSTEM=true; shift ;;
        -h|--help) 
            echo "사용법: $0 [-d|--dry-run] [-a|--all] [-h|--help]"
            echo "  -d  미리보기만"
            echo "  -a  시스템 네임스페이스 포함"
            exit 0 ;;
        *) error "알 수 없는 옵션: $1"; exit 1 ;;
    esac
done

log "=== Deployment 재시작 ==="

# 시스템 네임스페이스 제외 조건
EXCLUDE_PATTERN=""
if [[ "$INCLUDE_SYSTEM" == false ]]; then
    EXCLUDE_PATTERN="kube-system|kube-public|kube-node-lease"
fi

# Deployment 목록 가져오기
if [[ -n "$EXCLUDE_PATTERN" ]]; then
    DEPLOYMENTS=$(kubectl get deployments --all-namespaces --no-headers | grep -v -E "^($EXCLUDE_PATTERN)")
else
    DEPLOYMENTS=$(kubectl get deployments --all-namespaces --no-headers)
fi

# 목록이 비어있는지 확인
if [[ -z "$DEPLOYMENTS" ]]; then
    log "재시작할 Deployment가 없습니다."
    exit 0
fi

# 카운트
TOTAL=$(echo "$DEPLOYMENTS" | wc -l)
log "발견된 Deployment: $TOTAL 개"

echo
echo "재시작할 목록:"
echo "$DEPLOYMENTS" | while read ns name rest; do echo "  $ns/$name"; done
echo

# DRY RUN
if [[ "$DRY_RUN" == true ]]; then
    log "DRY-RUN 모드 (실제 실행 안됨)"
    exit 0
fi

# 확인
read -p "계속 진행? (y/N): " -r
[[ ! $REPLY =~ ^[Yy]$ ]] && { log "취소됨"; exit 0; }

# 실행
log "재시작 시작..."
SUCCESS=0
FAILED=0

echo "$DEPLOYMENTS" | while read namespace name rest; do
    echo -n "  $namespace/$name ... "
    if kubectl rollout restart deployment/"$name" -n "$namespace" &>/dev/null; then
        echo "OK"
        ((SUCCESS++))
    else
        echo "FAILED"
        ((FAILED++))
    fi
done

success "완료! 전체 상태: kubectl get deployments --all-namespaces"
