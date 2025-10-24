# Kubernetes Setup

This guide covers setting up a Kubernetes cluster on AWS EC2 t3.large using kind (Kubernetes in Docker).

## Prerequisites

- Completed [Installation Guide](installation.md)
- Docker running
- kubectl, kind, and Helm installed

## Option 1: Single-Node Cluster with kind

### Step 1: Create kind Configuration

Create a configuration file for kind:

```bash
cat <<EOF > /tmp/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: aether-onramp
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
  disableDefaultCNI: false
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
```

### Step 2: Create Kubernetes Cluster

```bash
kind create cluster --config /tmp/kind-config.yaml
```

### Step 3: Verify Cluster

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -A
```

## Option 2: Multi-Node Cluster with kind

For a more production-like setup:

```bash
cat <<EOF > /tmp/kind-multi-config.yaml
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
- role: worker
- role: worker
EOF

kind create cluster --config /tmp/kind-multi-config.yaml
```

## Option 3: kubeadm on EC2 (Production)

For production deployments, use kubeadm:

### Step 1: Initialize Kubernetes

```bash
# Initialize the cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Set up kubectl for regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Step 2: Install CNI Plugin (Calico)

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

### Step 3: Remove Taint (Single Node)

For single-node clusters, remove the control-plane taint:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-
```

### Add an EC2 Worker Node (kubeadm)

To add an additional EC2 instance as a worker node to your existing kubeadm cluster:

**On the control-plane node:**

1. Generate a join command with a fresh token (valid for 24 hours):

```bash
sudo kubeadm token create --print-join-command
```

This outputs something like:

```
kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

**On the new worker node EC2 instance:**

2. Complete the [Installation Guide](installation.md) prerequisites (Docker, kubeadm, kubelet, kubectl).

3. Run the join command from step 1 as root:

```bash
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

**Verify from the control-plane:**

4. Check that the new worker node appears:

```bash
kubectl get nodes
```

The new node should show `Ready` status after a minute or two (once the CNI plugin configures networking).

## Post-Installation Setup

### Install MetalLB (Load Balancer)

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

Configure MetalLB IP address pool:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.18.255.200-172.18.255.250
EOF
```

### Install Multus CNI (Optional)

For multi-interface support required by 5G:

```bash
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
```

### Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Install cert-manager (Optional)

For certificate management:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

## Configure Storage

### Local Path Provisioner (Default with kind)

Kind includes local-path-provisioner by default. Verify:

```bash
kubectl get storageclass
```

### Configure Persistent Volumes (Optional)

For production, configure persistent storage:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - aether-onramp-control-plane
EOF
```

## Namespace Setup

Create namespaces for SD-Core components:

```bash
# Create omec namespace for SD-Core
kubectl create namespace omec

# Create monitoring namespace (optional)
kubectl create namespace monitoring

# Create logging namespace (optional)
kubectl create namespace logging
```

## Verify Installation

```bash
# Check all namespaces
kubectl get namespaces

# Check all pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Check storage classes
kubectl get sc

# Check nodes
kubectl get nodes -o wide
```

## Configure kubectl Context

```bash
# Set default namespace
kubectl config set-context --current --namespace=omec

# View current context
kubectl config current-context

# View all contexts
kubectl config get-contexts
```

## Enable Kubernetes Dashboard (Optional)

```bash
# Deploy Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Get access token
kubectl -n kubernetes-dashboard create token admin-user

# Start proxy
kubectl proxy
```

Access dashboard at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

## Resource Monitoring

### Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For kind, patch metrics-server to allow insecure TLS
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Verify metrics
kubectl top nodes
kubectl top pods -A
```

## Troubleshooting

### Cluster Not Starting

```bash
# Check Docker
docker ps

# Check kind logs
kind export logs /tmp/kind-logs

# Delete and recreate cluster
kind delete cluster --name aether-onramp
kind create cluster --config /tmp/kind-config.yaml
```

### Pods Not Starting

```bash
# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -A --sort-by='.lastTimestamp'
```

### Network Issues

```bash
# Check CNI
kubectl get pods -n kube-system | grep -E 'calico|kindnet'

# Check DNS
kubectl run -it --rm --restart=Never busybox --image=busybox -- nslookup kubernetes.default
```

### Storage Issues

```bash
# Check PVs and PVCs
kubectl get pv
kubectl get pvc -A

# Check storage provisioner
kubectl get pods -n local-path-storage
```

## Clean Up

To remove the cluster:

```bash
# Delete kind cluster
kind delete cluster --name aether-onramp

# Or for kubeadm
sudo kubeadm reset
```

## Next Steps

After setting up Kubernetes, proceed to:
- [SD-Core Deployment](sd-core-deployment.md)
- [RAN Connectivity](ran-connectivity.md)
