#!/bin/bash
# Aether OnRamp Setup Script for AWS EC2 t3.large
# This script automates the installation and setup process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on supported OS
check_os() {
    print_info "Checking operating system..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            print_error "This script is designed for Ubuntu. Detected: $ID"
            exit 1
        fi
        print_info "Running on Ubuntu $VERSION_ID"
    else
        print_error "Cannot determine OS"
        exit 1
    fi
}

# Check if running on EC2
check_ec2() {
    print_info "Checking if running on AWS EC2..."
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-type > /dev/null 2>&1; then
        INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
        print_info "Running on EC2 instance type: $INSTANCE_TYPE"
        
        if [[ "$INSTANCE_TYPE" != "t3.large" ]] && [[ "$INSTANCE_TYPE" != "t3.xlarge" ]]; then
            print_warning "Recommended instance type is t3.large. Current: $INSTANCE_TYPE"
            print_warning "You may experience resource constraints."
        fi
    else
        print_warning "Not running on AWS EC2 or metadata service unavailable"
    fi
}

# Update system
update_system() {
    print_info "Updating system packages..."
    sudo apt-get update -qq
    sudo apt-get upgrade -y -qq
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_info "Docker already installed: $(docker --version)"
        return
    fi
    
    print_info "Installing Docker..."
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    
    print_info "Docker installed: $(docker --version)"
}

# Install kubectl
install_kubectl() {
    if command -v kubectl &> /dev/null; then
        print_info "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return
    fi
    
    print_info "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    print_info "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Install kind
install_kind() {
    if command -v kind &> /dev/null; then
        print_info "kind already installed: $(kind version)"
        return
    fi
    
    print_info "Installing kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    print_info "kind installed: $(kind version)"
}

# Install Helm
install_helm() {
    if command -v helm &> /dev/null; then
        print_info "Helm already installed: $(helm version --short)"
        return
    fi
    
    print_info "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    print_info "Helm installed: $(helm version --short)"
}

# Install additional tools
install_tools() {
    print_info "Installing additional tools..."
    sudo apt-get install -y git make jq wget
    
    # Install yq
    if ! command -v yq &> /dev/null; then
        print_info "Installing yq..."
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
    fi
}

# Configure system settings
configure_system() {
    print_info "Configuring system settings..."
    
    # Disable swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Load kernel modules
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    # Set sysctl parameters
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sudo sysctl --system > /dev/null 2>&1
    
    print_info "System configured successfully"
}

# Create Kubernetes cluster
create_cluster() {
    if kind get clusters 2>/dev/null | grep -q "aether-onramp"; then
        print_info "Kubernetes cluster 'aether-onramp' already exists"
        return
    fi
    
    print_info "Creating Kubernetes cluster with kind..."
    
    cat <<EOF > /tmp/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: aether-onramp
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 38412
    hostPort: 38412
    protocol: TCP
  - containerPort: 2152
    hostPort: 2152
    protocol: UDP
  - containerPort: 8000
    hostPort: 8000
    protocol: TCP
EOF
    
    kind create cluster --config /tmp/kind-config.yaml --wait 5m
    
    print_info "Kubernetes cluster created successfully"
}

# Setup Helm repositories
setup_helm_repos() {
    print_info "Setting up Helm repositories..."
    
    # Add common repositories (these may not exist, so we'll skip errors)
    helm repo add aether https://charts.aetherproject.org 2>/dev/null || print_warning "Could not add aether repo (may not be publicly available)"
    helm repo add stable https://charts.helm.sh/stable 2>/dev/null || true
    helm repo update
    
    print_info "Helm repositories configured"
}

# Install metrics server
install_metrics_server() {
    print_info "Installing metrics-server..."
    
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Patch for kind
    kubectl patch deployment metrics-server -n kube-system --type='json' \
      -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
    
    print_info "Metrics server installed"
}

# Print summary
print_summary() {
    echo ""
    echo "======================================"
    print_info "Aether OnRamp Setup Complete!"
    echo "======================================"
    echo ""
    echo "Installed components:"
    echo "  - Docker: $(docker --version | cut -d' ' -f3)"
    echo "  - kubectl: $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || kubectl version --client | grep 'Client Version' | cut -d':' -f2)"
    echo "  - kind: $(kind version | cut -d' ' -f2)"
    echo "  - Helm: $(helm version --short | cut -d':' -f2)"
    echo ""
    echo "Kubernetes cluster: aether-onramp"
    echo "  - kubectl get nodes"
    echo "  - kubectl get pods -A"
    echo ""
    echo "Next steps:"
    echo "  1. Review documentation: docs/installation.md"
    echo "  2. Deploy SD-Core: docs/sd-core-deployment.md"
    echo "  3. Connect RAN: docs/ran-connectivity.md"
    echo ""
    print_warning "Note: You may need to log out and back in for Docker group membership to take effect"
    echo "      Or run: newgrp docker"
    echo ""
}

# Main installation flow
main() {
    echo "======================================"
    echo "  Aether OnRamp Setup for AWS EC2"
    echo "======================================"
    echo ""
    
    check_os
    check_ec2
    
    print_info "Starting installation..."
    
    update_system
    install_docker
    install_kubectl
    install_kind
    install_helm
    install_tools
    configure_system
    
    # Create cluster (requires Docker)
    newgrp docker << END
        create_cluster
        setup_helm_repos
        install_metrics_server
END
    
    print_summary
}

# Run main function
main "$@"
