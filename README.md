# Aether OnRamp on AWS EC2

Aether OnRamp provides a low-overhead way to bring up a Kubernetes cluster, deploy a 5G version of SD-Core on that cluster, and then connect that Core to either an emulated 5G RAN or a network of physical gNBs. OnRamp also supports a 4G configuration that connects physical eNBs.

## Prerequisites

- AWS Account with EC2 access
- AWS CLI configured
- SSH key pair for EC2 instances
- Basic knowledge of Kubernetes and 5G networking

## Infrastructure Requirements

### AWS EC2 Instance Type: t3.large

The t3.large instance is recommended for Aether OnRamp deployment with the following specifications:
- **vCPUs**: 2
- **Memory**: 8 GiB
- **Network Performance**: Up to 5 Gigabit
- **Storage**: EBS-optimized

## Quick Start

**⚡ Want to get started quickly?** See [QUICKSTART.md](QUICKSTART.md) for a 25-minute deployment guide!

### 1. Launch AWS EC2 Instance

```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.large \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=aether-onramp}]'
```

### 2. Connect to Instance

```bash
ssh -i your-key.pem ubuntu@<instance-public-ip>
```

### 3. Install Prerequisites

See [docs/installation.md](docs/installation.md) for detailed installation steps.

### 4. Deploy Kubernetes Cluster

See [docs/kubernetes-setup.md](docs/kubernetes-setup.md) for Kubernetes deployment.

### 5. Deploy SD-Core

See [docs/sd-core-deployment.md](docs/sd-core-deployment.md) for SD-Core 5G deployment.

### 6. Connect RAN

See [docs/ran-connectivity.md](docs/ran-connectivity.md) for RAN connectivity options.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS EC2 t3.large                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Kubernetes Cluster                         │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │          SD-Core 5G                            │  │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐    │  │   │
│  │  │  │   AMF    │  │   SMF    │  │   UPF    │    │  │   │
│  │  │  └──────────┘  └──────────┘  └──────────┘    │  │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐    │  │   │
│  │  │  │  AUSF    │  │   UDM    │  │   PCF    │    │  │   │
│  │  │  └──────────┘  └──────────┘  └──────────┘    │  │   │
│  │  │  ┌──────────┐  ┌──────────┐                  │  │   │
│  │  │  │   NRF    │  │  NSSF    │                  │  │   │
│  │  │  └──────────┘  └──────────┘                  │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ N2/N3 Interface
                            │
                ┌───────────┴───────────┐
                │                       │
        ┌───────▼────────┐     ┌───────▼────────┐
        │  Emulated RAN  │     │  Physical gNBs │
        │   (UERANSIM)   │     │                │
        └────────────────┘     └────────────────┘
```

## Features

- **5G SA Core**: Full 5G Standalone core network
- **4G Support**: Optional 4G/LTE connectivity
- **RAN Options**: 
  - Emulated RAN using UERANSIM
  - Physical gNB connectivity
  - Physical eNB connectivity (4G)
- **Cloud Native**: Kubernetes-based deployment
- **Scalable**: Can be expanded across multiple nodes

## Documentation

- [Installation Guide](docs/installation.md)
- [Kubernetes Setup](docs/kubernetes-setup.md)
- [SD-Core Deployment](docs/sd-core-deployment.md)
- [RAN Connectivity](docs/ran-connectivity.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Configuration Reference](docs/configuration.md)

## Security Considerations

- Configure Security Groups to allow only necessary ports
- Use VPC with private subnets for production deployments
- Enable EC2 instance encryption
- Implement IAM roles with least privilege
- Regular security updates and patches

## Cost Optimization

- Use EC2 Spot Instances for development/testing
- Implement auto-scaling based on load
- Schedule instances to stop during non-business hours
- Monitor and optimize resource usage

## Support

For issues and questions:
- GitHub Issues: [github.com/cput-it-advdip/aether-open5g/issues](https://github.com/cput-it-advdip/aether-open5g/issues)
- Documentation: [docs/](docs/)

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.