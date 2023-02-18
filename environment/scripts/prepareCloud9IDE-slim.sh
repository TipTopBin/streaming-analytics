#!/bin/bash

set -e

# kubectl_version='1.23.9'
# kubectl_checksum='053561f7c68c5a037a69c52234e3cf1f91798854527692acd67091d594b616ce'

# helm_version='3.10.1'
# helm_checksum='c12d2cd638f2d066fec123d0bd7f010f32c643afdf288d39a4610b1f9cb32af3'

# eksctl_version='0.115.0'
# eksctl_checksum='d1d6d6d56ae33f47242f769bea4b19587f1200e5bbef65f3a35d159ed2463716'

# kustomize_version='4.5.7'
# kustomize_checksum='701e3c4bfa14e4c520d481fdf7131f902531bfc002cb5062dcf31263a09c70c9'

kustomize_version='5.0.0'
kustomize_checksum='2e8c28a80ce213528251f489db8d2dcbea7c63b986c8f7595a39fc76ff871cd7'

# kubeseal_version='0.18.4'
# kubeseal_checksum='2e765b87889bfcf06a6249cde8e28507e3b7be29851e4fac651853f7638f12f3'

kubeseal_version='0.19.5'
kubeseal_checksum='9f8de35b8272533cc687c909ce717d4340aea23a16a3e422a92a6105f23b835b'

yq_version='4.30.6'
yq_checksum='2aabdd748d301fc2286ea9f73eb20477b4ce173fbf072e0102fff1fcbed05985'

# flux_version='0.38.3'
# flux_checksum='268b8d9a2fa5b0c9e462b551eaefdadb9e03370eb53061a88a2a9ac40e95e8e4'

download_and_verify () {
  url=$1
  checksum=$2
  out_file=$3

  curl --location --show-error --silent --output $out_file $url

  echo "$checksum $out_file" > "$out_file.sha256"
  sha256sum --check "$out_file.sha256"
  
  rm "$out_file.sha256"
}

yum install --quiet -y findutils jq tar gzip zsh git diffutils wget tree unzip openssl gettext bash-completion python3 pip3 python3-pip amazon-linux-extras

amazon-linux-extras install -y postgresql12

pip3 install awscurl

# # kubectl
# download_and_verify "https://dl.k8s.io/release/v$kubectl_version/bin/linux/amd64/kubectl" "$kubectl_checksum" "kubectl"
# chmod +x ./kubectl
# mv ./kubectl /usr/local/bin

# # helm
# download_and_verify "https://get.helm.sh/helm-v$helm_version-linux-amd64.tar.gz" "$helm_checksum" "helm.tar.gz"
# tar zxf helm.tar.gz
# chmod +x linux-amd64/helm
# mv ./linux-amd64/helm /usr/local/bin
# rm -rf linux-amd64/ helm.tar.gz

# # eksctl
# download_and_verify "https://github.com/weaveworks/eksctl/releases/download/v$eksctl_version/eksctl_Linux_amd64.tar.gz" "$eksctl_checksum" "eksctl_Linux_amd64.tar.gz"
# tar zxf eksctl_Linux_amd64.tar.gz
# chmod +x eksctl
# mv ./eksctl /usr/local/bin
# rm -rf eksctl_Linux_amd64.tar.gz

# kustomize
download_and_verify "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${kustomize_version}/kustomize_v${kustomize_version}_linux_amd64.tar.gz" "$kustomize_checksum" "kustomize.tar.gz"
tar zxf kustomize.tar.gz
chmod +x kustomize
mv ./kustomize /usr/local/bin
rm -rf kustomize.tar.gz

# aws cli v2
curl --location --show-error --silent "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o -q awscliv2.zip
./aws/install --update
rm -rf ./aws awscliv2.zip

# kubeseal
download_and_verify "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${kubeseal_version}/kubeseal-${kubeseal_version}-linux-amd64.tar.gz" "$kubeseal_checksum" "kubeseal.tar.gz"
tar xfz kubeseal.tar.gz
chmod +x kubeseal
mv ./kubeseal /usr/local/bin
rm -rf kubeseal.tar.gz

# yq
download_and_verify "https://github.com/mikefarah/yq/releases/download/v${yq_version}/yq_linux_amd64" "$yq_checksum" "yq"
chmod +x ./yq
mv ./yq /usr/local/bin

# # flux
# download_and_verify "https://github.com/fluxcd/flux2/releases/download/v${flux_version}/flux_${flux_version}_linux_amd64.tar.gz" "$flux_checksum" "flux.tar.gz"
# tar zxf flux.tar.gz
# chmod +x flux
# mv ./flux /usr/local/bin
# rm -rf flux.tar.gz


cd /tmp/

echo "==============================================="
echo "  Install eksctl ......"
echo "==============================================="
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
# 配置自动完成
cat >> ~/.bashrc <<EOF
. <(eksctl completion bash)
alias e=eksctl
complete -F __start_eksctl e
EOF


echo "==============================================="
echo "  Install kubectl ......"
echo "==============================================="
# 安装 kubectl 并配置自动完成
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
cat >> ~/.bashrc <<EOF
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF
source ~/.bashrc
kubectl version --client
# Enable some kubernetes aliases
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all
sudo curl https://raw.githubusercontent.com/blendle/kns/master/bin/kns -o /usr/local/bin/kns && sudo chmod +x $_
sudo curl https://raw.githubusercontent.com/blendle/kns/master/bin/ktx -o /usr/local/bin/ktx && sudo chmod +x $_
echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L node.kubernetes.io/instance-type -L eks.amazonaws.com/nodegroup -L topology.kubernetes.io/zone'" | tee -a ~/.bashrc
echo "alias kk='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L karpenter.sh/capacity-type -L node.kubernetes.io/instance-type -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name'" | tee -a ~/.bashrc
echo "alias kgp='kubectl get po -o wide'" | tee -a ~/.bashrc


echo "==============================================="
echo "  Install helm ......"
echo "==============================================="
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
helm repo add stable https://charts.helm.sh/stable


echo "==============================================="
echo "  Install Flux CLI ......"
echo "==============================================="
curl -s https://fluxcd.io/install.sh | sudo bash
flux --version


echo "==============================================="
echo "  Install Maven ......"
echo "==============================================="
wget https://archive.apache.org/dist/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz
sudo tar xzvf apache-maven-3.8.6-bin.tar.gz -C /opt
cat >> ~/.bashrc <<EOF
export PATH="/opt/apache-maven-3.8.6/bin:$PATH"
EOF
source ~/.bashrc
mvn --version


echo "==============================================="
echo "  Install flink ......"
echo "==============================================="
wget https://archive.apache.org/dist/flink/flink-1.15.3/flink-1.15.3-bin-scala_2.12.tgz
sudo tar xzvf flink-*.tgz -C /opt
sudo chown -R ec2-user /opt/flink-1.15.3
cat >> ~/.bashrc <<EOF
export PATH="/opt/flink-1.15.3/bin:$PATH"
EOF
source ~/.bashrc
flink -v


echo "==============================================="
echo "  More Aliases ......"
echo "==============================================="
cat >> ~/.bashrc <<EOF
alias c=clear
EOF
source ~/.bashrc

echo "==============================================="
echo "  Install c9 to open files in cloud9 ......"
echo "==============================================="
npm install -g c9

# 最后再执行一次 source
echo "source .bashrc"
shopt -s expand_aliases
source ~/.bashrc
