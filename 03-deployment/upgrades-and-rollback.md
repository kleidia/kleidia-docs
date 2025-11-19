# Upgrades and Rollback

**Audience**: Operations Administrators  
**Prerequisites**: Helm installed, existing Kleidia deployment  
**Outcome**: Safely upgrade and rollback Kleidia deployments

## Overview

Kleidia supports zero-downtime upgrades using Helm's rolling update capabilities. This guide covers upgrade procedures, rollback procedures, and best practices.

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
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  pg_dumpall -U yubiuser > backup-$(date +%Y%m%d).sql

# Backup Vault
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
  vault operator raft snapshot save /tmp/vault-backup.snap

kubectl cp kleidia-platform-openbao-0:/tmp/vault-backup.snap \
  ./vault-backup-$(date +%Y%m%d).snap -n kleidia

# Save current Helm values
helm get values kleidia-platform -n kleidia > platform-values-$(date +%Y%m%d).yaml
helm get values kleidia-data -n kleidia > data-values-$(date +%Y%m%d).yaml
helm get values kleidia-services -n kleidia > services-values-$(date +%Y%m%d).yaml
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
helm upgrade kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --values platform-values.yaml

# Wait for upgrade to complete
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openbao -n kleidia --timeout=300s

# Verify OpenBao status
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status
```

### 4. Upgrade Data Layer (PostgreSQL)

```bash
# Upgrade data chart
helm upgrade kleidia-data ./helm/kleidia-data \
  --namespace kleidia \
  --values data-values.yaml

# Wait for upgrade
kubectl wait --for=condition=ready pod -l app=postgres-cluster -n kleidia --timeout=300s

# Verify database
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT version();"
```

### 5. Upgrade Services (Backend, Frontend)

```bash
# Upgrade services chart
helm upgrade kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --values services-values.yaml

# Wait for rollout
kubectl rollout status deployment/kleidia-services-backend -n kleidia
kubectl rollout status deployment/kleidia-services-frontend -n kleidia

# Verify services
curl https://kleidia.example.com/api/health
```

## Rollback Procedures

### Rollback Services

```bash
# List revisions
helm history kleidia-services -n kleidia

# Rollback to previous revision
helm rollback kleidia-services -n kleidia

# Rollback to specific revision
helm rollback kleidia-services 2 -n kleidia
```

### Rollback Platform

```bash
# Rollback platform
helm rollback kleidia-platform -n kleidia

# Verify OpenBao
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status
```

### Rollback Data Layer

**⚠️ WARNING**: Rolling back data layer may cause data inconsistencies. Only rollback if absolutely necessary.

```bash
# Rollback data layer
helm rollback kleidia-data -n kleidia

# Verify database
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT version();"
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
helm install kleidia-services-v2 ./helm/kleidia-services \
  --namespace kleidia \
  --set backend.service.nodePort=32571 \
  --set frontend.service.nodePort=30806

# Test new version
curl http://localhost:32571/api/health

# Switch load balancer to new ports
# Update load balancer configuration to point to new NodePorts

# Remove old version after verification
helm uninstall kleidia-services -n kleidia
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
kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i migrate

# Run migrations manually (if needed)
kubectl exec -it deployment/kleidia-services-backend -n kleidia -- \
  /app/kleidia-backend migrate
```

## Version Compatibility

### Check Current Versions

```bash
# Check Helm chart versions
helm list -n kleidia

# Check application versions
curl https://kleidia.example.com/api/health | jq .version

# Check database version
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT version();"
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
kubectl get pods -n kleidia

# Check pod logs
kubectl logs -f <pod-name> -n kleidia

# Check events
kubectl get events -n kleidia --sort-by=.metadata.creationTimestamp
```

### Image Pull Errors

```bash
# Check image availability
kubectl describe pod <pod-name> -n kleidia | grep -i image

# Verify image pull configuration
kubectl get pod <pod-name> -n kleidia -o jsonpath='{.spec.containers[*].image}'
```

### Database Migration Failures

```bash
# Check migration logs
kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i migration

# Check database connection
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "\dt"
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

