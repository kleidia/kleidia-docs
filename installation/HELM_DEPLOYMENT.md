# Kleidia Helm Chart Deployment Guide

## Overview

This guide covers the complete deployment of Kleidia using Helm charts. Helm charts provide infrastructure-as-code deployment with automatic configuration of all components.

**For automated CI/CD pipeline deployments**, see [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md) for an overview, or platform-specific guides:
- [GitHub Actions Deployment](GITHUB_ACTIONS_DEPLOYMENT.md)
- [GitLab CI Deployment](GITLAB_CI_DEPLOYMENT.md)
- [Bamboo Deployment](BAMBOO_DEPLOYMENT.md)

## Deployment Scenarios

Kleidia supports two deployment scenarios:

### Standalone Server Deployment

Deploy Kleidia on a standalone server with automatic k0s Kubernetes cluster provisioning:

- **Automatic k0s Installation**: Lightweight Kubernetes distribution automatically installed
- **All-in-One**: All components (Kubernetes, database, Vault (internal default), load balancer) on single server
- **Quick Setup**: Rapid deployment for single-server environments
- **Resource Efficient**: Minimal overhead for smaller deployments

### Existing Kubernetes Cluster Deployment

Deploy Kleidia into an existing Kubernetes cluster:

- **Cluster Integration**: Works with existing Kubernetes clusters
- **Shared Infrastructure**: Leverages existing cluster resources and infrastructure
- **Enterprise Ready**: Integrates with existing cluster ingress, storage, and networking
- **Flexible Deployment**: Can use customer load balancer or cluster ingress

## Prerequisites

Before proceeding with deployment, ensure all prerequisites are met. See [Prerequisites](PREREQUISITES.md) for complete requirements.

**Quick Prerequisites Check:**
- Server/cluster meets minimum hardware requirements
- Domain name configured and DNS pointing to server/cluster
- SSL/TLS certificates provisioned (or Let's Encrypt configured if using)
- kubectl and Helm installed
- Customer container registry/Artifactory accessible
- Vault option selected (internal or external)
- If external Vault: Vault configured with required engines, policies, and AppRole credentials
- If internal Vault (existing cluster): Storage classes and PVCs configured
- Deployment scenario selected (standalone server or existing cluster)

## Deployment Process

### Step 1: Prerequisites Setup

```bash
# Connect to your server
ssh user@your-server-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install Helm (if not already installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm installation
helm version
```

### Step 2: Clone Repository

```bash
# Clone Kleidia repository
git clone https://github.com/your-org/kleidia.git
cd kleidia

# Verify Helm chart exists
ls -la helm/kleidia/
```

### Step 3: Deploy with Helm Chart

**Standalone Server Deployment:**

**With Internal Vault (Default):**

```bash
# Deploy infrastructure using Helm chart (standalone server with internal Vault)
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=standalone \
  --set vault.type=internal

# Monitor deployment progress
watch kubectl get pods -n kleidia
```

**With External Vault:**

```bash
# Deploy infrastructure using Helm chart (standalone server with external Vault)
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=standalone \
  --set vault.type=external \
  --set vault.address=https://vault.example.com:8200 \
  --set vault.appRole.roleId=your-role-id \
  --set vault.appRole.secretIdSecret=vault-approle-secret \
  --set vault.path=yubikeys

# Monitor deployment progress
watch kubectl get pods -n kleidia
```

**Existing Kubernetes Cluster Deployment:**

**Option 1 - With External PostgreSQL and Internal Vault:**

```bash
# Deploy into existing Kubernetes cluster with external PostgreSQL
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster \
  --set database.type=external \
  --set database.host=postgres.example.com \
  --set database.port=5432 \
  --set database.name=kleidia_db \
  --set database.username=kleidia_user \
  --set database.passwordSecret=postgres-credentials \
  --set vault.type=internal \
  --set storage.vault.storageClassName=your-storage-class \
  --set storage.vault.size=20Gi

# Monitor deployment progress
watch kubectl get pods -n kleidia
```

**Option 1b - With External PostgreSQL and External Vault:**

```bash
# Deploy into existing Kubernetes cluster with external PostgreSQL and external Vault
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster \
  --set database.type=external \
  --set database.host=postgres.example.com \
  --set database.port=5432 \
  --set database.name=kleidia_db \
  --set database.username=kleidia_user \
  --set database.passwordSecret=postgres-credentials \
  --set vault.type=external \
  --set vault.address=https://vault.example.com:8200 \
  --set vault.appRole.roleId=your-role-id \
  --set vault.appRole.secretIdSecret=vault-approle-secret \
  --set vault.path=yubikeys

# Monitor deployment progress
watch kubectl get pods -n kleidia
```

**Option 2 - With PostgreSQL within Kubernetes and Internal Vault:**

```bash
# Deploy into existing Kubernetes cluster with PostgreSQL within cluster
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster \
  --set database.type=internal \
  --set storage.postgres.storageClassName=your-storage-class \
  --set storage.postgres.size=50Gi \
  --set vault.type=internal \
  --set storage.vault.storageClassName=your-storage-class \
  --set storage.vault.size=20Gi

# Monitor deployment progress
watch kubectl get pods -n kleidia

# Verify PVCs are created and bound
kubectl get pvc -n kleidia
```

### Deployment Configuration

The Helm chart accepts the following configuration options:

**Standalone Server Deployment Examples:**

**With Internal Vault (Default):**

```bash
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set vault.type=internal \
  --set components.backend.image.tag=latest \
  --set components.frontend.image.tag=latest
```

**With External Vault:**

```bash
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set vault.type=external \
  --set vault.address=https://vault.example.com:8200 \
  --set vault.appRole.roleId=your-role-id \
  --set vault.appRole.secretIdSecret=vault-approle-secret \
  --set vault.path=yubikeys \
  --set components.backend.image.tag=latest \
  --set components.frontend.image.tag=latest
```

**Existing Kubernetes Cluster Deployment Examples:**

**With External PostgreSQL and Internal Vault:**

```bash
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster \
  --set database.type=external \
  --set database.host=postgres.example.com \
  --set database.port=5432 \
  --set database.name=kleidia_db \
  --set database.username=kleidia_user \
  --set database.passwordSecret=postgres-credentials \
  --set vault.type=internal \
  --set storage.vault.storageClassName=customer-storage-class \
  --set storage.vault.size=20Gi
```

**With External PostgreSQL and External Vault:**

```bash
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster \
  --set database.type=external \
  --set database.host=postgres.example.com \
  --set database.port=5432 \
  --set database.name=kleidia_db \
  --set database.username=kleidia_user \
  --set database.passwordSecret=postgres-credentials \
  --set vault.type=external \
  --set vault.address=https://vault.customer.com:8200 \
  --set vault.appRole.roleId=customer-role-id \
  --set vault.appRole.secretIdSecret=vault-approle-secret \
  --set vault.path=yubikeys
```

**With PostgreSQL within Kubernetes and Internal Vault:**

```bash
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster \
  --set database.type=internal \
  --set storage.postgres.storageClassName=customer-storage-class \
  --set storage.postgres.size=50Gi \
  --set vault.type=internal \
  --set storage.vault.storageClassName=customer-storage-class \
  --set storage.vault.size=20Gi
```

**With PostgreSQL within Kubernetes and External Vault:**

```bash
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.namespace=kleidia \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster \
  --set database.type=internal \
  --set storage.postgres.storageClassName=customer-storage-class \
  --set storage.postgres.size=50Gi \
  --set vault.type=external \
  --set vault.address=https://vault.customer.com:8200 \
  --set vault.appRole.roleId=customer-role-id \
  --set vault.appRole.secretIdSecret=vault-approle-secret \
  --set vault.path=yubikeys
```

**Configuration Options:**

**Common Options:**
- `global.domain`: Your domain name (required)
- `global.namespace`: Kubernetes namespace (default: kleidia)
- `global.registry.host`: Customer Docker registry/Artifactory host (required)
- `global.registry.authSecret`: Kubernetes secret name for registry authentication (optional, if registry requires auth)
- `components.backend.image.tag`: Backend image tag (optional)
- `components.frontend.image.tag`: Frontend image tag (optional)
- `global.certificate.type`: Certificate type: `provided` (default), `letsencrypt`, or `cert-manager`
- `global.certificate.secretName`: Kubernetes secret name for pre-provisioned certificates (if using `provided`)

**Existing Kubernetes Cluster - Database Options:**
- `database.type`: Database type: `external` (customer PostgreSQL) or `internal` (deployed within cluster) (required for existing cluster)
- `database.host`: PostgreSQL host (required if `database.type=external`)
- `database.port`: PostgreSQL port (default: 5432, required if `database.type=external`)
- `database.name`: Database name (required if `database.type=external`)
- `database.username`: Database username (required if `database.type=external`)
- `database.passwordSecret`: Kubernetes secret name containing database password (required if `database.type=external`)
- `database.sslMode`: SSL mode for PostgreSQL connection (optional: `disable`, `require`, `verify-ca`, `verify-full`)

**Existing Kubernetes Cluster - Storage Options:**
- `storage.postgres.enabled`: Enable PostgreSQL PVC (default: true if `database.type=internal`)
- `storage.postgres.size`: PostgreSQL PVC size (default: 50Gi, only if `database.type=internal`)
- `storage.postgres.storageClassName`: Storage class for PostgreSQL PVC (required if `database.type=internal`)
- `storage.postgres.accessMode`: Access mode for PostgreSQL PVC (default: ReadWriteOnce)
- `storage.vault.enabled`: Enable Vault PVC (default: true if `vault.type=internal` and `global.deployment.type=existing-cluster`)
- `storage.vault.size`: Vault PVC size (default: 20Gi, only if `vault.type=internal`)
- `storage.vault.storageClassName`: Storage class for Vault PVC (required if `vault.type=internal` and `global.deployment.type=existing-cluster`)
- `storage.vault.accessMode`: Access mode for Vault PVC (default: ReadWriteOnce)

**Vault Configuration:**
- `vault.type`: Vault type: `internal` (deployed within cluster, default for standalone) or `external` (customer-managed existing Vault instance) (required for existing cluster)
- `vault.address`: External Vault address (required if `vault.type=external`, e.g., `https://vault.example.com:8200`)
- `vault.appRole.roleId`: Vault AppRole role ID (required if `vault.type=external`)
- `vault.appRole.secretIdSecret`: Kubernetes secret name containing AppRole secret ID (required if `vault.type=external`)
- `vault.path`: Vault KV v2 mount path (default: `yubikeys`)
- `vault.tls.skipVerify`: Skip TLS certificate verification (default: `false`, use `true` for self-signed certificates, only if `vault.type=external`)
- `vault.tls.caSecret`: Kubernetes secret name containing Vault CA certificate (optional, for custom CA, only if `vault.type=external`)

### Step 4: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n kleidia

# Expected output (with internal Vault):
# NAME                          READY   STATUS    RESTARTS   AGE
# backend-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
# frontend-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
# postgres-0                     1/1     Running   0          2m
# vault-0                        1/1     Running   0          2m

# Expected output (with external Vault):
# NAME                          READY   STATUS    RESTARTS   AGE
# backend-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
# frontend-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
# postgres-0                     1/1     Running   0          2m

# Check services
kubectl get services -n kleidia

# Check ingress
kubectl get ingress -n kleidia
```

### Step 5: Verify SSL Certificate

```bash
# Test SSL certificate
curl -I https://your-domain.com

# Verify certificate details
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# For air-gapped deployments or custom CA, verify certificate chain
openssl s_client -connect your-domain.com:443 -servername your-domain.com -showcerts
```

### Step 6: Test Application Health

```bash
# Test application health endpoint
curl https://your-domain.com/api/health

# Expected response:
# {"status":"ok","version":"2.2.0"}
```

### Step 7: Access Web Portal

Open your browser and navigate to:
- **Web Interface**: `https://your-domain.com`
- **API Health**: `https://your-domain.com/api/health`

**Default Admin Credentials:**
- **Email**: `admin@kleidia.local`
- **Password**: `admin_password_change_me` (change immediately after first login)

## What Gets Deployed

The Helm chart automatically deploys (deployment scenario dependent):

### Infrastructure Components

#### Standalone Server Deployment
1. **Kubernetes Cluster**: k0s lightweight Kubernetes distribution (automatically provisioned)
2. **PostgreSQL Database**: Managed database with persistent storage
3. **Vault Options**:
   - **Option 1 (Internal Vault)**: OpenBao Vault pod deployed within Kubernetes with automatic provisioning (default)
   - **Option 2 (External Vault)**: Customer-managed OpenBao or HashiCorp Vault instance (external to deployment)
4. **HAProxy (External Load Balancer)**: Host-level load balancing with SSL termination, communicates with Kubernetes services via NodePort by default
5. **SSL/TLS Certificates**: Customer-provided certificates (default) or Let's Encrypt (optional)

#### Existing Kubernetes Cluster Deployment

**PostgreSQL Options:**

1. **Option 1 - Customer External PostgreSQL**:
   - **External PostgreSQL Cluster**: Customer-managed PostgreSQL outside Kubernetes
   - **Connection**: Backend connects to external PostgreSQL via connection string
   - **No PVC Required**: PostgreSQL storage managed by customer

2. **Option 2 - PostgreSQL within Kubernetes**:
   - **PostgreSQL Database**: Deployed within cluster with customer-provided Persistent Volume Claims (PVCs)
   - **PVC Required**: Storage class and PVC configuration required

**Common Components:**
- **Vault Options**:
  - **Option 1 (Internal Vault)**: OpenBao Vault pod deployed within Kubernetes with customer-provided Persistent Volume Claims (PVCs)
  - **Option 2 (External Vault)**: Customer-managed OpenBao or HashiCorp Vault instance (external to deployment)
- **Load Balancer/Ingress**: Uses customer load balancer or existing cluster ingress
- **SSL/TLS Certificates**: Customer-provided certificates (default) or Let's Encrypt/cert-manager (optional)
- **Storage**: Customer-managed storage classes and PVCs required for PostgreSQL (if Option 2 selected) and/or Vault (if Vault Option 1 selected) (see [Prerequisites](PREREQUISITES.md#storage-configuration))

### Application Components

1. **Frontend**: Nuxt.js 4 web portal
2. **Backend**: Go/Gin API server
3. **Database**: PostgreSQL with automated migrations
4. **Vault Options**:
   - **Internal Vault**: OpenBao Vault pod with PKI and KV v2 secret engines (automatically configured)
   - **External Vault**: Backend configured to connect to customer's external Vault instance

### Security Components

1. **RBAC**: Role-based access control for all components
2. **Pod Security Standards**: Restricted security contexts
3. **Network Policies**: Kubernetes network segmentation
4. **Encrypted Secrets**: AES-256-GCM encryption for sensitive data

### Monitoring Components

1. **Health Checks**: Built-in health check endpoints
2. **Readiness Probes**: Kubernetes readiness probes
3. **Liveness Probes**: Kubernetes liveness probes
4. **Log Aggregation**: Centralized logging via Kubernetes

## Vault Configuration

Kleidia supports two Vault deployment options: **Internal Vault** (deployed within Kubernetes) or **External Vault** (customer-managed existing instance).

### Internal Vault Configuration (Deployed within Kubernetes)

When using `vault.type=internal`, the Helm chart automatically:

1. **Deploys Vault Pod**: OpenBao Vault pod deployed within Kubernetes cluster
2. **Provisions Storage**: Automatically provisions persistent volumes (standalone) or uses customer-provided PVCs (existing cluster)
3. **Enables AppRole Authentication**: `vault auth enable approle`
4. **Configures PKI Engine**: Creates root CA and roles automatically
5. **Enables KV v2 Secrets Engine**: `vault secrets enable -path=yubikeys kv-v2`
6. **Creates Policies**: Defines backend permissions automatically
7. **Generates Credentials**: Creates AppRole role ID and secret ID automatically
8. **Stores Secrets**: Saves credentials in Kubernetes secrets
9. **Generates Application Secrets**: JWT, encryption, database passwords generated automatically

**No manual configuration required** - the Helm chart handles all Vault setup automatically.

### External Vault Configuration (Customer-managed)

When using `vault.type=external`, Kleidia connects to customer's existing external OpenBao or HashiCorp Vault instance. Customer must configure their Vault instance before deployment.

### Pre-Deployment External Vault Requirements

Customer must configure their external Vault instance with:

1. **KV v2 Secrets Engine**: Enabled at the mount path specified in Helm values (default: `yubikeys`)
   ```bash
   vault secrets enable -path=yubikeys kv-v2
   ```

2. **AppRole Authentication**: Enabled and configured
   ```bash
   vault auth enable approle
   ```

3. **AppRole Policy**: Policy granting access to the KV v2 mount path
   ```hcl
   path "yubikeys/data/*" {
     capabilities = ["create", "read", "update", "delete", "list"]
   }
   path "yubikeys/metadata/*" {
     capabilities = ["list", "read", "delete"]
   }
   ```

4. **AppRole Role**: Role created with the policy attached
   ```bash
   vault write auth/approle/role/kleidia-backend \
     token_policies="kleidia-backend" \
     token_ttl=1h \
     token_max_ttl=4h
   ```

5. **AppRole Credentials**: Role ID and Secret ID generated
   ```bash
   vault read auth/approle/role/kleidia-backend/role-id
   vault write -f auth/approle/role/kleidia-backend/secret-id
   ```

### External Vault Configuration in Helm

The Helm chart connects to the customer's external Vault using AppRole authentication:

```bash
# Create Kubernetes secret with AppRole secret ID
kubectl create secret generic vault-approle-secret \
  --from-literal=secret-id=your-secret-id \
  -n kleidia

# Deploy with Vault configuration
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set vault.address=https://vault.example.com:8200 \
  --set vault.appRole.roleId=your-role-id \
  --set vault.appRole.secretIdSecret=vault-approle-secret \
  --set vault.path=yubikeys
```

### Vault Connection Verification

After deployment, verify Vault connectivity:

**For Internal Vault:**
```bash
# Check Vault pod status
kubectl get pods -n kleidia | grep vault

# Check Vault status
kubectl exec -it vault-0 -n kleidia -- vault status

# Check backend logs for Vault connection
kubectl logs -f deployment/backend -n kleidia | grep -i vault

# Test Vault connectivity endpoint
curl https://your-domain.com/api/admin/system/vault
```

**For External Vault:**
```bash
# Check backend logs for Vault connection status
kubectl logs -f deployment/backend -n kleidia | grep -i vault

# Test Vault connectivity from backend pod
kubectl exec -it deployment/backend -n kleidia -- \
  curl -s https://vault.example.com:8200/v1/sys/health

# Test Vault connectivity endpoint
curl https://your-domain.com/api/admin/system/vault
```

## Database Initialization

The Helm chart automatically:

1. **Initializes Database**: Creates database schema
2. **Creates Admin User**: Default admin user created
3. **Seeds Data**: Initial data seeded if needed
4. **Runs Migrations**: Database migrations executed automatically

## Helm Chart Management

### Updating Helm Deployments

```bash
# Update Helm chart with new values
helm upgrade kleidia ./helm/kleidia \
  --namespace kleidia \
  --set global.domain=your-domain.com \
  --set components.backend.image.tag=latest

# Check deployment status
helm status kleidia -n kleidia

# View deployment history
helm history kleidia -n kleidia
```

### Helm Chart Rollback

```bash
# Rollback to previous version
helm rollback kleidia -n kleidia

# Rollback to specific revision
helm rollback kleidia 2 -n kleidia
```

### Viewing Helm Chart Values

```bash
# View current configuration
helm get values kleidia -n kleidia

# View all values (including defaults)
helm get values kleidia -n kleidia --all
```

## Post-Deployment Verification

### Application Health

```bash
# Test application health
curl https://your-domain.com/api/health

# Test individual components
curl https://your-domain.com/api/admin/system/database
curl https://your-domain.com/api/admin/system/vault
# Note: Vault endpoint verifies connectivity to external Vault instance
```

### Service Verification

```bash
# Check all pods are running
kubectl get pods -n kleidia

# Check services are accessible
kubectl get services -n kleidia

# Check ingress configuration
kubectl get ingress -n kleidia
```

### SSL Certificate Verification

```bash
# Verify SSL certificate
curl -I https://your-domain.com

# Check certificate expiration
openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n kleidia

# Check pod logs
kubectl logs -f deployment/backend -n kleidia
kubectl logs -f deployment/frontend -n kleidia

# Check pod events
kubectl get events -n kleidia --sort-by=.metadata.creationTimestamp
```

### SSL Certificate Issues

```bash
# Check HAProxy status
sudo systemctl status haproxy

# Check HAProxy logs
sudo journalctl -u haproxy -f

# Test certificate validity
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

### Vault Issues

**For Internal Vault:**

```bash
# Check Vault pod status
kubectl get pods -n kleidia | grep vault

# Check Vault status
kubectl exec -it vault-0 -n kleidia -- vault status

# Check Vault logs
kubectl logs -f vault-0 -n kleidia

# Test Vault unsealing (if needed)
kubectl exec -it vault-0 -n kleidia -- vault operator unseal

# Check backend logs for Vault connection
kubectl logs -f deployment/backend -n kleidia | grep -i vault

# Test Vault API endpoint
curl https://your-domain.com/api/admin/system/vault
```

**For External Vault:**

```bash
# Check backend logs for Vault connection errors
kubectl logs -f deployment/backend -n kleidia | grep -i vault

# Test Vault connectivity from backend pod
kubectl exec -it deployment/backend -n kleidia -- \
  curl -s https://vault.example.com:8200/v1/sys/health

# Verify Vault configuration in backend
kubectl exec -it deployment/backend -n kleidia -- env | grep -i vault

# Check Vault AppRole secret exists
kubectl get secret vault-approle-secret -n kleidia

# Test Vault API endpoint
curl https://your-domain.com/api/admin/system/vault

# Verify network connectivity to Vault (if accessible from cluster)
kubectl run vault-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s https://vault.example.com:8200/v1/sys/health

# Note: For Vault management issues (unsealing, etc.), contact customer's Vault administrator
```

### Database Issues

**For PostgreSQL Deployed within Kubernetes:**

```bash
# Check database pod status
kubectl get pods -n kleidia | grep postgres

# Check database status
kubectl exec -it postgres-0 -n kleidia -- psql -U kleidia -d kleidia_db

# Check database logs
kubectl logs -f postgres-0 -n kleidia

# Verify database connectivity from backend
kubectl exec -it backend-xxxxxxxxxx-xxxxx -n kleidia -- curl http://localhost:8000/api/admin/system/database

# Check PostgreSQL PVC
kubectl get pvc -n kleidia | grep postgres
```

**For External PostgreSQL:**

```bash
# Verify database connectivity from Kubernetes cluster
kubectl run postgres-test --rm -it --image=postgres:13 --restart=Never -- \
  psql -h postgres.example.com -p 5432 -U kleidia_user -d kleidia_db

# Test connection from backend pod
kubectl exec -it backend-xxxxxxxxxx-xxxxx -n kleidia -- \
  env | grep -i postgres

# Verify database credentials secret exists
kubectl get secret postgres-credentials -n kleidia

# Check backend logs for database connection errors
kubectl logs -f deployment/backend -n kleidia | grep -i postgres

# Verify network connectivity to external PostgreSQL
kubectl run netcat-test --rm -it --image=busybox --restart=Never -- \
  nc -zv postgres.example.com 5432

# Verify database connectivity endpoint
kubectl exec -it backend-xxxxxxxxxx-xxxxx -n kleidia -- \
  curl http://localhost:8000/api/admin/system/database
```

### Resource Issues

```bash
# Check resource usage
kubectl top pods -n kleidia
kubectl top nodes

# Check disk usage
df -h

# Clean Docker cache if needed
docker system prune -af
```

## Performance Optimization

### Installation Timeouts

Kleidia includes optimized timeouts for faster deployment:

- **Database Setup**: ~2 minutes
- **Vault Configuration**: 
  - **Internal Vault**: ~3-5 minutes (automatic configuration)
  - **External Vault**: Vault connectivity verified during deployment
- **Total Installation**: ~5-7 minutes

### Container Registry

Kleidia assumes customers have their own container registry or Artifactory:

- **Customer Registry**: Container images must be pre-loaded to customer registry
- **Registry Access**: Kubernetes cluster must have network access to customer registry
- **Image Pull**: Images are pulled from customer registry during deployment
- **Air-Gapped Support**: Customer registry can be internal (no internet required)

## Next Steps

After successful deployment:

1. **Access Web Portal**: Navigate to `https://your-domain.com`
2. **Change Admin Password**: Update default admin credentials
3. **Install Agents**: Follow [Agent Setup](AGENT_SETUP.md) for workstation agents
4. **Register YubiKeys**: Register your first YubiKey device through the web portal
5. **Review Architecture**: Review [Architecture Documentation](../architecture/README.md) for system overview

## Support

For deployment issues or questions:

- Review troubleshooting sections above
- Check deployment logs: `kubectl logs -n kleidia`
- Contact your account representative for support







