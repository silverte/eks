# EKS 클러스터 관리 저장소

AWS EKS 클러스터의 설치, 확장, 업그레이드를 위한 통합 관리 도구 모음입니다.

## 🚀 Quick Start

```bash
# 1. Terraform으로 EKS 클러스터 생성
cd terraform
terraform init
terraform apply -var-file="terraform.tfvars"

# 2. 클러스터 연결
aws eks update-kubeconfig --region ap-northeast-2 --name eks-esp-prd

# 3. 핵심 컴포넌트 설치
cd ../extentions
./albc/albc.sh
./karpenter/karpenter.sh
```

## 📁 프로젝트 구조

```
├── terraform/                 # 인프라 구성 (VPC, EKS 클러스터)
├── upgrade/                   # EKS 버전 업그레이드 도구
├── extentions/                # Kubernetes 확장 컴포넌트
│   ├── albc/                  # AWS Load Balancer Controller
│   ├── karpenter/             # Karpenter (Node Auto-scaling)
│   ├── kyverno/               # 정책 엔진
│   ├── keda/                  # 이벤트 기반 오토스케일링
│   ├── pdb/                   # Pod Disruption Budget
│   ├── fluent-bit/            # 로그 수집
│   └── otel/                  # OpenTelemetry 관측성
└── eks-admin-server.md        # 관리 서버 설정 가이드
```

## 🏗️ 인프라 설치

### Terraform 기반 EKS 클러스터

```bash
cd terraform

# 백엔드 설정 (최초 1회)
./base.backend.sh

# 클러스터 배포
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

**주요 구성 요소:**
- VPC (Private/Public 서브넷)
- EKS 클러스터 (v1.33)
- 관리형 노드 그룹 (ARM64)
- 필수 애드온 (vpc-cni, coredns, kube-proxy)

## 🔧 필수 컴포넌트 설치

### 1. AWS Load Balancer Controller
```bash
cd extentions/albc
./albc.sh
```

### 2. Karpenter (Node Auto-scaling)
```bash
cd extentions/karpenter
./karpenter.sh

# NodePool 설정 적용
kubectl apply -f karpenter-nodepool-amd64.yaml
kubectl apply -f karpenter-nodepool-arm64.yaml
kubectl apply -f karpenter-ec2nodeclass-default.yaml
```

### 3. 정책 엔진 (Kyverno)
```bash
cd extentions/kyverno
./kyverno.sh
kubectl apply -f kyverno-policy.yaml
```

## 📈 모니터링 & 로깅

### Fluent Bit 로그 수집
```bash
cd extentions/fluent-bit
./fluent-bit-irsa.sh  # IAM 역할 생성
kubectl apply -f aws-for-fluent-bit-rbac.yaml
kubectl apply -f aws-for-fluent-bit-config.yaml
kubectl apply -f aws-for-fluent-bit-ds.yaml
```

### OpenTelemetry
```bash
cd extentions/otel
kubectl apply -f cm_otel.yaml
kubectl apply -f deploy_otel.yaml
kubectl apply -f svc_otel.yaml
```

## 🚀 애플리케이션 스케일링

### KEDA (이벤트 기반)
```bash
cd extentions/keda
./keda.sh

# HPA Behavior 설정 적용
./keda-advanced.sh
```

### Pod Disruption Budget 생성
```bash
cd extentions/pdb
./create-pdb.sh
kubectl apply -f pdb-manifests/
```

## 🔄 EKS 업그레이드

안전한 3단계 업그레이드 프로세스:

```bash
cd upgrade

# Step 1: 컨트롤 플레인 업그레이드
./eks-upgrade-step1.sh 1.33

# Step 2: 애드온 업그레이드  
./eks-upgrade-step2.sh

# Step 3: 노드 업그레이드
./eks-upgrade-step3.sh
```

**업그레이드 프로세스:**
1. **Step 1**: Karpenter AMI 고정 → drift 비활성화 → 컨트롤 플레인 업그레이드
2. **Step 2**: 네트워킹(kube-proxy, coredns, vpc-cni) → 보안 → 스토리지 애드온 순차 업그레이드
3. **Step 3**: 노드 그룹 → Karpenter 노드 교체 → 정리

> 💡 각 단계는 상태 파일(`.upgrade-state`)로 추적되며, 멱등성을 보장합니다.

## 🛠️ 운영 도구

### 관리 서버 설정
```bash
# kubectl, helm, eksctl 등 설치
# 상세 내용: eks-admin-server.md 참조
```

### 네임스페이스 생성
```bash
cd extentions/etc
./namespace.sh
```

### 백업 설정 (Velero)
```bash
cd extentions/etc
./velero.sh
```

## 📋 주요 설정 사항

### 보안 정책
- **Kyverno**: 컨테이너 리소스 제한, 허용된 이미지 레지스트리 제한
- **Pod Security Standards**: Restricted 정책 적용
- **Network Policies**: VPC CNI 기반 네트워크 분리

### 스토리지
- **EFS CSI Driver**: 공유 스토리지 (ConfigMap, PVC)
- **GP3 EBS**: 고성능 블록 스토리지 (기본)

### 네트워킹
- **AWS Load Balancer Controller**: ALB/NLB 통합 관리
- **VPC CNI**: Prefix Delegation 활성화 (IP 효율성)