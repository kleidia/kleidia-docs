# Storage Configuration

**Audience**: Operations Administrators  
**Prerequisites**: Kubernetes cluster, understanding of PersistentVolumes  
**Outcome**: Configure persistent storage for Kleidia deployment

## Overview

Kleidia requires persistent storage for:

- **OpenBao (Vault)**: Secrets, PKI certificates, and configuration data
- **OpenBao Audit Logs**: Security audit trail
- **PostgreSQL**: Application database

All components use Kubernetes PersistentVolumeClaims (PVCs) that require a StorageClass.

## Storage Requirements

| Component | Default Size | Access Mode | Notes |
|-----------|-------------|-------------|-------|
| OpenBao Data | 10Gi | ReadWriteOnce | Secrets and PKI data |
| OpenBao Audit | 10Gi | ReadWriteOnce | Audit logs (required for compliance) |
| PostgreSQL | 10Gi | ReadWriteOnce | Application database |

**Minimum Total**: 30Gi of persistent storage

## Storage Options

### Option 1: Local Path Provisioner (Development/Single-Node)

Best for:
- Development environments
- Single-node clusters
- Testing deployments

The Kleidia platform chart includes an embedded local-path-provisioner that can be enabled.

**Configuration**:

```yaml
# kleidia-platform values
storage:
  className: "local-path"
  localPath:
    enabled: true
    path: /opt/local-path-provisioner
```

**Installation**:

```bash
# Ensure the storage directory exists on the node
sudo mkdir -p /opt/local-path-provisioner

# Install with local-path-provisioner enabled
helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set storage.className=local-path \
  --set storage.localPath.enabled=true \
  --set openbao.server.dataStorage.storageClass=local-path \
  --set openbao.server.auditStorage.storageClass=local-path

# Install data layer with matching storage class
helm install kleidia-data ./helm/kleidia-data \
  --namespace kleidia \
  --set storage.className=local-path
```

**Limitations**:
- Data is stored on a single node
- No high availability
- Data loss if node fails
- Not suitable for production

### Option 2: Existing Cluster StorageClass (Production)

Best for:
- Production environments
- Multi-node clusters
- High availability requirements

Use your cluster's existing StorageClass (NFS, Longhorn, Rook-Ceph, cloud provider, etc.).

**Common StorageClass Names**:

| Provider/Solution | StorageClass Name |
|-------------------|-------------------|
| NFS Subdir External Provisioner | `nfs-client` |
| Longhorn | `longhorn` |
| Rook-Ceph | `rook-ceph-block` |
| AWS EBS | `gp2`, `gp3` |
| Azure Disk | `managed-premium`, `managed-standard` |
| GCP Persistent Disk | `standard`, `premium-rwo` |
| VMware vSphere | `vsphere-volume` |

**Check Available StorageClasses**:

```bash
kubectl get storageclass
```

**Installation with Existing StorageClass**:

```bash
# Example with NFS client
helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set storage.className=nfs-client \
  --set storage.localPath.enabled=false \
  --set openbao.server.dataStorage.storageClass=nfs-client \
  --set openbao.server.auditStorage.storageClass=nfs-client

helm install kleidia-data ./helm/kleidia-data \
  --namespace kleidia \
  --set storage.className=nfs-client
```

### Option 3: Cluster Default StorageClass

If your cluster has a default StorageClass, you can omit the storageClass setting:

```bash
# Check for default StorageClass (marked with "(default)")
kubectl get storageclass

# Install without specifying storageClass
helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set storage.localPath.enabled=false \
  --set openbao.server.dataStorage.storageClass="" \
  --set openbao.server.auditStorage.storageClass=""
```

## Setting Up NFS Storage

For production deployments without cloud-provider storage, NFS is a common choice.

### Prerequisites

1. NFS server with exported share
2. NFS client packages on all nodes

### Install NFS Subdir External Provisioner

```bash
# Add Helm repository
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# Install NFS provisioner
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --set nfs.server=<NFS_SERVER_IP> \
  --set nfs.path=/exported/path \
  --set storageClass.name=nfs-client \
  --set storageClass.defaultClass=true
```

### Verify NFS StorageClass

```bash
# Check StorageClass is created
kubectl get storageclass nfs-client

# Test with a sample PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

# Verify PVC is bound
kubectl get pvc test-nfs-pvc

# Clean up test
kubectl delete pvc test-nfs-pvc
```

## Setting Up Longhorn Storage

Longhorn provides distributed block storage for Kubernetes.

### Install Longhorn

```bash
# Add Helm repository
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Install Longhorn
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set defaultSettings.defaultDataPath=/var/lib/longhorn

# Wait for Longhorn to be ready
kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer
```

### Use Longhorn with Kleidia

```bash
helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set storage.className=longhorn \
  --set storage.localPath.enabled=false \
  --set openbao.server.dataStorage.storageClass=longhorn \
  --set openbao.server.auditStorage.storageClass=longhorn
```

## Verification

### Check PVCs After Installation

```bash
# List all PVCs in kleidia namespace
kubectl get pvc -n kleidia

# Expected output:
# NAME                               STATUS   VOLUME     CAPACITY   STORAGECLASS
# audit-kleidia-platform-openbao-0   Bound    pvc-xxx    10Gi       local-path
# data-kleidia-platform-openbao-0    Bound    pvc-xxx    10Gi       local-path
# postgres-data-postgres-0           Bound    pvc-xxx    10Gi       local-path
```

### Verify Storage is Working

```bash
# Check OpenBao can write to storage
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
  ls -la /openbao/data

# Check PostgreSQL data directory
kubectl exec -it postgres-0 -n kleidia -- \
  ls -la /var/lib/postgresql/data
```

## Troubleshooting

### PVC Stuck in Pending

```bash
# Check PVC status
kubectl describe pvc <pvc-name> -n kleidia

# Common causes:
# - StorageClass doesn't exist
# - No available PersistentVolumes
# - Insufficient storage capacity
# - Node selector constraints
```

### StorageClass Not Found

```bash
# List available StorageClasses
kubectl get storageclass

# If using local-path-provisioner, check it's deployed
kubectl get pods -n kube-system | grep local-path

# Check provisioner logs
kubectl logs -n kube-system -l app=local-path-provisioner
```

### Pod Stuck in Pending Due to Volume

```bash
# Check pod events
kubectl describe pod <pod-name> -n kleidia | grep -A 10 Events

# Look for:
# - "pod has unbound immediate PersistentVolumeClaims"
# - "no persistent volumes available"
```

## Storage Sizing Guidelines

### Small Deployment (< 100 YubiKeys)

```yaml
openbao:
  server:
    dataStorage:
      size: 5Gi
    auditStorage:
      size: 5Gi

postgres:
  storage:
    size: 5Gi
```

### Medium Deployment (100-1000 YubiKeys)

```yaml
openbao:
  server:
    dataStorage:
      size: 10Gi
    auditStorage:
      size: 10Gi

postgres:
  storage:
    size: 20Gi
```

### Large Deployment (> 1000 YubiKeys)

```yaml
openbao:
  server:
    dataStorage:
      size: 20Gi
    auditStorage:
      size: 50Gi  # More audit logs

postgres:
  storage:
    size: 50Gi
```

## Best Practices

1. **Production**: Always use a production-grade StorageClass (NFS, Longhorn, cloud provider)
2. **Backups**: Implement regular backups regardless of storage type
3. **Monitoring**: Monitor storage usage and set alerts for capacity
4. **Testing**: Test storage failover in non-production before production deployment
5. **Documentation**: Document your storage configuration for disaster recovery

## Related Documentation

- [Helm Installation](helm-install.md)
- [Prerequisites](prerequisites.md)
- [Backups and Restore](../04-operations/backups-and-restore.md)

