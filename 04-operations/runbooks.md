# Operational Runbooks

**Audience**: Operations Administrators  
**Prerequisites**: Kleidia deployed  
**Outcome**: Resolve common operational issues

## Runbook Overview

This document provides step-by-step procedures for common operational scenarios.

## Agent Pairing Issues

### Symptom
Users cannot pair agents with the system.

### Diagnosis

```bash
# Check agent is running
curl http://127.0.0.1:56123/health

# Check agent discovery
curl http://127.0.0.1:56123/.well-known/kleidia-agent

# Check backend logs
kubectl logs -f deployment/backend -n kleidia | grep -i agent
```

### Resolution

1. **Agent Not Running**
   ```bash
   # On user workstation
   # Start agent service
   sudo systemctl start kleidia-agent
   # Or run manually
   ./kleidia-agent
   ```

2. **Agent Not Detected**
   - Verify agent is running on localhost:56123
   - Check browser console for CORS errors
   - Verify user is logged in

3. **Key Registration Failed**
   ```bash
   # Check backend logs for registration errors
   kubectl logs -f deployment/backend -n kleidia | grep -i register
   
   # Check database for agent keys
   kubectl exec -it kleidia-db-1 -n kleidia -- \
     psql -U kleidiauser -d kleidia -c "SELECT * FROM user_sessions WHERE agent_pubkey IS NOT NULL;"
   ```

## Device Revocation

### Symptom
Device needs to be revoked (lost, stolen, compromised, or user departure).

### Procedure

1. **Via Admin UI**:
   - Navigate to Admin Panel → YubiKeys
   - Select device to revoke
   - Click "Revoke Device"
   - Review confirmation dialog (shows device serial, owner, warning)
   - Confirm revocation

2. **Verify Revocation**:
   ```bash
   # Check device status in database
   kubectl exec -it kleidia-db-1 -n kleidia -- \
     psql -U kleidiauser -d kleidia -c \
     "SELECT id, serial, is_active, deleted_at FROM yubikeys WHERE serial = '<serial-number>';"
   ```

3. **Verify Secrets Removed**:
   ```bash
   # Check Vault secrets (should be removed)
   kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
     bao kv list yubikeys/data/ | grep <serial-number>
   ```

4. **Verify Certificates Revoked**:
   ```bash
   # Check audit logs for certificate revocation
   kubectl logs -f deployment/backend -n kleidia | grep -i "revoke.*certificate"
   ```

### Automatic Wipe Behavior

**Important**: When a revoked device is connected to an admin workstation (where an agent is running), the system automatically attempts to wipe the PIV application. This ensures the device cannot be used even if physically recovered.

**To verify wipe attempt**:
- Check backend logs for PIV reset attempts
- Check agent logs (if available) for reset operations
- Verify device PIV status if device is accessible

### Troubleshooting

**Device Not Wiped Automatically**:
- Verify agent is running on admin workstation
- Check device is actually connected to admin workstation
- Review backend logs for PIV reset errors
- Manually reset PIV if needed (via agent or ykman CLI)

**Revocation Failed**:
- Check backend logs for errors
- Verify database connectivity
- Verify Vault connectivity
- Check user permissions (admin role required)

## Revoking Certificates Left Valid Before 2.4.2

### Symptom
Up to and including 2.4.1, revoking or deleting a YubiKey did not revoke its
certificates in the PKI. Those certificates stay valid, and absent from the CRL,
until they expire. 2.4.2 revokes going forward but does not revoke past ones.

Two cases are affected:
- certificates of YubiKeys that were revoked (lost key) or deleted;
- certificates still attached to a YubiKey that was deleted and then registered
  again to a **different** owner.

### Procedure

Run this once, **after** upgrading to 2.4.2. External Vault/OpenBao: the Kleidia
policy must include `update` on `<pkiMount>/revoke` (see
[External Vault](../03-deployment/external-vault.md)), or use your own token.

1. **List the affected certificates.** The query prints `id|serial`, with the
   serial already in the colon-hex form `pki/revoke` expects:
   ```bash
   PRIMARY=$(kubectl -n kleidia get pod -l cnpg.io/cluster=kleidia-db,cnpg.io/instanceRole=primary -o name)
   kubectl -n kleidia exec -i "$PRIMARY" -c postgres -- psql -d kleidia -At > historic-certs.txt <<'EOF'
   WITH RECURSIVE affected AS (
     SELECT c.id, c.serial_number::numeric AS n
     FROM issued_certificates c
     JOIN yubi_keys y ON y.id = c.yubikey_id
     WHERE c.serial_number ~ '^[0-9]+$'
       AND c.not_after > now()
       AND (y.deleted_at IS NOT NULL OR c.owner_user_id IS DISTINCT FROM y.owner_id)
   ), hex(id, n, h) AS (
     SELECT id, n, ''::text FROM affected
     UNION ALL
     SELECT id, div(n, 16), substr('0123456789abcdef', mod(n, 16)::int + 1, 1) || h
     FROM hex WHERE n > 0
   )
   SELECT id, regexp_replace(lpad(h, length(h) + length(h) % 2, '0'), '(..)(?!$)', '\1:', 'g')
   FROM hex WHERE n = 0 AND h <> '' ORDER BY id;
   EOF
   cat historic-certs.txt
   ```
   Review the list before continuing. To see what each row is, run
   `SELECT c.id, c.subject, c.not_after, y.serial FROM issued_certificates c JOIN yubi_keys y ON y.id = c.yubikey_id WHERE c.id IN (...)`.

2. **Revoke them.** Bundled OpenBao, using the backend's AppRole (which has the
   revoke permission from 2.4.2). The credentials and serials travel on stdin,
   so they never appear in a command line or the Kubernetes audit log; the
   script logs in once and revokes its own token at the end:
   ```bash
   { kubectl -n kleidia get secret openbao-backend-approle \
       -o jsonpath='{.data.role_id} {.data.secret_id}{"\n"}'
     cat historic-certs.txt; } |
   kubectl -n kleidia exec -i kleidia-platform-openbao-0 -- sh -c '
     read -r rid sid
     rid=$(echo "$rid" | base64 -d); sid=$(echo "$sid" | base64 -d)
     BAO_TOKEN=$(echo "{\"role_id\":\"$rid\",\"secret_id\":\"$sid\"}" |
       bao write -field=token auth/approle/login -) || exit 1
     export BAO_TOKEN
     while IFS="|" read -r id serial; do
       if bao write pki/revoke serial_number="$serial" </dev/null >/dev/null; then
         echo "$id"; echo "revoked row $id serial $serial" >&2
       fi
     done
     bao token revoke -self </dev/null >/dev/null
   ' > revoked-ids.txt
   ```
   `revoked-ids.txt` receives only the rows whose revoke succeeded; failures
   print OpenBao's error. External Vault: run
   `vault write <pkiMount>/revoke serial_number=<serial>` for each line with a
   token allowed to revoke, and put the ids that succeeded in
   `revoked-ids.txt`. A serial reported as "not found" was issued by a
   different CA or mount and cannot be revoked here; delete its row by id if
   you no longer want it tracked.

3. **Stop tracking the revoked certificates** (removes them from expiry
   notifications), using only the rows that revoked successfully:
   ```bash
   kubectl -n kleidia exec "$PRIMARY" -c postgres -- psql -d kleidia -c \
     "DELETE FROM issued_certificates WHERE id IN ($(paste -sd, revoked-ids.txt))"
   ```

4. **Publish the CRL.** OpenBao's CRL updates immediately; Kleidia's public
   CRL endpoint (`/api/pki/crl`, the URL in the certificates) caches it for up
   to an hour. To publish now:
   ```bash
   kubectl -n kleidia rollout restart deployment/backend
   ```

5. **Verify.** Re-running step 1 prints nothing, and each revoked serial
   (upper-case, without colons) appears in
   `curl -s https://<your-domain>/api/pki/crl | openssl crl -inform DER -noout -text`.

## Auditing Local Accounts After 2.4.2

### Symptom
Up to 2.4.1, self-registration was open by default and never verified that the
registrant owns the email address. That email becomes the email SAN of the
account's PIV certificates, and a later OIDC login with the same email is
merged into the existing account, which keeps its local password. A squatted
account therefore survives the upgrade and passes a "SAN equals the owner's
email" review.

### Procedure

1. **List local accounts that have a password** (IdP-synced and OIDC-created
   users have none):
   ```bash
   PRIMARY=$(kubectl -n kleidia get pod -l cnpg.io/cluster=kleidia-db,cnpg.io/instanceRole=primary -o name)
   kubectl -n kleidia exec "$PRIMARY" -c postgres -- psql -d kleidia -c \
     "SELECT id, username, email, created_at, is_active FROM users
      WHERE hashed_password <> '' AND COALESCE(sync_source, '') IN ('', 'manual')
        AND deleted_at IS NULL ORDER BY created_at"
   ```
   Registration is not audited, so compare the list against the accounts your
   administrators created. The seeded `admin` account always appears.

2. **For every account nobody can vouch for:** revoke its YubiKeys (Admin
   Panel → YubiKeys → Revoke Device, which revokes their certificates on 2.4.2)
   and disable or delete the account (Admin Panel → Users).

## Vault 403 Errors

### Symptom
Backend returns 403 errors when accessing Vault.

### Diagnosis

```bash
# Check Vault status
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- bao status

# Check backend Vault authentication
kubectl logs -f deployment/backend -n kleidia | grep -i vault

# Check AppRole credentials
kubectl get secret openbao-backend-approle -n kleidia

# Test Vault authentication
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
  bao write auth/approle/login \
    role_id=<role-id> \
    secret_id=<secret-id>
```

### Resolution

1. **Policy Issues**
   ```bash
   # Check backend policy
   kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
     bao policy read kleidia-backend
   
   # Update policy if needed
   kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
     bao policy write kleidia-backend - <<EOF
   path "pki/sign/*" {
     capabilities = ["create", "read", "update"]
   }
   path "yubikeys/data/*" {
     capabilities = ["create", "read", "update", "delete", "list"]
   }
   EOF
   ```

2. **AppRole Credentials**
   ```bash
   # Regenerate AppRole credentials
   # See Vault Setup documentation
   ```

3. **Token Expired**
   ```bash
   # Restart backend to get new token
   kubectl rollout restart deployment/backend -n kleidia
   ```

## TLS Certificate Expiry

### Symptom
Browser shows certificate errors or certificate expired warnings.

### Diagnosis

```bash
# Check certificate expiration
echo | openssl s_client -connect kleidia.example.com:443 2>/dev/null | \
  openssl x509 -noout -dates

# Check Let's Encrypt certificates
sudo certbot certificates
```

### Resolution

1. **Certificate Expired**
   - Renew certificate through your external load balancer
   - Verify certificate is properly configured

2. **Certificate Not Renewing**
   - Check certificate renewal configuration in your load balancer
   - Verify DNS records are correct
   - Test certificate renewal manually

## Agent Connection Issues

### Symptom
Agents cannot connect or communicate with backend.

### Diagnosis

```bash
# Check agent is running on workstation
curl http://127.0.0.1:56123/health

# Check agent discovery
curl http://127.0.0.1:56123/.well-known/kleidia-agent

# Check backend logs
kubectl logs -f deployment/backend -n kleidia | grep -i agent
```

### Resolution

1. **Agent Not Running**
   - Verify agent is installed on workstation
   - Start agent service or run manually
   - Check agent logs for errors

2. **Connection Refused**
   - Verify agent is running on localhost:56123
   - Check browser console for CORS errors
   - Verify user is logged in
   - Check backend is accessible

## High Disk Usage

### Symptom
System running out of disk space.

### Diagnosis

```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Check Kubernetes disk usage
kubectl top nodes
```

### Resolution

1. **Clean Docker**
   ```bash
   # Remove unused containers, images, volumes
   docker system prune -af
   docker image prune -af
   ```

2. **Clean Kubernetes**
   ```bash
   # Remove completed jobs
   kubectl delete jobs --field-selector status.successful=1 -n kleidia
   
   # Remove old logs (if log rotation not configured)
   ```

3. **Expand Storage**
   - Add additional disk
   - Expand persistent volumes
   - Archive old data

## Database Performance Issues

### Symptom
Slow queries, high database load.

### Diagnosis

```bash
# Check database connections
kubectl exec -it kleidia-db-1 -n kleidia -- \
  psql -U kleidiauser -d kleidia -c "SELECT count(*) FROM pg_stat_activity;"

# Check slow queries
kubectl exec -it kleidia-db-1 -n kleidia -- \
  psql -U kleidiauser -d kleidia -c "
    SELECT query, calls, total_time, mean_time
    FROM pg_stat_statements
    ORDER BY mean_time DESC
    LIMIT 10;
  "
```

### Resolution

1. **Too Many Connections**
   ```bash
   # Check connection pool settings
   # Reduce connection pool size if needed
   ```

2. **Slow Queries**
   ```bash
   # Vacuum database
   kubectl exec -it kleidia-db-1 -n kleidia -- \
     psql -U kleidiauser -d kleidia -c "VACUUM ANALYZE;"
   
   # Check for missing indexes
   kubectl exec -it kleidia-db-1 -n kleidia -- \
     psql -U kleidiauser -d kleidia -c "
       SELECT schemaname, tablename, attname, n_distinct, correlation
       FROM pg_stats
       WHERE schemaname = 'public'
       ORDER BY abs(correlation) DESC;
     "
   ```

## Pod CrashLoopBackOff

### Symptom
Pods restarting repeatedly.

### Diagnosis

```bash
# Check pod status
kubectl get pods -n kleidia

# Check pod logs
kubectl logs -f <pod-name> -n kleidia

# Check pod events
kubectl describe pod <pod-name> -n kleidia
```

### Resolution

1. **Application Errors**
   - Check application logs for errors
   - Verify configuration
   - Check dependencies

2. **Resource Constraints**
   ```bash
   # Check resource limits
   kubectl describe pod <pod-name> -n kleidia | grep -A 5 "Limits"
   
   # Increase resources if needed
   # Update Helm values and upgrade
   ```

3. **Configuration Errors**
   - Verify environment variables
   - Check secrets exist
   - Verify service connectivity

## Emergency Procedures

### Complete System Restart

```bash
# Restart all pods
kubectl rollout restart deployment -n kleidia
```

### Database Recovery

```bash
# Stop backend
kubectl scale deployment/backend --replicas=0 -n kleidia

# Restore from backup
gunzip -c backups/20250115/database.sql.gz | \
  kubectl exec -i kleidia-db-1 -n kleidia -- \
  psql -U kleidiauser -d kleidia

# Restart backend
kubectl scale deployment/backend --replicas=2 -n kleidia
```

### Vault Recovery

OpenBao uses `storage "file"`, so recovery is done by restoring its on-disk data directory (`/openbao/data`) from a backup archive — there is no raft snapshot restore. For most scenarios, prefer the built-in restore (KV secrets) plus the PostgreSQL restore above.

```bash
# Stop backend
kubectl scale deployment/backend --replicas=0 -n kleidia

# Copy the data-directory archive into the pod
kubectl cp backups/20250115/openbao-data.tar.gz \
  kleidia-platform-openbao-0:/tmp/openbao-data.tar.gz -n kleidia

# Restore the data directory (OpenBao must be restarted afterwards to re-read it)
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
  sh -c "tar xzf /tmp/openbao-data.tar.gz -C /openbao"

# Restart OpenBao so it loads the restored data and auto-unseals
kubectl rollout restart statefulset/kleidia-platform-openbao -n kleidia

# Restart backend
kubectl scale deployment/backend --replicas=2 -n kleidia
```

> **Note**: The restored data directory is only usable by an OpenBao instance with the same static unseal key.

## Related Documentation

- [Daily Operations](daily-operations.md)
- [Monitoring and Logs](monitoring-and-logs.md)
- [Backups and Restore](backups-and-restore.md)
- [Troubleshooting](../03-deployment/troubleshooting.md)

