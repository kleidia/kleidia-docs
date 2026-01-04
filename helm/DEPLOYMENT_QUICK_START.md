# Kleidia Deployment Quick Start

## 🚀 Clean Deployment from Scratch

This guide helps you clean up a problematic deployment and start fresh.

## Prerequisites

- `kubectl` configured and connected to your cluster
- `helm` v3.8 or later
- `jq` (optional, for advanced cleanup)

## Quick Start

### Option 1: Automated Cleanup and Deploy (Recommended)

Run the comprehensive cleanup and deployment script:

```bash
cd helm
./cleanup-and-deploy.sh
```

This script will:
1. ✅ Check prerequisites
2. 🧹 Completely clean up existing deployment
3. 🏗️ Deploy fresh from DockerHub images
4. ✓ Verify all components
5. 📊 Show deployment status

### Option 2: Manual Step-by-Step

If you prefer manual control:

```bash
cd helm

# 1. Clean up existing deployment
./deploy-from-dockerhub.sh
# (This script includes cleanup as the first step)
```

## Custom Domain

To deploy with a custom domain:

```bash
export DOMAIN="your-domain.example.com"
./cleanup-and-deploy.sh
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n kleidia
```

### View Backend Logs

```bash
kubectl logs -f deployment/backend -n kleidia
```

### View Frontend Logs

```bash
kubectl logs -f deployment/frontend -n kleidia
```

### Check Services

```bash
kubectl get svc -n kleidia
```

### Access Backend Shell

```bash
kubectl exec -it deployment/backend -n kleidia -- /bin/sh
```

### Test Backend Health

```bash
BACKEND_POD=$(kubectl get pods -n kleidia -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kleidia $BACKEND_POD -- wget -q -O- http://localhost:8080/health
```

## Common Issues and Fixes

### 503 Service Unavailable

**Symptoms:** API calls return 503 errors

**Causes:**
- Backend pods not running
- Backend health checks failing
- Database connection issues
- OpenBao not ready

**Fix:**
```bash
# Check backend pod status
kubectl get pods -n kleidia -l app=backend

# View backend logs
kubectl logs -n kleidia -l app=backend --tail=100

# If pods are not running, check events
kubectl describe pods -n kleidia -l app=backend
```

### Pods Stuck in Pending

**Cause:** PVCs not binding or storage class issues

**Fix:**
```bash
# Check PVC status
kubectl get pvc -n kleidia

# Check storage classes
kubectl get storageclass

# If using local-path, ensure provisioner is installed
kubectl get pods -n local-path-storage
```

### Database Connection Failures

**Symptoms:** Backend logs show database connection errors

**Fix:**
```bash
# Check PostgreSQL pod
kubectl get pods -n kleidia -l app=postgres

# View PostgreSQL logs
kubectl logs -n kleidia -l app=postgres --tail=50

# Test database connectivity from backend
BACKEND_POD=$(kubectl get pods -n kleidia -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kleidia $BACKEND_POD -- nc -zv postgres.kleidia.svc.cluster.local 5432
```

### OpenBao Not Initialized

**Symptoms:** Backend logs show Vault connection errors

**Fix:**
```bash
# Check OpenBao pod status
kubectl get pods -n kleidia | grep openbao

# View OpenBao logs
kubectl logs -n kleidia -l app.kubernetes.io/name=openbao --tail=100

# Check if OpenBao initialization job completed
kubectl get jobs -n kleidia | grep openbao
```

## What Was Fixed

This deployment includes the following fixes:

1. **Added DB_PASSWORD environment variable** to backend deployment
   - Previously missing, causing database connection to fail
   - Now set to empty string (matches PostgreSQL trust auth)

2. **Comprehensive cleanup process**
   - Removes all resources including stuck PVCs
   - Forces namespace deletion if stuck
   - Cleans up orphaned PersistentVolumes

3. **Better error handling**
   - Detailed pod status checks
   - Health endpoint verification
   - Automatic log collection for failed pods

## Deployment Architecture

The deployment consists of three Helm charts installed in order:

1. **kleidia-platform** (OpenBao, Storage)
   - OpenBao StatefulSet (secrets management)
   - Local-path-provisioner (if needed)
   - OpenBao initialization jobs

2. **kleidia-data** (PostgreSQL)
   - PostgreSQL StatefulSet
   - Database initialization ConfigMap
   - PVC for data persistence

3. **kleidia-services** (Backend, Frontend, License)
   - Backend Deployment (2 replicas)
   - Frontend Deployment (2 replicas)
   - License Service Deployment (2 replicas)
   - NodePort Services for external access

## NodePort Configuration

The following NodePorts are exposed for external load balancer:

- **Backend:** 32570 → https://kleidia.example.com/api
- **Frontend:** 30805 → https://kleidia.example.com

Ensure your external load balancer (HAProxy, etc.) is configured to route:
- `https://kleidia.example.com/api/*` → `http://<node-ip>:32570`
- `https://kleidia.example.com/*` → `http://<node-ip>:30805`

## Success Criteria

A successful deployment should show:

✅ All pods in `Running` state
✅ Backend health check returns `{"status":"healthy","service":"Kleidia"}`
✅ Frontend accessible via NodePort
✅ No error logs in backend or frontend pods
✅ PostgreSQL accepting connections
✅ OpenBao initialized and unsealed

## Support

If issues persist after following this guide:

1. Collect pod logs: `kubectl logs -n kleidia <pod-name> > pod.log`
2. Collect pod descriptions: `kubectl describe pod -n kleidia <pod-name> > pod-desc.txt`
3. Check events: `kubectl get events -n kleidia --sort-by='.lastTimestamp'`
4. Review Helm release status: `helm list -n kleidia`

