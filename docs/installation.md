# Installation Guide

This guide covers the installation of prerequisites for Aether OnRamp on AWS EC2 t3.large instances.

## System Requirements

- AWS EC2 t3.large instance (2 vCPUs, 8 GiB RAM)
- Ubuntu 20.04 LTS or 22.04 LTS
- At least 50 GB of disk space
- Root or sudo access

## Step 1: Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

## Step 2: Install Docker

```bash
# Install prerequisites
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker
```

## Step 3: Install Kubernetes Tools

### Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Install kind (Kubernetes in Docker)

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Step 4: Install Additional Tools

### Install Git

```bash
sudo apt-get install -y git
```

### Install Make

```bash
sudo apt-get install -y make
```

### Install jq (JSON processor)

```bash
sudo apt-get install -y jq
```

### Install yq (YAML processor)

```bash
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

## Step 5: Configure System Settings

### Disable Swap

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### Load Kernel Modules

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### Set Sysctl Parameters

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

## Step 6: Configure AWS Security Groups

Ensure your EC2 security group allows the following ports:

### Kubernetes Ports
- TCP 6443: Kubernetes API server
- TCP 2379-2380: etcd server client API
- TCP 10250: Kubelet API
- TCP 10251: kube-scheduler
- TCP 10252: kube-controller-manager

### SD-Core Ports
- TCP 38412: NGAP (N2 interface)
- UDP 2152: GTP-U (N3 interface)
- TCP 29518: AMF service
- TCP 8000: SD-Core web UI

### Additional Ports
- TCP 22: SSH access
- TCP 80: HTTP (optional)
- TCP 443: HTTPS (optional)

Example security group configuration:

```bash
# Create security group
aws ec2 create-security-group \
  --group-name aether-onramp-sg \
  --description "Security group for Aether OnRamp"

# Add rules
aws ec2 authorize-security-group-ingress \
  --group-name aether-onramp-sg \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-name aether-onramp-sg \
  --protocol tcp \
  --port 6443 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-name aether-onramp-sg \
  --protocol tcp \
  --port 38412 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-name aether-onramp-sg \
  --protocol udp \
  --port 2152 \
  --cidr 0.0.0.0/0
```

## Step 7: Verify Installation

```bash
# Check Docker version
docker --version

# Check kubectl version
kubectl version --client

# Check kind version
kind version

# Check Helm version
helm version

# Check system configuration
sudo sysctl net.bridge.bridge-nf-call-iptables
sudo sysctl net.ipv4.ip_forward
```

## Step 8: Reboot (Optional but Recommended)

```bash
sudo reboot
```

After reboot, verify all services are running:

```bash
sudo systemctl status docker
```

## Troubleshooting

### Docker Permission Issues

If you encounter permission issues with Docker:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Kernel Module Issues

If kernel modules fail to load:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
lsmod | grep br_netfilter
```

### Network Issues

If you experience network connectivity issues:

```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward

# Reset iptables if needed
sudo iptables -F
sudo iptables -X
```

## Next Steps

After completing the installation, proceed to:
- [Kubernetes Setup](kubernetes-setup.md)
- [SD-Core Deployment](sd-core-deployment.md)
