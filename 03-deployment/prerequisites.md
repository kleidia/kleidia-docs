# Deployment Prerequisites

**Audience**: Operations Administrators  
**Prerequisites**: Basic Linux and Kubernetes knowledge  
**Outcome**: Understand system requirements and prerequisites for deployment

## Prerequisites

### Kubernetes Cluster

Kleidia requires an existing Kubernetes cluster (version 1.24+) with:

- **NodePort Services**: Support for NodePort service type
- **Persistent Volumes**: Storage class for persistent volumes
- **RBAC**: Role-based access control enabled
- **Network Policies**: Optional, but recommended

**Note**: The specific Kubernetes distribution (k0s, k3s, EKS, AKS, GKE, etc.) is not relevant - any compatible Kubernetes cluster will work.

### External Load Balancer

Kleidia services are exposed via NodePort and require an external load balancer for:

- **SSL Termination**: TLS/HTTPS termination
- **Load Balancing**: Distribution of traffic to NodePort services
- **DNS Integration**: Domain name routing

The external load balancer configuration is customer-specific and not covered in this documentation.

### Domain and SSL Requirements

- **Domain Name**: Registered domain pointing to load balancer IP
- **DNS Configuration**: A record for your domain (e.g., `kleidia.example.com`)
- **SSL Certificate**: TLS certificate for your domain (managed by your load balancer)

### Operator Tools

For deployment and management, operators need:

- **Helm**: Kubernetes package manager (version 3.8+)
- **kubectl**: Kubernetes command-line tool configured for your cluster

### Workstation Requirements (for Agents)

- **Operating System**: 
  - Windows 10 or Windows 11
  - macOS (latest versions)
- **Agent Installation**: Pre-built agent installer packages available
- **Network Access**: Outbound HTTPS to Kleidia server (no inbound ports required)
- **USB Access**: Direct USB access to YubiKey devices

**Note**: The agent installer includes ykman (YubiKey Manager CLI) - no separate installation required.

## Network Requirements

### Load Balancer Configuration

Your external load balancer should:

- **Route HTTPS Traffic**: Route port 443 traffic to Kubernetes NodePort services
- **Health Checks**: Configure health checks for backend and frontend services
- **SSL Termination**: Handle TLS/SSL certificate management

### Agent Workstations
- **No Inbound Ports**: Agents use localhost only (port 56123)
- **Outbound HTTPS**: To Kleidia server for agent operations

### DNS Configuration

1. **A Record**: Point domain to server IP
   ```
   kleidia.example.com → 192.0.2.1
   ```

2. **Verification**: Verify DNS resolution
   ```bash
   dig kleidia.example.com
   nslookup kleidia.example.com
   ```

## Storage Requirements

### Main Disk

- **Purpose**: Kubernetes cluster, application data, system files
- **Minimum**: 30GB available
- **Recommended**: 50GB+ for production
- **Usage**: 
  - Kubernetes system files (~5GB)
  - Container images (~10GB)
  - Application data (~10GB)
  - Logs and temporary files (~5GB)


### Persistent Volumes

Kubernetes persistent volumes for:
- **PostgreSQL**: 10GB+ (database data)
- **OpenBao (Vault)**: 10GB+ (secrets and PKI data)
- **Audit Storage**: 10GB+ (Vault audit logs)

## Security Prerequisites

### Kubernetes Security

- **RBAC**: Role-based access control configured
- **Network Policies**: Optional, but recommended for network segmentation
- **Pod Security Standards**: Configured according to your security requirements

## Pre-Deployment Checklist

Before starting deployment, verify:

- [ ] Kubernetes cluster (1.24+) is available and accessible
- [ ] kubectl configured and working with your cluster
- [ ] Helm 3.8+ installed
- [ ] Domain name registered and DNS configured
- [ ] External load balancer configured for SSL termination
- [ ] Persistent storage available (StorageClass configured)
- [ ] Sufficient resources available (CPU, memory, storage)
- [ ] Backup strategy planned
- [ ] Monitoring solution planned (optional)

## Next Steps

After verifying prerequisites:

1. **Clone Repository**: See [Helm Installation](helm-install.md)
2. **Configure Values**: See [Configuration](configuration.md)
3. **Deploy**: See [Helm Installation](helm-install.md)
4. **Verify**: See [Troubleshooting](troubleshooting.md)

## Related Documentation

- [Helm Installation](helm-install.md)
- [Configuration](configuration.md)
- [Vault Setup](vault-setup.md)

