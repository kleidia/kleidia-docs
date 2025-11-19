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

Kleidia uses multiple Helm charts that must be installed in order:

#### Step 1: Install Platform (OpenBao, Storage)

```bash
helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia
```

**What this installs**:
- OpenBao (Vault) with persistent storage
- Local path provisioner for storage
- cert-manager (if enabled)
- Vault configuration hooks

**Wait for**: OpenBao to be ready and unsealed (5-10 minutes)

#### Step 2: Install Data Layer (PostgreSQL)

```bash
helm install kleidia-data ./helm/kleidia-data \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia
```

**What this installs**:
- PostgreSQL operator
- PostgreSQL cluster with persistent storage
- Database initialization hooks

**Wait for**: PostgreSQL to be ready (2-3 minutes)

#### Step 3: Install Services (Backend, Frontend)

```bash
helm install kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia
```

**What this installs**:
- Backend API server
- Frontend web application
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

### 2. Default Credentials

- **Username**: `admin`
- **Password**: `password` (change immediately!)

### 3. Initial Configuration

1. Change admin password
2. Configure organization settings
3. Review security policies
4. Set up backup procedures

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

