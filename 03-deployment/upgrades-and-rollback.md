# Upgrades and Rollback

**Audience**: Operations Administrators  
**Prerequisites**: Helm installed, existing YubiMgr deployment  
**Outcome**: Safely upgrade and rollback YubiMgr deployments

## Overview

YubiMgr supports zero-downtime upgrades using Helm's rolling update capabilities. This guide covers upgrade procedures, rollback procedures, and best practices.

## Pre-Upgrade Checklist

Before upgrading:

- [ ] Review release notes and changelog
- [ ] Backup database and Vault data
- [ ] Test upgrade in development environment
- [ ] Verify current deployment version
- [ ] Check resource availability
- [ ] Review breaking changes

## Upgrade Procedures

### 1. Backup Current State

```bash
# Backup database
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  pg_dumpall -U yubiuser > backup-$(date +%Y%m%d).sql

# Backup Vault
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
  vault operator raft snapshot save /tmp/vault-backup.snap

kubectl cp yubimgr-platform-openbao-0:/tmp/vault-backup.snap \
  ./vault-backup-$(date +%Y%m%d).snap -n yubimgr

# Save current Helm values
helm get values yubimgr-platform -n yubimgr > platform-values-$(date +%Y%m%d).yaml
helm get values yubimgr-data -n yubimgr > data-values-$(date +%Y%m%d).yaml
helm get values yubimgr-services -n yubimgr > services-values-$(date +%Y%m%d).yaml
```

### 2. Update Helm Charts

```bash
# Pull latest charts
git pull origin main

# Or update specific charts
helm repo update
```

### 3. Upgrade Platform (OpenBao)

```bash
# Upgrade platform chart
helm upgrade yubimgr-platform ./helm/yubimgr-platform \
  --namespace yubimgr \
  --values platform-values.yaml

# Wait for upgrade to complete
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openbao -n yubimgr --timeout=300s

# Verify OpenBao status
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault status
```

### 4. Upgrade Data Layer (PostgreSQL)

```bash
# Upgrade data chart
helm upgrade yubimgr-data ./helm/yubimgr-data \
  --namespace yubimgr \
  --values data-values.yaml

# Wait for upgrade
kubectl wait --for=condition=ready pod -l app=postgres-cluster -n yubimgr --timeout=300s

# Verify database
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "SELECT version();"
```

### 5. Upgrade Services (Backend, Frontend)

```bash
# Upgrade services chart
helm upgrade yubimgr-services ./helm/yubimgr-services \
  --namespace yubimgr \
  --values services-values.yaml

# Wait for rollout
kubectl rollout status deployment/yubimgr-services-backend -n yubimgr
kubectl rollout status deployment/yubimgr-services-frontend -n yubimgr

# Verify services
curl https://yubimgr.example.com/api/health
```

## Rollback Procedures

### Rollback Services

```bash
# List revisions
helm history yubimgr-services -n yubimgr

# Rollback to previous revision
helm rollback yubimgr-services -n yubimgr

# Rollback to specific revision
helm rollback yubimgr-services 2 -n yubimgr
```

### Rollback Platform

```bash
# Rollback platform
helm rollback yubimgr-platform -n yubimgr

# Verify OpenBao
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault status
```

### Rollback Data Layer

**⚠️ WARNING**: Rolling back data layer may cause data inconsistencies. Only rollback if absolutely necessary.

```bash
# Rollback data layer
helm rollback yubimgr-data -n yubimgr

# Verify database
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "SELECT version();"
```

## Upgrade Strategies

### Rolling Update (Default)

Helm uses rolling updates by default:

- **Zero Downtime**: New pods start before old pods terminate
- **Gradual Migration**: Traffic gradually shifts to new pods
- **Automatic Rollback**: Kubernetes rolls back on health check failures

### Blue-Green Deployment (Manual)

For major upgrades:

```bash
# Deploy new version with different release name
helm install yubimgr-services-v2 ./helm/yubimgr-services \
  --namespace yubimgr \
  --set backend.service.nodePort=32571 \
  --set frontend.service.nodePort=30806

# Test new version
curl http://localhost:32571/api/health

# Switch load balancer to new ports
# Update load balancer configuration to point to new NodePorts

# Remove old version after verification
helm uninstall yubimgr-services -n yubimgr
```

## Database Migrations

### Automatic Migrations

Backend automatically runs migrations on startup:

- **GORM AutoMigrate**: Automatically creates/updates schema
- **Migration Safety**: Idempotent migrations (safe to rerun)
- **Backup Recommended**: Always backup before migrations

### Manual Migrations

```bash
# Check migration status
kubectl logs deployment/yubimgr-services-backend -n yubimgr | grep -i migrate

# Run migrations manually (if needed)
kubectl exec -it deployment/yubimgr-services-backend -n yubimgr -- \
  /app/yubimgr-backend migrate
```

## Version Compatibility

### Check Current Versions

```bash
# Check Helm chart versions
helm list -n yubimgr

# Check application versions
curl https://yubimgr.example.com/api/health | jq .version

# Check database version
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "SELECT version();"
```

### Compatibility Matrix

| Component | Min Version | Max Version | Notes |
|-----------|-------------|-------------|-------|
| Kubernetes | 1.24+ | Latest | Any compatible Kubernetes |
| Helm | 3.8+ | Latest | |
| PostgreSQL | 13+ | 15+ | |
| OpenBao | 2.4+ | Latest | |

## Troubleshooting Upgrades

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n yubimgr

# Check pod logs
kubectl logs -f <pod-name> -n yubimgr

# Check events
kubectl get events -n yubimgr --sort-by=.metadata.creationTimestamp
```

### Image Pull Errors

```bash
# Check image availability
kubectl describe pod <pod-name> -n yubimgr | grep -i image

# Verify image pull configuration
kubectl get pod <pod-name> -n yubimgr -o jsonpath='{.spec.containers[*].image}'
```

### Database Migration Failures

```bash
# Check migration logs
kubectl logs deployment/yubimgr-services-backend -n yubimgr | grep -i migration

# Check database connection
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "\dt"
```

## Best Practices

### Upgrade Planning

- ✅ Test upgrades in development first
- ✅ Schedule upgrades during maintenance windows
- ✅ Have rollback plan ready
- ✅ Communicate upgrades to users
- ✅ Monitor system after upgrade

### Backup Strategy

- ✅ Backup before every upgrade
- ✅ Test backup restoration
- ✅ Keep multiple backup versions
- ✅ Store backups securely

### Monitoring

- ✅ Monitor pod health during upgrade
- ✅ Check application logs
- ✅ Verify API endpoints
- ✅ Monitor resource usage
- ✅ Check error rates

## Related Documentation

- [Helm Installation](helm-install.md)
- [Configuration](configuration.md)
- [Troubleshooting](troubleshooting.md)
- [Backups and Restore](../04-operations/backups-and-restore.md)

