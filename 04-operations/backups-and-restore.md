# Backups and Restore

**Audience**: Operations Administrators  
**Prerequisites**: Kleidia deployed  
**Outcome**: Understand backup and restore procedures

## Overview

Kleidia provides a built-in backup and restore system accessible through the Admin Portal. Backups are:

- **Encrypted**: AES-256-GCM encryption with password-based key derivation (Argon2id)
- **Complete**: Includes PostgreSQL database and OpenBao secrets
- **Stored in S3**: Any S3-compatible storage (AWS S3, MinIO, etc.)
- **Audited**: All backup and restore operations are logged

### What Gets Backed Up

| Component | Contents |
|-----------|----------|
| **PostgreSQL Database** | Users, organizations, YubiKey records, certificates, audit logs |
| **OpenBao Secrets** | JWT secrets, PIV credentials, S3 credentials, certificate keys |

> **Note**: Audit logs can be excluded from backups to reduce file size (configurable in settings).

## Backup Configuration

### Accessing Backup Settings

1. Log in to Kleidia Admin Portal
2. Navigate to **Settings** → **Backup Management**
3. Select the **Settings** tab

### S3 Storage Configuration

Configure your S3-compatible storage:

| Field | Description | Example |
|-------|-------------|---------|
| **S3 Endpoint** | Storage service URL | `https://s3.amazonaws.com` or `http://minio.local:9000` |
| **Region** | S3 region | `us-east-1`, `eu-west-1` |
| **Bucket** | Bucket name | `kleidia-backups` |
| **Prefix** | Object key prefix | `backups/` |
| **Access Key ID** | S3 access key | Your access key |
| **Secret Access Key** | S3 secret key | Your secret key |
| **Use Path-Style** | Enable for MinIO/non-AWS | ✓ for MinIO |
| **Insecure TLS** | Skip certificate verification | Only for testing |

### Encryption Password

**Important**: Set a strong encryption password and store it securely.

- Backups are encrypted with AES-256-GCM
- Password is used to derive the encryption key using Argon2id
- **You will need this password to restore backups**
- Password is stored securely in OpenBao (not in database)

### Backup Schedule

Configure automatic backups:

| Field | Description | Default |
|-------|-------------|---------|
| **Schedule** | Cron expression | `0 2 * * *` (daily at 2 AM) |
| **Retention Days** | Auto-delete after N days | 30 |
| **Include Audit Logs** | Include audit logs in backup | Enabled |

### Testing the Connection

Click **Test S3 Connection** to verify your configuration before saving.

## Running Backups

### Manual Backup

1. Navigate to **Backup Management** → **History** tab
2. Click **Run Backup Now**
3. Select backup type:
   - **Full**: Database + OpenBao secrets (recommended)
   - **Database Only**: PostgreSQL data only
   - **Vault Only**: OpenBao secrets only
4. Monitor progress in the job list

### Scheduled Backups

Scheduled backups run automatically according to the configured cron schedule. Check the **History** tab to verify scheduled backups are completing successfully.

### Backup Status

| Status | Description |
|--------|-------------|
| **Pending** | Job created, waiting to start |
| **Running** | Backup in progress |
| **Completed** | Backup successful |
| **Failed** | Backup failed (check error message) |

## Restoring from Backup

### Before You Restore

> ⚠️ **Warning**: Restore operations overwrite existing data. This cannot be undone.

1. Ensure you have the backup encryption password
2. Consider backing up current state first
3. Notify users of potential service interruption

### Restore Procedure

1. Navigate to **Backup Management** → **Restore** tab
2. Locate the backup you want to restore from
3. Click **Restore** next to the backup
4. Enter the encryption password
5. Click **Validate Password** to verify
6. Click **Restore Now** to start the restore

### Restore Progress

Monitor the restore operation in the **History** tab. The restore process:

1. Downloads and decrypts the backup from S3
2. Restores PostgreSQL database (using UPSERT for existing records)
3. Restores OpenBao secrets
4. Logs completion status to audit log

### After Restore

1. Verify the restore completed successfully in the History tab
2. Test application functionality
3. Check that users and data are accessible

## Backup File Format

Backup files are stored as encrypted archives:

```
backups/backup-full-20251222-143000.enc
```

The encrypted archive contains:
- `header.json`: Metadata (version, salt, timestamp, checksum)
- `db-backup.sql.gz`: Compressed PostgreSQL dump
- `vault-secrets.json.gz`: Compressed OpenBao KV export

## Performance

Backup and restore times depend on data volume:

| Scale | Backup Time | Restore Time |
|-------|-------------|--------------|
| 1,000 keys | ~15-20 sec | ~20-30 sec |
| 10,000 keys | ~1-2 min | ~2-3 min |
| 50,000 keys | ~5-7 min | ~7-10 min |

Backups use parallel processing (20 concurrent workers) for OpenBao secret export.

## Audit Logging

All backup and restore operations are recorded in the audit log:

| Action | Description |
|--------|-------------|
| `backup.started` | Manual backup initiated |
| `backup.completed` | Backup finished successfully |
| `backup.failed` | Backup failed with error |
| `restore.started` | Restore initiated |
| `restore.completed` | Restore finished successfully |
| `restore.failed` | Restore failed with error |

Audit entries include:
- User who initiated the operation
- Workstation hostname and IP address
- Backup file name and type
- Duration and file size (for completed backups)

## Disaster Recovery

### Scenario: Corrupted System Storage

If the existing system's storage is corrupted but OpenBao is still sealed with known unseal keys:

1. Restore the PostgreSQL database from backup
2. Restore OpenBao secrets from backup
3. Verify system functionality

### Scenario: Fresh Installation

If restoring to a completely new installation:

1. Deploy Kleidia using Helm charts
2. Complete initial setup (create admin user)
3. Configure S3 backup settings with original storage location
4. Navigate to Restore tab
5. Select the backup and enter encryption password
6. Restore data

> **Important**: The new installation will have different OpenBao unseal keys. The backup restores the *secrets* (KV data), not the OpenBao encryption keys.

## Best Practices

- ✅ **Set a strong encryption password** and store it in a secure password manager
- ✅ **Test restore procedures** regularly (at least quarterly)
- ✅ **Monitor backup completion** in the History tab
- ✅ **Keep retention period appropriate** (30 days minimum recommended)
- ✅ **Use separate S3 buckets** for production and test environments
- ✅ **Enable audit logs in backups** unless storage is a concern
- ✅ **Document your S3 credentials** in secure storage for disaster recovery

## Troubleshooting

### Backup Fails with S3 Connection Error

1. Verify S3 endpoint URL is correct
2. Check Access Key ID and Secret Access Key
3. Enable "Use Path-Style" for MinIO or non-AWS S3
4. Test connectivity with **Test S3 Connection** button

### Restore Fails with Invalid Password

The encryption password must match exactly what was used when the backup was created. Passwords are case-sensitive.

### Backup Job Stuck in "Running"

If a backup job remains in "Running" status for more than 2 hours:

1. Check backend pod logs for errors
2. The system automatically marks stale jobs as failed on restart
3. Try running a new backup

### No Backups Visible in Restore Tab

1. Verify S3 configuration is saved correctly
2. Check that backup files exist in S3 (use S3 browser or CLI)
3. Verify the prefix matches the location of backup files

## Manual Backup (Advanced)

For environments without S3 access or for additional backup methods:

### Database Backup

```bash
# Create backup
kubectl exec -i kleidia-data-postgres-cluster-0 -n kleidia -- \
  pg_dumpall -U yubiuser > database-backup.sql

# Compress
gzip database-backup.sql
```

### OpenBao Snapshot

```bash
# Create snapshot (requires root token)
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
  vault operator raft snapshot save /tmp/vault-backup.snap

# Copy locally
kubectl cp kleidia-platform-openbao-0:/tmp/vault-backup.snap \
  vault-backup.snap -n kleidia
```

> **Note**: OpenBao raft snapshots include the master key encryption layer and can only be restored to the same OpenBao instance or one initialized with the same unseal keys.

## Related Documentation

- [Daily Operations](daily-operations.md)
- [Monitoring and Logs](monitoring-and-logs.md)
- [Runbooks](runbooks.md)
