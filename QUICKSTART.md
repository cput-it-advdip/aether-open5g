# Quick Start Guide

Get Aether OnRamp running on AWS EC2 t3.large in minutes.

## Prerequisites

- AWS account with EC2 access
- SSH key pair configured in AWS
- AWS CLI installed and configured locally

## Step 1: Launch EC2 Instance (5 minutes)

```bash
# Launch t3.large instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.large \
  --key-name YOUR-KEY-NAME \
  --security-group-ids YOUR-SECURITY-GROUP \
  --subnet-id YOUR-SUBNET-ID \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=aether-onramp}]'

# Get instance IP
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aether-onramp" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

## Step 2: Configure Security Group

```bash
# Allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id YOUR-SECURITY-GROUP \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Allow Kubernetes API
aws ec2 authorize-security-group-ingress \
  --group-id YOUR-SECURITY-GROUP \
  --protocol tcp \
  --port 6443 \
  --cidr 0.0.0.0/0

# Allow NGAP (N2)
aws ec2 authorize-security-group-ingress \
  --group-id YOUR-SECURITY-GROUP \
  --protocol tcp \
  --port 38412 \
  --cidr 0.0.0.0/0

# Allow GTP-U (N3)
aws ec2 authorize-security-group-ingress \
  --group-id YOUR-SECURITY-GROUP \
  --protocol udp \
  --port 2152 \
  --cidr 0.0.0.0/0
```

## Step 3: Connect and Setup (10 minutes)

```bash
# SSH to instance
ssh -i YOUR-KEY.pem ubuntu@INSTANCE-IP

# Clone repository
git clone https://github.com/cput-it-advdip/aether-open5g.git
cd aether-open5g

# Run automated setup
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The setup script will:
- ✓ Update system packages
- ✓ Install Docker
- ✓ Install kubectl, kind, and Helm
- ✓ Configure system settings
- ✓ Create Kubernetes cluster
- ✓ Install metrics-server

## Step 4: Deploy SD-Core (5 minutes)

```bash
# Create namespace
kubectl create namespace omec

# Add Helm repositories (if available)
helm repo add aether https://charts.aetherproject.org || echo "Using local config"
helm repo update

# Deploy SD-Core using example configuration
# Note: Update with actual Helm chart when available
kubectl apply -f examples/basic-5g.yaml
```

## Step 5: Deploy Emulated RAN (3 minutes)

```bash
# Deploy UERANSIM gNB
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gnb-config
  namespace: omec
data:
  gnb.yaml: |
    mcc: '208'
    mnc: '93'
    nci: '0x000000010'
    idLength: 32
    tac: 1
    linkIp: 0.0.0.0
    ngapIp: 0.0.0.0
    gtpIp: 0.0.0.0
    amfConfigs:
      - address: amf.omec.svc.cluster.local
        port: 38412
    slices:
      - sst: 1
        sd: 0x010203
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ueransim-gnb
  namespace: omec
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ueransim-gnb
  template:
    metadata:
      labels:
        app: ueransim-gnb
    spec:
      containers:
      - name: gnb
        image: free5gc/ueransim:latest
        command: ["/ueransim/build/nr-gnb", "-c", "/etc/ueransim/gnb.yaml"]
        volumeMounts:
        - name: config
          mountPath: /etc/ueransim
        securityContext:
          privileged: true
      volumes:
      - name: config
        configMap:
          name: gnb-config
EOF

# Wait for gNB to be ready
kubectl wait --for=condition=ready pod -l app=ueransim-gnb -n omec --timeout=120s
```

## Step 6: Verify Installation (2 minutes)

```bash
# Check all pods are running
kubectl get pods -n omec

# Check services
kubectl get svc -n omec

# View logs
kubectl logs -n omec -l app=amf --tail=20
kubectl logs -n omec -l app=ueransim-gnb --tail=20

# Check cluster resources
kubectl top nodes
kubectl top pods -n omec
```

## Common Commands

### View Status
```bash
# Cluster info
kubectl cluster-info

# All resources
kubectl get all -n omec

# Pod logs
kubectl logs -f -n omec <pod-name>

# Describe pod
kubectl describe pod -n omec <pod-name>
```

### Restart Components
```bash
# Restart deployment
kubectl rollout restart deployment <name> -n omec

# Delete pod (will be recreated)
kubectl delete pod <pod-name> -n omec
```

### Clean Up
```bash
# Delete namespace (removes all resources)
kubectl delete namespace omec

# Delete cluster
kind delete cluster --name aether-onramp

# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids <instance-id>
```

## Troubleshooting

### Pods not starting?
```bash
kubectl describe pod <pod-name> -n omec
kubectl logs <pod-name> -n omec
```

### gNB not connecting?
```bash
# Check AMF logs
kubectl logs -n omec -l app=amf | grep -i ngap

# Check gNB logs
kubectl logs -n omec -l app=ueransim-gnb
```

### Out of resources?
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n omec

# Consider upgrading to t3.xlarge
```

## Next Steps

- 📖 Read detailed documentation in [docs/](docs/)
- 🔧 Customize configuration in [examples/](examples/)
- 🐛 Report issues on [GitHub](https://github.com/cput-it-advdip/aether-open5g/issues)
- 🤝 Contribute via [CONTRIBUTING.md](CONTRIBUTING.md)

## Estimated Timeline

| Step | Time | Cumulative |
|------|------|------------|
| Launch EC2 | 5 min | 5 min |
| Setup System | 10 min | 15 min |
| Deploy SD-Core | 5 min | 20 min |
| Deploy RAN | 3 min | 23 min |
| Verification | 2 min | 25 min |

**Total: ~25 minutes** from zero to running 5G network!

## Cost Estimate

AWS EC2 t3.large pricing (approximate):
- On-Demand: ~$0.08/hour (~$60/month)
- Spot Instance: ~$0.02/hour (~$15/month)

Storage (50GB gp3): ~$4/month

**Total estimated cost: ~$20-65/month** depending on usage pattern.

## Support

- 📧 Email: support@example.com
- 💬 Discussions: [GitHub Discussions](https://github.com/cput-it-advdip/aether-open5g/discussions)
- 🐛 Issues: [GitHub Issues](https://github.com/cput-it-advdip/aether-open5g/issues)
