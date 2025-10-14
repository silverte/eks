# EKS Terraform 모듈화 구조

## 📁 디렉토리 구조

```
terraform/
├── modules/
│   ├── vpc/          # VPC 모듈
│   └── eks/          # EKS 모듈
├── main.tf           # 루트 모듈
├── variables.tf      # 통합 변수
├── outputs.tf        # 통합 출력
├── vpc-only.tfvars   # VPC만 배포
├── eks-only.tfvars   # EKS만 배포
├── all.tfvars        # 전체 배포
└── deploy.sh         # 배포 스크립트
```

## 🚀 배포 방법

### 1. VPC만 배포
```bash
./deploy.sh vpc-only
# 또는
terraform apply -var-file="vpc-only.tfvars"
```

### 2. EKS만 배포 (기존 VPC 사용)
```bash
# eks-only.tfvars에서 existing_vpc_id 수정 후
./deploy.sh eks-only
# 또는
terraform apply -var-file="eks-only.tfvars"
```

### 3. 전체 배포 (VPC + EKS)
```bash
./deploy.sh all
# 또는
terraform apply -var-file="all.tfvars"
```

## 🔧 설정 파일

### VPC 전용 (vpc-only.tfvars)
- `create_vpc = true`
- `create_eks_cluster = false`

### EKS 전용 (eks-only.tfvars)
- `create_vpc = false`
- `create_eks_cluster = true`
- `existing_vpc_id` 설정 필요

### 전체 배포 (all.tfvars)
- `create_vpc = true`
- `create_eks_cluster = true`

## 💡 사용 시나리오

1. **단계별 배포**: VPC 먼저 → EKS 나중에
2. **기존 VPC 활용**: 기존 VPC에 EKS만 추가
3. **전체 신규 구축**: VPC와 EKS 동시 배포