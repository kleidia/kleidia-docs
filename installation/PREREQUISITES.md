# Kleidia Installation Prerequisites

## Overview

This document outlines all prerequisites and requirements before installing Kleidia. Ensure all requirements are met before proceeding with installation.

## Server Requirements

### Operating System

- **Ubuntu Server**: 22.04 LTS or later (20.04+ compatible)
- **Root or Sudo Access**: Required for system configuration and package installation
- **Deployment Options**: 
  - Standalone server deployment (k0s cluster automatically provisioned)
  - Existing Kubernetes cluster deployment
- **Network Connectivity**: Supports both air-gapped (offline) and online environments

### Hardware Requirements

Hardware requirements differ based on deployment scenario:

#### Standalone Server Deployment

**Minimum Requirements:**
- **CPU**: 2+ cores
- **RAM**: 4GB+ available memory
- **Storage**: 
  - **Main Disk**: 30GB+ available disk space
- **Network**: Static IP with DNS A record configured (internal or external network)

**Production Requirements:**
- **CPU**: 4+ cores recommended
- **RAM**: 8GB+ recommended
- **Storage**:
  - **Main Disk**: 50GB+ available disk space

#### Existing Kubernetes Cluster Deployment

**Minimum Requirements:**
- **Cluster Resources**: 
  - **CPU**: 2+ cores available for Kleidia components
  - **RAM**: 4GB+ available memory for Kleidia components
  - **Persistent Volume Claims (PVCs)**: Required for database storage if PostgreSQL is deployed within cluster (see [Storage Configuration](#storage-configuration))
- **Network**: Cluster must have network access to customer registry and load balancer/ingress

**Production Requirements:**
- **Cluster Resources**:
  - **CPU**: 4+ cores available recommended
  - **RAM**: 8GB+ available memory recommended
  - **Persistent Volume Claims (PVCs)**: Adequate storage for database if PostgreSQL is deployed within cluster (see [Storage Configuration](#storage-configuration))

### Software Prerequisites

The following software must be installed before deployment:

#### For Standalone Server Deployment
- **Kubernetes**: k0s or compatible Kubernetes distribution (k0s is automatically installed by Helm chart)
- **kubectl**: Kubernetes command-line tool (for deployment verification)
- **Helm**: Version 3.0+ (for Helm chart deployment)
- **HAProxy**: For SSL termination and load balancing (installed by deployment)

#### For Existing Kubernetes Cluster Deployment
- **Existing Kubernetes Cluster**: Version 1.24+ (tested with k0s)
- **kubectl**: Configured to access your Kubernetes cluster
- **Helm**: Version 3.0+ (for Helm chart deployment)
- **External Load Balancer**: Customer-provided load balancer (or use existing cluster ingress)

#### Common Requirements
- **Container Registry**: Customer Docker registry or Artifactory (container images must be pre-loaded)

#### Installing Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y git curl wget openssl

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
kubectl version --client
helm version
```

## Domain & SSL Requirements

### Domain Configuration

- **Domain Name**: Internal or external domain name pointing to server/cluster IP
- **DNS Configuration**: A record for your domain (e.g., `kleidia.example.com`)
- **Internal DNS**: Supported for air-gapped deployments (no external DNS required)

### SSL/TLS Certificate

- **Certificate Authority**: Customer private CA or public CA certificates
- **Certificate Provisioning**: 
  - Pre-provisioned certificates (recommended for air-gapped deployments)
  - Let's Encrypt (optional, requires internet connectivity and port 80 access)
  - Certificate Manager integration (e.g., cert-manager with private CA)
- **Certificate Format**: Standard X.509 certificates (PEM format)

### Verifying DNS Configuration

```bash
# Verify DNS record points to your server
dig your-domain.com
nslookup your-domain.com

# Verify port 80 is accessible
curl -I http://your-domain.com
```

## Vault Requirements (OpenBao/HashiCorp Vault)

Kleidia supports two Vault deployment options for enterprise PKI and **Vault-first secret management**: **Internal Vault** (deployed within Kubernetes) or **External Vault** (customer-managed existing instance).

### Option 1: Internal Vault (Deployed within Kubernetes)

When using internal Vault (`vault.type=internal`):

- **Automatic Configuration**: Helm chart automatically configures Vault with required engines, policies, and AppRole credentials
- **No Pre-Configuration Required**: Customer does not need to configure Vault before deployment
- **Standalone Server Deployment**: Vault pod deployed with automatic storage provisioning
- **Existing Cluster Deployment**: Vault pod deployed with customer-provided PVCs (see [Storage Configuration](#storage-configuration))

**Storage Requirements (Existing Cluster Only):**
- **Vault PVC**: Required for Vault data storage
- **Minimum Size**: 10GB
- **Production Size**: 20GB+ recommended
- **Storage Class**: Customer-defined (must support ReadWriteOnce)
- **Access Mode**: ReadWriteOnce

### Option 2: External Vault (Customer-managed)

When using external Vault (`vault.type=external`), Kleidia requires customers to have an **existing external OpenBao or HashiCorp Vault instance** configured before deployment. Customer's Vault can be integrated with private CAs or used standalone.

### Customer External Vault Configuration Requirements

Customer must configure their external Vault instance with the following **before deployment**:

1. **KV v2 Secrets Engine**: Enabled at mount path (default: `yubikeys`)
   ```bash
   vault secrets enable -path=yubikeys kv-v2
   ```

2. **AppRole Authentication**: Enabled
   ```bash
   vault auth enable approle
   ```

3. **AppRole Policy**: Policy granting access to KV v2 mount path
   ```hcl
   path "yubikeys/data/*" {
     capabilities = ["create", "read", "update", "delete", "list"]
   }
   path "yubikeys/metadata/*" {
     capabilities = ["list", "read", "delete"]
   }
   ```

4. **AppRole Role**: Role created with policy attached
   ```bash
   vault write auth/approle/role/kleidia-backend \
     token_policies="kleidia-backend" \
     token_ttl=1h \
     token_max_ttl=4h
   ```

5. **AppRole Credentials**: Role ID and Secret ID generated for Helm deployment
   ```bash
   vault read auth/approle/role/kleidia-backend/role-id
   vault write -f auth/approle/role/kleidia-backend/secret-id
   ```

6. **Network Accessibility**: Vault endpoint must be accessible from Kubernetes cluster
   - Vault address/endpoint (e.g., `https://vault.example.com:8200`)
   - Network connectivity from cluster to Vault
   - SSL/TLS certificates configured (or skip TLS verification for self-signed certificates)

### Vault-First Secret Management

The system implements comprehensive Vault-first secret management for both internal and external Vault options:

**Secret Storage:**
- All application secrets stored in Vault KV v2 engine (`yubikeys/` mount by default)
- JWT signing secrets, encryption keys, database passwords
- Secrets stored and encrypted using Vault's encryption
- Idempotent secret management (safe to redeploy)

**AppRole Authentication:**
- Backend authenticates with Vault using AppRole credentials
- **Internal Vault**: AppRole automatically configured by Helm chart
- **External Vault**: AppRole configured by customer's Vault administrator
- Secure token-based authentication with configurable TTL
- Fine-grained policies (automatically managed for internal Vault, customer-managed for external Vault)

**Secret Rotation:**
- Automated secret rotation via REST API
- Versioning support for rollback scenarios
- Admin-only rotation endpoints with audit logging

### Vault Management

**Internal Vault:**
- Vault lifecycle managed by Helm chart deployment
- Automatic unsealing, backup, and configuration
- Kubernetes pod health monitoring and automatic restarts

**External Vault:**
- Vault management (unsealing, backup, high availability, etc.) is the responsibility of the customer's Vault administrator
- Kleidia connects to the customer's existing Vault infrastructure and does not manage Vault lifecycle operations

## Workstation Requirements (for Agents)

### Operating System Support

Agents run on user workstations with the following OS support:

- **macOS**: 10.15+ (Catalina or later)
- **Windows**: Windows 10+

**Note**: Linux workstations are not supported for agent deployment.

### Software Prerequisites

#### YubiKey Tools

The agent requires the ykman CLI tool for YubiKey operations. Install using one of the following methods:

**macOS:**

**Option 1: Homebrew (Recommended)**
```bash
brew install yubikey-manager
```

**Option 2: Yubico Installer**
Download the macOS installer from [Yubico Downloads - macOS](https://www.yubico.com/support/download/yubikey-manager/)

**Windows:**

**Option 1: Chocolatey (Recommended)**
```powershell
choco install yubikey-manager
```

**Option 2: Yubico Installer**
Download the Windows installer (MSI) from [Yubico Downloads - Windows](https://www.yubico.com/support/download/yubikey-manager/)

**Verification:**
After installation, verify ykman is working:
```bash
ykman --version
```

#### Network Access

- **Outbound HTTPS**: Connection to server on port 443 (HTTPS)
- **No Inbound Ports**: Agents do not require inbound ports (outbound-only)
- **Firewall**: Ensure outbound HTTPS is allowed

#### USB Access

- **Direct USB Access**: Required for YubiKey device operations
- **USB Permissions**: User must have permissions to access USB devices
- **YubiKey Connection**: Physical YubiKey device must be connected to workstation

## Network Requirements

### Server Network

- **Public IP**: Server must have a public IP address
- **DNS Resolution**: Domain must resolve to server IP
- **Port 443**: Must be accessible for HTTPS traffic
- **Port 6443**: Kubernetes API (internal, if k0s is used)

### Workstation Network

- **Network Access**: Outbound HTTPS to server on port 443 (internal or external network)
- **HTTPS Outbound**: Port 443 outbound access to server
- **No Inbound Requirements**: Agents do not require inbound ports

## Storage Configuration

Storage requirements differ significantly between deployment scenarios:

### Standalone Server Deployment

**Direct Storage Requirements:**

The main disk is used for:
- Operating system
- Kubernetes cluster (k0s)
- Application data
- System files
- Persistent volumes for PostgreSQL (deployed within Kubernetes)
- Persistent volumes for Vault (if internal Vault selected, default)

**Storage Requirements:**
- **Minimum**: 30GB available disk space
- **Production**: 50GB+ available disk space recommended

**Automatic Provisioning:**
- Storage is automatically provisioned on the standalone server
- PostgreSQL is deployed within Kubernetes cluster with local persistent volumes
- **Vault Options**:
  - **Internal Vault (Default)**: Vault deployed within Kubernetes cluster with local persistent volumes automatically provisioned
  - **External Vault**: Customer-managed external Vault instance (no storage required in deployment)

### Existing Kubernetes Cluster Deployment

For existing Kubernetes cluster deployments, customers have two PostgreSQL options:

#### Option 1: Customer External PostgreSQL Cluster

**External PostgreSQL Database:**

Customers can use their own external PostgreSQL cluster (managed outside Kubernetes):

**Requirements:**
- **PostgreSQL Version**: 13+ recommended (12+ minimum)
- **Network Access**: Kubernetes cluster must have network access to PostgreSQL
- **Connection**: PostgreSQL connection string/endpoint required
- **Authentication**: Database credentials (username/password) required
- **Database**: Database and user must be pre-created, or creation privileges provided
- **SSL/TLS**: Optional but recommended for production

**Configuration:**
- PostgreSQL connection details provided via Helm values
- No PVC required for PostgreSQL (external database)
- Backend connects to external PostgreSQL instance

#### Option 2: PostgreSQL Deployed within Kubernetes

**PostgreSQL with Persistent Volume Claims (PVCs):**

Alternatively, PostgreSQL can be deployed within the Kubernetes cluster using PVCs:

**Required PVCs:**

1. **PostgreSQL Database PVC**
   - **Purpose**: Database data storage
   - **Minimum Size**: 20GB
   - **Production Size**: 50GB+ recommended
   - **Storage Class**: Customer-defined (must support ReadWriteOnce)
   - **Access Mode**: ReadWriteOnce
   - **Required**: Only if PostgreSQL Option 2 selected (PostgreSQL within Kubernetes)

2. **OpenBao Vault PVC**
   - **Purpose**: Vault data and secrets storage
   - **Minimum Size**: 10GB
   - **Production Size**: 20GB+ recommended
   - **Storage Class**: Customer-defined (must support ReadWriteOnce)
   - **Access Mode**: ReadWriteOnce
   - **Required**: Only if Vault Option 1 selected (Internal Vault within Kubernetes)

**Note**: If external Vault is selected, no Vault PVC is required. Storage for external Vault is managed by the customer's Vault infrastructure.

**PVC Configuration:**

PVCs can be provisioned using:
- **Static Provisioning**: Pre-created PVCs provided to Helm chart
- **Dynamic Provisioning**: Storage classes configured in customer cluster

**Helm Chart Configuration:**

**For External PostgreSQL:**
```yaml
# Example configuration for external PostgreSQL
database:
  type: external
  host: postgres.example.com
  port: 5432
  database: kleidia_db
  username: kleidia_user
  passwordSecret: postgres-credentials
  sslMode: require
```

**For PostgreSQL within Kubernetes:**
```yaml
# Example PVC configuration for PostgreSQL within cluster
database:
  type: internal
storage:
  postgres:
    enabled: true
    size: 50Gi
    storageClassName: customer-storage-class
    accessMode: ReadWriteOnce
  vault:
    enabled: true
    size: 20Gi
    storageClassName: customer-storage-class
    accessMode: ReadWriteOnce
```

**Storage Class Requirements (for Option 2):**

- Must support `ReadWriteOnce` access mode
- Must be available in the target namespace
- Customer is responsible for storage class provisioning and management

### Container Registry Requirements

Kleidia assumes customers have their own container registry or Artifactory:

- **Customer Registry**: Docker registry, Harbor, Artifactory, or compatible registry
- **Image Pre-loading**: Container images must be pre-loaded to customer registry
- **Registry Access**: Kubernetes cluster must have access to customer registry
- **Authentication**: Registry authentication supported (imagePullSecrets)
- **Air-Gapped Support**: Registry can be internal (no internet required)

**Note**: The deployment does not provision or manage a container registry. Customers are responsible for their registry infrastructure.

## Security Considerations

### Firewall Configuration

Ensure the following ports are accessible:

**Server:**
- Port 443: HTTPS (for web portal and API)
- Port 80: HTTP (optional, only required for Let's Encrypt certificate provisioning)

**Workstations:**
- No inbound ports required
- Outbound HTTPS to server on port 443

### Access Control

- **SSH Access**: Secure SSH access to server
- **Key-Based Authentication**: Recommended for SSH access
- **Root Access**: Required for initial deployment (can be restricted post-deployment)

## Pre-Installation Checklist

Before proceeding with installation, verify:

**Common Prerequisites:**
- [ ] Domain name is registered and DNS configured
- [ ] Port 443 is accessible for HTTPS traffic
- [ ] kubectl and Helm are installed
- [ ] Customer container registry/Artifactory is accessible
- [ ] SSL/TLS certificates are provisioned (or Let's Encrypt configured if using)
- [ ] Deployment scenario selected (standalone server or existing Kubernetes cluster)
- [ ] Workstations meet agent requirements
- [ ] YubiKey tools installed on workstations
- [ ] Network connectivity verified

**Standalone Server Deployment:**
- [ ] Server meets minimum hardware requirements (CPU, RAM, disk)
- [ ] Operating system is Ubuntu 22.04+ or compatible
- [ ] Sufficient disk space for automatic storage provisioning (30GB+ minimum, 50GB+ recommended)

**Existing Kubernetes Cluster Deployment:**
- [ ] Kubernetes cluster meets minimum resource requirements (CPU, RAM)
- [ ] PostgreSQL deployment option selected:
  - **Option 1 - External PostgreSQL**: 
    - [ ] External PostgreSQL cluster accessible from Kubernetes cluster
    - [ ] PostgreSQL connection details available (host, port, database, credentials)
    - [ ] Network connectivity verified between cluster and PostgreSQL
    - [ ] Database and user pre-created (or creation privileges available)
  - **Option 2 - PostgreSQL within Kubernetes**:
    - [ ] Storage classes available in cluster and accessible in target namespace
    - [ ] PostgreSQL PVC: 20GB+ minimum (50GB+ recommended)
    - [ ] Storage classes support ReadWriteOnce access mode
- [ ] Vault option selected (internal or external)
- [ ] If external Vault: Vault configured with required engines, policies, and AppRole credentials
- [ ] If internal Vault (existing cluster): Vault PVC: 10GB+ minimum (20GB+ recommended)

## Troubleshooting Prerequisites

### DNS Resolution Issues

```bash
# Verify DNS configuration
dig your-domain.com
nslookup your-domain.com

# Check DNS propagation
# DNS changes can take up to 48 hours to propagate globally
```

### Port Accessibility Issues

```bash
# Test port 80 accessibility
curl -I http://your-domain.com

# Test port 443 accessibility
curl -I https://your-domain.com

# Check firewall rules
sudo ufw status
sudo iptables -L
```

### Disk Space Issues

```bash
# Check disk usage
df -h

# Clean Docker cache if needed
docker system prune -af

# Check largest directories
du -h --max-depth=1 / | sort -hr
```

## Next Steps

Once all prerequisites are verified:

1. Proceed to [Helm Deployment](HELM_DEPLOYMENT.md) for installation
2. Review [Architecture Documentation](../architecture/README.md) for system overview
3. Prepare workstation agents following [Agent Setup](AGENT_SETUP.md)







