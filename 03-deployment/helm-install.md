# Helm Installation Guide

**Audience**: Operations Administrators  
**Prerequisites**: Kubernetes cluster, Helm 3.8+, kubectl  
**Outcome**: Successfully deploy Kleidia using Helm charts

## Overview

Kleidia uses Helm charts as the primary deployment method. The Helm charts provide complete infrastructure-as-code deployment with automatic configuration of all components.

## Prerequisites

Before deploying, ensure:

- ✅ Kubernetes cluster (1.24+) available and accessible
- ✅ Helm 3.8+ installed
- ✅ kubectl configured and working
- ✅ Domain name configured with DNS A record
- ✅ External load balancer configured for SSL termination
- ✅ Sufficient disk space (30GB+ minimum)

See [Prerequisites](prerequisites.md) for detailed requirements.

## Installation Steps

### 1. Clone Repository

```bash
# Clone the repository
git clone https://github.com/your-org/kleidia.git
cd kleidia
```

### 2. Configure Values

Create a `values.yaml` file or use command-line overrides:

```yaml
global:
  domain: kleidia.example.com
  namespace: kleidia

backend:
  replicas: 2
  image:
    tag: latest

frontend:
  replicas: 2
  image:
    tag: latest
```

### 3. Install Helm Charts

Kleidia uses multiple Helm charts that must be installed in order.

> **Important**: Before installing, decide on your storage strategy. See [Storage Configuration](storage-configuration.md) for details.

#### Step 1: Install Platform (OpenBao, Storage)

**Option A: With Local Path Provisioner** (single-node/development):

```bash
# Ensure storage directory exists on the node
sudo mkdir -p /opt/local-path-provisioner

helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set storage.className=local-path \
  --set storage.localPath.enabled=true \
  --set openbao.server.dataStorage.storageClass=local-path \
  --set openbao.server.auditStorage.storageClass=local-path
```

**Option B: With Existing StorageClass** (production):

```bash
helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set storage.className=nfs-client \
  --set storage.localPath.enabled=false \
  --set openbao.server.dataStorage.storageClass=nfs-client \
  --set openbao.server.auditStorage.storageClass=nfs-client
```

Replace `nfs-client` with your cluster's StorageClass name (e.g., `longhorn`, `gp2`, `managed-premium`).

**What this installs**:
- OpenBao (Vault) with persistent storage
- Local path provisioner (if enabled)
- Vault configuration hooks with AppRole authentication

**Wait for**: OpenBao to be ready and unsealed (5-10 minutes)

#### Step 2: Install Data Layer (PostgreSQL)

The data layer automatically selects the PostgreSQL deployment method based on your Kubernetes version:

| Kubernetes Version | PostgreSQL Method | TLS Support |
|:-------------------|:------------------|:------------|
| 1.32+ | CloudNativePG (CNPG) | ✅ Full TLS 1.3 with certificates |
| < 1.32 | Legacy StatefulSet | ❌ No TLS (internal network only) |

**Standard Installation (auto-detects K8s version):**

```bash
# Use the same storage class as the platform chart
helm install kleidia-data ./helm/kleidia-data \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set storage.className=local-path  # Must match platform chart
```

**Force Legacy PostgreSQL (optional, for older Kubernetes):**

```bash
# Explicitly disable CNPG for K8s < 1.32
helm install kleidia-data ./helm/kleidia-data \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set storage.className=local-path \
  --set cnpg.enabled=false
```

> ⚠️ **Note**: Legacy PostgreSQL does not support TLS. Database connections are unencrypted but remain within the Kubernetes internal network. For production deployments requiring encrypted database connections, use Kubernetes 1.32+ with CloudNativePG.

**What this installs**:
- PostgreSQL with persistent storage (CNPG or legacy based on K8s version)
- Database initialization hooks
- TLS certificates via cert-manager (CNPG only)

**Wait for**: PostgreSQL to be ready (2-3 minutes)

#### Step 3: Install Services (Backend, Frontend)

**Basic Installation:**

```bash
helm install kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia
```

**With Database TLS (CloudNativePG, Kubernetes 1.32+):**

When using CloudNativePG for PostgreSQL (automatically enabled on K8s 1.32+), enable TLS for encrypted database connections:

```bash
helm install kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set database.tls.enabled=true \
  --set database.tls.sslMode=verify-full \
  --set database.tls.clientCertSecret=kleidia-db-client-tls \
  --set database.tls.caSecret=kleidia-db-ca
```

This enables TLS 1.3 encryption with certificate verification for all database connections.

> ⚠️ **Note**: Database TLS is only available with CloudNativePG (Kubernetes 1.32+). On older Kubernetes versions using legacy PostgreSQL, omit the `database.tls.*` settings.

**What this installs**:
- Backend API server (with AppRole authentication to OpenBao)
- Frontend web application
- License service
- NodePort services for external load balancer routing

**Wait for**: All pods to be ready (2-3 minutes)

### 4. Verify Installation

```bash
# Check all pods are running
kubectl get pods -n kleidia

# Check services
kubectl get services -n kleidia

# Check persistent volumes
kubectl get pvc -n kleidia

# Check OpenBao status
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status
```

### 5. Configure External Load Balancer

Your external load balancer should route HTTPS traffic to the Kubernetes NodePort services. Configuration is customer-specific and depends on your load balancer solution.

## Installation Verification

### Check Pod Status

```bash
# All pods should be Running
kubectl get pods -n kleidia

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# kleidia-platform-openbao-0              1/1     Running   0          5m
# kleidia-data-postgres-cluster-0         1/1     Running   0          3m
# kleidia-services-backend-xxx            1/1     Running   0          2m
# kleidia-services-frontend-xxx           1/1     Running   0          2m
```

### Check Services

```bash
# Check NodePort services
kubectl get services -n kleidia

# Expected output:
# NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# backend-service             NodePort    10.x.x.x       <none>        8080:32570/TCP
# frontend-service            NodePort    10.x.x.x       <none>        3000:30805/TCP
# kleidia-platform-openbao    ClusterIP   10.x.x.x       <none>        8200/TCP
# postgres-cluster            ClusterIP   10.x.x.x       <none>        5432/TCP
```

### Test Application

```bash
# Test backend health
curl http://localhost:32570/api/health

# Test frontend (via external load balancer)
curl -I https://kleidia.example.com

# Test SSL certificate
openssl s_client -connect kleidia.example.com:443 -servername kleidia.example.com
```

## Post-Installation

### 1. Access Web Interface

Open browser to: `https://kleidia.example.com`

### 2. First-Time Setup: Create Administrator Account

On first access, you'll see the bootstrap screen to create the initial administrator account:

1. **Create Admin Account**:
   - Default username: `admin` (customizable)
   - Set a strong password
   - Confirm password
   - Click "Create Admin"

2. **Automatic Login**: After creation, you'll be automatically logged in

**Security Notes**:
- The bootstrap screen only appears on fresh installations with no admin users
- A race-condition lock prevents multiple simultaneous admin account creations
- The lock expires after 10 minutes if abandoned

### 3. OpenBao Bootstrap Keys Modal

**⚠️ CRITICAL SECURITY STEP**

Immediately after first admin login, a **non-dismissible modal** will appear displaying OpenBao initialization keys:

**What You'll See**:
- **Root Token**: Master access token for OpenBao
- **Recovery Key 1, 2, 3**: Emergency recovery keys for OpenBao

**Required Actions**:
1. **Copy all keys** to a secure location:
   - Use a password manager
   - Store in encrypted storage
   - Print and store in a safe
   - **DO NOT** store in plain text files
2. **Use the copy buttons** provided for each key
3. **Check the acknowledgment checkbox**: "I have securely saved these keys..."
4. **Click "Confirm & Delete Keys from Cluster"**

**Important Notes**:
- ⚠️ The modal **cannot be dismissed** without confirming
- ⚠️ Keys are **permanently deleted** from Kubernetes after confirmation
- ⚠️ **You cannot retrieve these keys later**
- ⚠️ These keys are needed for emergency OpenBao recovery operations
- ✅ The modal only appears **once** on first admin login
- ✅ Subsequent logins will not show the modal

**What Happens After Confirmation**:
- Keys are deleted from the Kubernetes secret `openbao-init-keys`
- Action is logged in audit logs
- Dashboard loads normally
- Keys are no longer accessible from the cluster

### 4. Initial Configuration

After securing the OpenBao keys, complete the initial configuration:

1. Configure organization settings
2. Review security policies
3. Set up backup procedures
4. Create additional admin or user accounts

## Troubleshooting

### Pods Not Starting

```bash
# Check pod logs
kubectl logs -f <pod-name> -n kleidia

# Check pod events
kubectl describe pod <pod-name> -n kleidia

# Common issues:
# - Image pull errors: Check registry configuration
# - Resource constraints: Check node resources
# - Storage issues: Check PVC status
```

### OpenBao Not Unsealed

```bash
# Check OpenBao status
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status

# If sealed, check auto-unseal configuration
kubectl logs kleidia-platform-openbao-0 -n kleidia | grep -i unseal
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
kubectl logs -f kleidia-data-postgres-cluster-0 -n kleidia

# Check backend logs for connection errors
kubectl logs -f deployment/kleidia-services-backend -n kleidia | grep -i postgres
```

## Upgrading

To upgrade an existing installation:

```bash
# Upgrade platform
helm upgrade kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --set global.domain=kleidia.example.com

# Upgrade data layer
helm upgrade kleidia-data ./helm/kleidia-data \
  --namespace kleidia

# Upgrade services
helm upgrade kleidia-services ./helm/kleidia-services \
  --namespace kleidia
```

See [Upgrades and Rollback](upgrades-and-rollback.md) for detailed upgrade procedures.

## Uninstallation

To completely remove Kleidia:

```bash
# Uninstall services
helm uninstall kleidia-services -n kleidia

# Uninstall data layer (WARNING: This deletes data!)
helm uninstall kleidia-data -n kleidia

# Uninstall platform
helm uninstall kleidia-platform -n kleidia

# Delete namespace (removes all resources)
kubectl delete namespace kleidia
```

**⚠️ WARNING**: Uninstalling the data layer will delete all data. Ensure backups are taken before uninstallation.

## Related Documentation

- [Prerequisites](prerequisites.md)
- [Configuration](configuration.md)
- [Vault Setup](vault-setup.md)
- [Upgrades and Rollback](upgrades-and-rollback.md)
- [Troubleshooting](troubleshooting.md)

