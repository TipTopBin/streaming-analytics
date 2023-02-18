echo "==============================================="
echo "  Config envs ......"
echo "==============================================="
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
#export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
#export ACCOUNT_ID=`aws sts get-caller-identity --query Account --output text`

test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set

echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bashrc
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bashrc
aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws configure set region $AWS_REGION

source ~/.bashrc
aws sts get-caller-identity

# 辅助工具
echo "==============================================="
echo "  Install jq, envsubst (from GNU gettext utilities) and bash-completion ......"
echo "==============================================="
# moreutils: The command sponge allows us to read and write to the same file (cat a.txt|sponge a.txt)
sudo amazon-linux-extras install epel -y
sudo yum -y install bash-completion jq gettext moreutils


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
source ~/.bashrc


# 更新 awscli 并配置自动完成
echo "==============================================="
echo "  Upgrade awscli to v2 ......"
echo "==============================================="
sudo mv /bin/aws /bin/aws1
sudo mv ~/anaconda3/bin/aws ~/anaconda3/bin/aws1
ls -l /usr/local/bin/aws
rm -fr awscliv2.zip aws
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
AWS_COMPLETER=$(which aws_completer)
echo $SHELL
cat >> ~/.bashrc <<EOF
alias a=aws
complete -C '${AWS_COMPLETER}' aws
complete -C '${AWS_COMPLETER}' a
EOF
source ~/.bashrc
aws --version


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
# echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L beta.kubernetes.io/instance-type -L eks.amazonaws.com/nodegroup -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name -L karpenter.sh/capacity-type'" | tee -a ~/.bashrc
#echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L beta.kubernetes.io/instance-type -L eks.amazonaws.com/nodegroup -L topology.kubernetes.io/zone'" | tee -a ~/.bashrc
echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L node.kubernetes.io/instance-type -L eks.amazonaws.com/nodegroup -L topology.kubernetes.io/zone'" | tee -a ~/.bashrc
# echo "alias kgnk='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L node.kubernetes.io/instance-type -L eks.amazonaws.com/nodegroup -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name -L karpenter.sh/capacity-type'" | tee -a ~/.bashrc
echo "alias kk='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L karpenter.sh/capacity-type -L node.kubernetes.io/instance-type -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name'" | tee -a ~/.bashrc
echo "alias kgp='kubectl get po -o wide'" | tee -a ~/.bashrc
echo "alias kaf='kubectl apply -f'" | tee -a ~/.bashrc
source ~/.bashrc


echo "==============================================="
echo "  Install krew ......"
echo "==============================================="
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

cat >> ~/.bashrc <<EOF
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
EOF
source ~/.bashrc


# 安装 helm
echo "==============================================="
echo "  Install helm ......"
echo "==============================================="
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
helm repo add stable https://charts.helm.sh/stable



# 安装 awscurl 工具 https://github.com/okigan/awscurl
echo "==============================================="
echo "  Install awscurl ......"
echo "==============================================="
cat >> ~/.bashrc <<EOF
export PATH=\$PATH:\$HOME/.local/bin:\$HOME/bin:/usr/local/bin
EOF
source ~/.bashrc

sudo python3 -m pip install awscurl


# 安装 session-manager 插件
echo "==============================================="
echo "  Install session-manager ......"
echo "==============================================="
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"

sudo yum install -y session-manager-plugin.rpm

session-manager-plugin


# More tools
echo "==============================================="
echo "  Install yq for yaml processing ......"
echo "==============================================="
echo 'yq() {
  docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
}' | tee -a ~/.bashrc && source ~/.bashrc



echo "==============================================="
echo "  Install k9s a Kubernetes CLI To Manage Your Clusters In Style ......"
echo "==============================================="
curl -sS https://webinstall.dev/k9s | bash
# 参考 https://segmentfault.com/a/1190000039755239


echo "==============================================="
echo "  Install kubectx + kubens ......"
echo "==============================================="
kubectl krew install ctx
kubectl krew install ns


echo "==============================================="
echo "  Install kube-no-trouble (kubent) ......"
echo "==============================================="
# https://github.com/doitintl/kube-no-trouble
# https://medium.doit-intl.com/kubernetes-how-to-automatically-detect-and-deal-with-deprecated-apis-f9a8fc23444c
sh -c "$(curl -sSL https://git.io/install-kubent)"


echo "==============================================="
echo "  Install kubescape ......"
echo "==============================================="
curl -s https://raw.githubusercontent.com/armosec/kubescape/master/install.sh | /bin/bash


echo "==============================================="
echo "  Install ec2-instance-selector ......"
echo "==============================================="
curl -Lo ec2-instance-selector https://github.com/aws/amazon-ec2-instance-selector/releases/download/v2.3.3/ec2-instance-selector-`uname | tr '[:upper:]' '[:lower:]'`-amd64 && chmod +x ec2-instance-selector
chmod +x ./ec2-instance-selector
mkdir -p $HOME/bin && mv ./ec2-instance-selector $HOME/bin/ec2-instance-selector


echo "==============================================="
echo "  Install kind ......"
echo "==============================================="
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.14.0/kind-$(uname)-amd64"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/


echo "==============================================="
echo "  Install Flux CLI ......"
echo "==============================================="
curl -s https://fluxcd.io/install.sh | sudo bash
flux --version


echo "==============================================="
echo "  Install siege ......"
echo "==============================================="
sudo yum install siege -y
siege -V
#siege -q -t 15S -c 200 -i URL
#ab -c 500 -n 30000 http://$(kubectl get ing -n front-end --output=json | jq -r .items[].status.loadBalancer.ingress[].hostname)/


echo "==============================================="
echo "  Install terraform ......"
echo "==============================================="
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install terraform -y
terraform --version

echo "==============================================="
echo "  Install Go ......"
echo "==============================================="
sudo yum install golang -y
go version
export GOPATH=$(go env GOPATH)
echo 'export GOPATH='${GOPATH} >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc


echo "==============================================="
echo "  Install ccat ......"
echo "==============================================="
go install github.com/owenthereal/ccat@latest
cat >> ~/.bashrc <<EOF
alias cat=ccat
EOF
source ~/.bashrc

echo "==============================================="
echo "  Install telnet ......"
echo "==============================================="
sudo yum -y install telnet


echo "==============================================="
echo "  Cofing dfimage ......"
echo "==============================================="
cat >> ~/.bashrc <<EOF
alias dfimage="docker run -v /var/run/docker.sock:/var/run/docker.sock --rm alpine/dfimage"  
EOF
source ~/.bashrc
# dfimage -sV=1.36 nginx:latest 


echo "==============================================="
echo "  Install ParallelCluster ......"
echo "==============================================="
if ! command -v pcluster &> /dev/null
then
  echo ">> pcluster is missing, reinstalling it"
  sudo pip3 install 'aws-parallelcluster'
else
  echo ">> Pcluster $(pcluster version) found, nothing to install"
fi
pcluster version

echo "==============================================="
echo "  Install wildq ......"
echo "==============================================="
# wildq: Tool on-top of jq to manipulate INI files
sudo pip3 install wildq
# cat file.ini \
#   |wildq -i ini -M '.Key = "value"' \
#   |sponge file.ini


echo "==============================================="
echo "  Install copilot ......"
echo "==============================================="
sudo curl -Lo /usr/local/bin/copilot https://github.com/aws/copilot-cli/releases/latest/download/copilot-linux \
   && sudo chmod +x /usr/local/bin/copilot \
   && copilot --help


echo "==============================================="
echo "  Install App2Container ......"
echo "==============================================="
#https://aws.amazon.com/blogs/containers/modernize-java-and-net-applications-remotely-using-aws-app2container/
curl -o AWSApp2Container-installer-linux.tar.gz https://app2container-release-us-east-1.s3.us-east-1.amazonaws.com/latest/linux/AWSApp2Container-installer-linux.tar.gz
sudo tar xvf AWSApp2Container-installer-linux.tar.gz
# sudo ./install.sh
echo y |sudo ./install.sh
sudo app2container --version
cat >> ~/.bashrc <<EOF
alias a2c="sudo app2container"
EOF
source ~/.bashrc


echo "==============================================="
echo "  Install flink ......"
echo "==============================================="
wget https://dlcdn.apache.org/flink/flink-1.15.2/flink-1.15.2-bin-scala_2.12.tgz
sudo tar xzvf flink-*.tgz -C /opt
sudo chown -R ec2-user /opt/flink-1.15.2 
cat >> ~/.bashrc <<EOF
export PATH="/opt/flink-1.15.2/bin:$PATH"
EOF
source ~/.bashrc
flink -v


echo "==============================================="
echo "  Install sam cli ......"
echo "==============================================="
wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
sudo ./sam-installation/install
sam --version


echo "==============================================="
echo "  Set Aliases ......"
echo "==============================================="
echo "alias c='clear'" | tee -a ~/.bashrc
echo "alias b='/bin/bash'" | tee -a ~/.bashrc
echo "alias cds='cd /home/notebook/work'" | tee -a ~/.bashrc

source ~/.bashrc


echo "==============================================="
echo "  Install emr-on-eks-custom-image ......"
echo "==============================================="
wget https://github.com/awslabs/amazon-emr-on-eks-custom-image-cli/releases/download/v1.03/amazon-emr-on-eks-custom-image-cli-linux-v1.03.zip
mkdir -p ./emr-on-eks-custom-image
unzip amazon-emr-on-eks-custom-image-cli-linux-v1.03.zip -d ./emr-on-eks-custom-image
sudo ./emr-on-eks-custom-image/installation
emr-on-eks-custom-image --version


# 最后再执行一次 source
echo "source .bashrc"
shopt -s expand_aliases
source ~/.bashrc