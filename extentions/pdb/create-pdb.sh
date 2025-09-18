#!/bin/bash

# PDB 자동 생성 스크립트
# 용도: replica 2개 이상인 deployment들의 PDB 파일 생성

set -e

# 출력 디렉토리 설정
OUTPUT_DIR="./pdb-manifests"
mkdir -p "$OUTPUT_DIR"

echo "=== PDB 파일 생성 시작 ==="
echo "출력 디렉토리: $OUTPUT_DIR"
echo

# deployment 목록 가져오기 및 PDB 생성
kubectl get deployments -A | grep -E "esp-(fo|hcas|hims|hpas|if)-prd" | awk '$3 >= 2 {print $1 "/" $2}' | \
while IFS='/' read -r namespace deployment; do
    
    # deployment 이름에서 app 이름 추출 (패턴 분석)
    if [[ "$deployment" =~ ^(.*)-app-prd$ ]]; then
        app_name="${BASH_REMATCH[1]}"
    elif [[ "$deployment" =~ ^(.*)-api-app-prd$ ]]; then
        app_name=$(echo "${BASH_REMATCH[1]}" | sed 's/-api$//')
    elif [[ "$deployment" == "apache-server" ]]; then
        app_name="apache-server"
    else
        # 기본 패턴: deployment 이름에서 -app-prd, -api-app-prd 제거
        app_name=$(echo "$deployment" | sed -E 's/-(api-)?app-prd$//')
    fi
    
    # profile 이름 생성 (namespace별 맞춤 설정)
    if [[ "$namespace" == "esp-if-prd" ]]; then
        profile_name="esp-api.prd"  # esp-if-prd는 esp-api.prd 사용
    else
        profile_name=$(echo "$namespace" | sed 's/-prd$/.prd/')
    fi
    
    # PDB 파일 이름
    pdb_name="pdb-$deployment"
    filename="$OUTPUT_DIR/${namespace}-${deployment}-pdb.yaml"
    
    echo "생성 중: $namespace/$deployment -> $filename"
    
    # apache-server는 특별 처리 (app 레이블만 사용)
    if [[ "$deployment" == "apache-server" ]]; then
        cat > "$filename" << EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: $pdb_name
  namespace: $namespace
spec:
  maxUnavailable: 50%
  selector:
    matchLabels:
      app: apache-server
EOF
    else
        # 일반 deployment용 PDB 생성
        cat > "$filename" << EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: $pdb_name
  namespace: $namespace
spec:
  maxUnavailable: 50%
  selector:
    matchLabels:
      amdp.io/app: $app_name
      amdp.io/profile: $profile_name
EOF
    fi

done

echo
echo "=== 생성 완료 ==="
echo "총 $(ls -1 $OUTPUT_DIR/*.yaml | wc -l)개의 PDB 파일이 생성되었습니다."
echo
echo "생성된 파일들:"
ls -la "$OUTPUT_DIR"

echo
echo "=== 적용 방법 ==="
echo "모든 PDB 적용: kubectl apply -f $OUTPUT_DIR/"
echo "개별 파일 확인: cat $OUTPUT_DIR/esp-fo-prd-hezo-fo-customer-api-app-prd-pdb.yaml"
