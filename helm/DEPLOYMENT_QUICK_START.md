# Kleidia Deployment Quick Start

## 🚀 Quick Start

Deploy Kleidia's three charts in order, straight from the **public OCI registry** — no clone, no scripts. For the full walkthrough (storage options, TLS, verification) see the **[Helm Installation Guide](../03-deployment/helm-install.md)**.

## Prerequisites

- `kubectl` configured and connected to your cluster
- `helm` v3.8 or later
- A `StorageClass` available in the cluster

## Install

```bash
DOMAIN=kleidia.example.com   # your public domain
SC=local-path                # your StorageClass (e.g. local-path, longhorn, gp2)

# 1/3 — Platform (OpenBao + cert-manager/CNPG bootstrap)
helm install kleidia-platform oci://registry-1.docker.io/therinn/kleidia-platform --version 1.0.0 \
  --namespace kleidia --create-namespace \
  --set global.domain=$DOMAIN --set global.namespace=kleidia \
  --set storage.className=$SC \
  --set openbao.server.dataStorage.storageClass=$SC --set openbao.server.auditStorage.storageClass=$SC
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openbao -n kleidia --timeout=600s

# 2/3 — Data (PostgreSQL via CloudNativePG)
helm install kleidia-data oci://registry-1.docker.io/therinn/kleidia-data --version 2.0.0 \
  --namespace kleidia --set global.domain=$DOMAIN --set global.namespace=kleidia --set storage.className=$SC
kubectl wait --for=condition=Ready cluster/kleidia-db -n kleidia --timeout=300s

# 3/3 — Services (backend, frontend, license)
helm install kleidia-services oci://registry-1.docker.io/therinn/kleidia-services --version 1.0.0 \
  --namespace kleidia --set global.domain=$DOMAIN --set global.namespace=kleidia --set global.siteUrl=https://$DOMAIN
```

> **Single-node clusters:** append `--set backend.replicas=1 --set frontend.replicas=1 --set licenseService.replicas=1` to the services install so the second replicas don't sit `Pending`.

After install, create the admin account via the web UI (the bootstrap flow at `https://$DOMAIN`).

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

