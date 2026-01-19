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
- **Atomic**: Restore operations run in a single transaction

### What Gets Backed Up

| Component | Contents |
|-----------|----------|
| **PostgreSQL Database** | Users, organizations, YubiKey records, certificates, audit logs |
| **OpenBao Secrets** | JWT secrets, database credentials, S3 credentials, YubiKey PIV credentials, certificate private keys |

### What Is NOT Backed Up

| Component | Reason |
|-----------|--------|
| **Backup Jobs Table** | Preserved during restore to maintain job history |
| **OpenBao Unseal Keys** | Not stored in KV; required to access OpenBao |
| **OpenBao Root Token** | Regenerated on each unseal |

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
3. The backup starts immediately (full backup of database + OpenBao secrets)
4. Monitor progress in the job list

> **Note**: All backups are full backups containing both PostgreSQL database and OpenBao secrets. Partial backup types (database-only or vault-only) are only available via the API.

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
2. Validates checksum and decryption
3. Restores PostgreSQL database:
   - Temporarily disables foreign key constraints
   - Runs pg_dump restore (DROP + CREATE statements)
   - Re-enables foreign key constraints
   - Runs as a single atomic transaction
4. Restores OpenBao secrets using parallel workers (20 concurrent)
5. Logs completion status to audit log

### Technical Details: Database Restore

The restore process uses PostgreSQL's `session_replication_role` to handle foreign key constraints:

```sql
-- Disable FK constraint checking during restore
SET session_replication_role = 'replica';

-- pg_dump restore statements (DROP TABLE, CREATE TABLE, COPY data)
...

-- Re-enable FK constraint checking
SET session_replication_role = 'origin';
```

This approach:
- Allows tables to be dropped even when referenced by foreign keys
- Runs the entire restore as a single transaction (`-1` flag)
- Rolls back completely if any error occurs

### After Restore

1. Verify the restore completed successfully in the History tab
2. Test application functionality
3. Check that users and data are accessible
4. **Restart backend pods** if you experience session issues (JWT secret may have changed)

## Backup File Format

Backup files are stored as encrypted archives:

```
backups/backup-full-20251222-143000.enc
```

### File Structure

The encrypted backup file uses a custom binary format:

```
┌─────────────────────────────────────────────────────────┐
│ Magic Bytes (17 bytes): "KLEIDIA_BACKUP_V1"            │
├─────────────────────────────────────────────────────────┤
│ Header Length (4 bytes, big-endian uint32)             │
├─────────────────────────────────────────────────────────┤
│ Header (JSON): version, created_at, backup_type,       │
│   checksum, includes_db, includes_kv, includes_audit   │
├─────────────────────────────────────────────────────────┤
│ Salt (32 bytes): Random salt for Argon2id              │
├─────────────────────────────────────────────────────────┤
│ Nonce (12 bytes): Random nonce for AES-GCM             │
├─────────────────────────────────────────────────────────┤
│ Ciphertext: AES-256-GCM encrypted, gzip-compressed     │
│   JSON containing database SQL and vault secrets       │
└─────────────────────────────────────────────────────────┘
```

### Encryption Details

| Parameter | Value |
|-----------|-------|
| **Key Derivation** | Argon2id |
| **Argon2 Time** | 3 iterations |
| **Argon2 Memory** | 64 MB |
| **Argon2 Parallelism** | 4 threads |
| **Encryption** | AES-256-GCM |
| **Key Length** | 256 bits (32 bytes) |
| **Nonce Length** | 96 bits (12 bytes) |
| **Salt Length** | 256 bits (32 bytes) |
| **Integrity** | SHA-256 checksum of ciphertext |

### Archive Contents

The decrypted, decompressed payload is a JSON object:

```json
{
  "header": {
    "version": 1,
    "created_at": "2026-01-17T12:00:00Z",
    "backup_type": "full",
    "includes_db": true,
    "includes_kv": true,
    "includes_audit_logs": true
  },
  "database_sql": "-- pg_dump output...",
  "vault_secrets": {
    "jwt-secret": {"secret": "..."},
    "database": {"password": "..."},
    "yubikeys/abc123/piv": {"management_key": "..."}
  }
}
```

## Performance

Backup and restore times depend on data volume:

| Scale | Backup Time | Restore Time |
|-------|-------------|--------------|
| 1,000 keys | ~15-20 sec | ~20-30 sec |
| 10,000 keys | ~1-2 min | ~2-3 min |
| 50,000 keys | ~5-7 min | ~7-10 min |

### Parallel Processing

Both backup and restore use parallel workers for OpenBao operations:

| Parameter | Value |
|-----------|-------|
| **Concurrent Workers** | 20 |
| **Operation Timeout** | 30 minutes per S3 operation |
| **Job Timeout** | 2 hours maximum |
| **Stale Job Detection** | Jobs running >2 hours marked as failed |

### Timeouts and Limits

| Setting | Value |
|---------|-------|
| **Presigned URL Expiry** | 1 hour |
| **Default Retention** | 30 days |
| **Max Backups Listed** | 1,000 |
| **Default Page Size** | 50 backups |

## Audit Logging

All backup and restore operations are recorded in the audit log:

| Action | Description |
|--------|-------------|
| `backup.completed` | Backup finished successfully |
| `backup.failed` | Backup failed with error |
| `restore.completed` | Restore finished successfully |
| `restore.failed` | Restore failed with error |

Audit entries include:
- User who initiated the operation (or "system" for scheduled backups)
- Workstation hostname and IP address
- Backup file name and type
- Duration and file size (for completed backups)

### Scheduled Backup Audit Entries

Scheduled backups appear with:
- **IP Address**: `system`
- **Details**: Prefixed with `[Scheduled]`
- **Triggered By**: `null` (no user ID)

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

### Restore Fails with Foreign Key Constraint Error

If restore fails with errors like `cannot drop constraint X because other objects depend on it`:

1. Ensure you're running the latest backend version
2. The backend automatically disables FK constraints during restore
3. Check backend logs for the specific error

### Backup Job Stuck in "Running"

If a backup job remains in "Running" status for more than 2 hours:

1. Check backend pod logs for errors
2. The system automatically marks stale jobs as failed on restart
3. Try running a new backup

```bash
# Check for stale jobs
kubectl logs -l app=backend -n kleidia | grep -i "stale"

# Force cleanup by restarting backend
kubectl rollout restart deployment/backend -n kleidia
```

### No Backups Visible in Restore Tab

1. Verify S3 configuration is saved correctly
2. Check that backup files exist in S3 (use S3 browser or CLI)
3. Verify the prefix matches the location of backup files

### OpenBao Secrets Partially Restored

If vault restore reports partial failures:

- **<50% failure rate**: Restore succeeds with warnings
- **>50% failure rate**: Restore fails
- **100% failure rate**: Restore fails

Check backend logs for specific paths that failed:

```bash
kubectl logs -l app=backend -n kleidia | grep -i "failed to write"
```

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

## API Reference

The backup system exposes the following REST API endpoints:

### Backup Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/backup/trigger` | Trigger a manual backup |
| `GET` | `/api/backup/list` | List available backups |
| `DELETE` | `/api/backup/{key}` | Delete a specific backup |
| `GET` | `/api/backup/test-connection` | Test S3 connectivity |

### Restore Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/backup/restore` | Initiate a restore |
| `POST` | `/api/backup/restore/validate-password` | Validate restore password |
| `GET` | `/api/backup/restore/status` | Get current restore status |

### Job Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/backup/jobs` | List backup/restore jobs |
| `GET` | `/api/backup/jobs/{id}` | Get specific job details |
| `GET` | `/api/backup/jobs/running` | Get currently running jobs |

### Example: Trigger Backup via API

```bash
curl -X POST https://kleidia.example.com/api/backup/trigger \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "full"}'
```

### Example: List Backups

```bash
curl -X GET "https://kleidia.example.com/api/backup/list?limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

## Related Documentation

- [Daily Operations](daily-operations.md)
- [Monitoring and Logs](monitoring-and-logs.md)
- [Runbooks](runbooks.md)
