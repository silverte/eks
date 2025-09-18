# helm(ec2-user)

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

# git(ec2-user)

```bash
sudo dnf install git-all
```

# docker(ec2-user)

```bash
sudo dnf install docker -y

sudo usermod -aG docker eks-admin

sudo systemctl start docker
sudo systemctl enable docker

su - apim
docker ps
```

# eks-node-viewer(ec2-user)

```bash
curl -LO https://go.dev/dl/go1.24.3.linux-arm64.tar.gz
sudo tar -C /usr/local -xzf go1.24.3.linux-arm64.tar.gz

echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bash_profile
source ~/.bash_profile

go install github.com/awslabs/eks-node-viewer/cmd/eks-node-viewer@latest
sudo mv ~/go/bin/eks-node-viewer /usr/local/bin/
```

# k9s(ec2-user)

```bash
curl -L -o k9s_linux_aarch64.rpm https://github.com/derailed/k9s/releases/download/v0.50.6/k9s_Linux_arm64.rpm

sudo dnf install -y ./k9s_linux_aarch64.rpm
```

# kubectl(eks-admin)

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.0/2024-12-20/bin/linux/arm64/kubectl

chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc

source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc 

# .bash_profile 추가
alias k=kubectl
alias nv='eks-node-viewer --resources cpu,memory'
complete -o default -F __start_kubectl k
export AWS_DEFAULT_REGION=ap-northeast-2
```

# kubectl krew(eks-admin)

```bash
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# .bashrc 추가 
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Essentail
kubectl krew install ctx ns view-secret tree df-pv neat

# RBAC
kubectl krew install access-matrix rbac-tool rbac-view rolesum whoami
```

# eksctl(eks-admin)

```bash

ARCH=arm64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

tar -xzf eksctl_$PLATFORM.tar.gz -C $HOME/bin && rm eksctl_$PLATFORM.tar.gz
```

# eks cluster 연결(eks-admin)

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name eks-esp-dev
```