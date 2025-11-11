# Backups and Restore

**Audience**: Operations Administrators  
**Prerequisites**: YubiMgr deployed  
**Outcome**: Understand backup and restore procedures

## Overview

Regular backups are essential for disaster recovery and data protection. YubiMgr requires backups of:

1. **PostgreSQL Database**: User data, device records, audit logs
2. **OpenBao**: Secrets and PKI certificates
3. **Configuration**: Helm values

## Backup Strategy

### Backup Frequency

- **Database**: Daily backups (recommended)
- **Vault**: Daily backups (recommended)
- **Configuration**: On configuration changes
- **Full System**: Weekly full backups

### Backup Retention

- **Daily Backups**: Keep 7 days
- **Weekly Backups**: Keep 4 weeks
- **Monthly Backups**: Keep 12 months

## Database Backups

### Automated Backup

Set up cron job for automated backups:

```bash
# Create backup script
sudo nano /usr/local/bin/yubimgr-backup-db.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/backups/yubimgr"
DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR

# Backup database
kubectl exec -i yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  pg_dumpall -U yubiuser > $BACKUP_DIR/db-backup-$DATE.sql

# Compress backup
gzip $BACKUP_DIR/db-backup-$DATE.sql

# Remove backups older than 7 days
find $BACKUP_DIR -name "db-backup-*.sql.gz" -mtime +7 -delete

echo "Database backup completed: $BACKUP_DIR/db-backup-$DATE.sql.gz"
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/yubimgr-backup-db.sh

# Add to crontab (daily at 2 AM)
sudo crontab -e
# Add: 0 2 * * * /usr/local/bin/yubimgr-backup-db.sh
```

### Manual Backup

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup database
kubectl exec -i yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  pg_dumpall -U yubiuser > backups/$(date +%Y%m%d)/database.sql

# Compress
gzip backups/$(date +%Y%m%d)/database.sql
```

### Backup Verification

```bash
# Verify backup file exists
ls -lh backups/$(date +%Y%m%d)/database.sql.gz

# Test backup restoration (on test system)
gunzip -c backups/$(date +%Y%m%d)/database.sql.gz | \
  psql -U yubiuser -d yubimgr_test
```

## Vault Backups

### Automated Backup

```bash
# Create backup script
sudo nano /usr/local/bin/yubimgr-backup-vault.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/backups/yubimgr"
DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR

# Create Vault snapshot
kubectl exec -i yubimgr-platform-openbao-0 -n yubimgr -- \
  vault operator raft snapshot save /tmp/vault-backup.snap

# Copy snapshot locally
kubectl cp yubimgr-platform-openbao-0:/tmp/vault-backup.snap \
  $BACKUP_DIR/vault-backup-$DATE.snap -n yubimgr

# Remove backups older than 7 days
find $BACKUP_DIR -name "vault-backup-*.snap" -mtime +7 -delete

echo "Vault backup completed: $BACKUP_DIR/vault-backup-$DATE.snap"
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/yubimgr-backup-vault.sh

# Add to crontab (daily at 3 AM)
sudo crontab -e
# Add: 0 3 * * * /usr/local/bin/yubimgr-backup-vault.sh
```

### Manual Backup

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Create snapshot
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
  vault operator raft snapshot save /tmp/vault-backup.snap

# Copy snapshot
kubectl cp yubimgr-platform-openbao-0:/tmp/vault-backup.snap \
  backups/$(date +%Y%m%d)/vault-backup.snap -n yubimgr
```

## Configuration Backups

### Helm Values

```bash
# Backup Helm values
helm get values yubimgr-platform -n yubimgr > backups/$(date +%Y%m%d)/platform-values.yaml
helm get values yubimgr-data -n yubimgr > backups/$(date +%Y%m%d)/data-values.yaml
helm get values yubimgr-services -n yubimgr > backups/$(date +%Y%m%d)/services-values.yaml
```

## Configuration Backups

### Helm Values

```bash
# Backup Helm values
helm get values yubimgr-platform -n yubimgr > backups/$(date +%Y%m%d)/platform-values.yaml
helm get values yubimgr-data -n yubimgr > backups/$(date +%Y%m%d)/data-values.yaml
helm get values yubimgr-services -n yubimgr > backups/$(date +%Y%m%d)/services-values.yaml
```

### Database Restore

```bash
# Stop backend (to prevent data corruption)
kubectl scale deployment/yubimgr-services-backend --replicas=0 -n yubimgr

# Restore database
gunzip -c backups/20250115/database.sql.gz | \
  kubectl exec -i yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr

# Restart backend
kubectl scale deployment/yubimgr-services-backend --replicas=2 -n yubimgr

# Verify restoration
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "SELECT count(*) FROM users;"
```

### Vault Restore

```bash
# Stop backend (to prevent secret access issues)
kubectl scale deployment/yubimgr-services-backend --replicas=0 -n yubimgr

# Copy snapshot to pod
kubectl cp backups/20250115/vault-backup.snap \
  yubimgr-platform-openbao-0:/tmp/vault-backup.snap -n yubimgr

# Restore snapshot
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
  vault operator raft snapshot restore /tmp/vault-backup.snap

# Verify Vault
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault status

# Restart backend
kubectl scale deployment/yubimgr-services-backend --replicas=2 -n yubimgr
```

### Configuration Restore

```bash
# Restore Helm values
helm upgrade yubimgr-platform ./helm/yubimgr-platform \
  --namespace yubimgr \
  --values backups/20250115/platform-values.yaml

# Restore Helm values
helm upgrade yubimgr-platform -n yubimgr -f backups/20250115/platform-values.yaml ./helm/yubimgr-platform
helm upgrade yubimgr-data -n yubimgr -f backups/20250115/data-values.yaml ./helm/yubimgr-data
helm upgrade yubimgr-services -n yubimgr -f backups/20250115/services-values.yaml ./helm/yubimgr-services
```

## Disaster Recovery

### Complete System Restore

1. **Restore Infrastructure**
   ```bash
   # Restore Kubernetes cluster (if needed)
   # Restore persistent volumes
   ```

2. **Restore Database**
   ```bash
   # Restore PostgreSQL from backup
   ```

3. **Restore Vault**
   ```bash
   # Restore Vault from snapshot
   ```

4. **Restore Configuration**
   ```bash
   # Restore Helm values
   helm upgrade yubimgr-platform -n yubimgr -f backups/20250115/platform-values.yaml ./helm/yubimgr-platform
   helm upgrade yubimgr-data -n yubimgr -f backups/20250115/data-values.yaml ./helm/yubimgr-data
   helm upgrade yubimgr-services -n yubimgr -f backups/20250115/services-values.yaml ./helm/yubimgr-services
   ```

5. **Verify System**
   ```bash
   # Check all pods are running
   # Test application functionality
   # Verify data integrity
   ```

## Backup Storage

### Local Storage

- **Location**: `/backups/yubimgr/`
- **Retention**: 7 days local, longer-term archival
- **Security**: Encrypt backups containing sensitive data

### Remote Storage

Consider storing backups remotely:

- **Cloud Storage**: AWS S3, Azure Blob, Google Cloud Storage
- **Network Storage**: NFS, SMB shares
- **Backup Service**: Dedicated backup solutions

### Backup Encryption

Encrypt backups containing sensitive data:

```bash
# Encrypt database backup
gzip -c database.sql | \
  openssl enc -aes-256-cbc -salt -pbkdf2 -out database.sql.gz.enc

# Decrypt backup
openssl enc -d -aes-256-cbc -pbkdf2 -in database.sql.gz.enc | \
  gunzip > database.sql
```

## Best Practices

- ✅ Automate backups
- ✅ Test restore procedures regularly
- ✅ Store backups off-site
- ✅ Encrypt sensitive backups
- ✅ Verify backup integrity
- ✅ Document restore procedures
- ✅ Keep multiple backup versions
- ✅ Monitor backup completion

## Related Documentation

- [Daily Operations](daily-operations.md)
- [Monitoring and Logs](monitoring-and-logs.md)
- [Runbooks](runbooks.md)

