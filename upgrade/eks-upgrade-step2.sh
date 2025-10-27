
    # 5. 스토리지 드라이버
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