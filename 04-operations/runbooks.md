# Operational Runbooks

**Audience**: Operations Administrators  
**Prerequisites**: YubiMgr deployed  
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
curl http://127.0.0.1:56123/.well-known/yubimgr-agent

# Check backend logs
kubectl logs -f deployment/yubimgr-services-backend -n yubimgr | grep -i agent
```

### Resolution

1. **Agent Not Running**
   ```bash
   # On user workstation
   # Start agent service
   sudo systemctl start yubimgr-agent
   # Or run manually
   ./yubimgr-agent
   ```

2. **Agent Not Detected**
   - Verify agent is running on localhost:56123
   - Check browser console for CORS errors
   - Verify user is logged in

3. **Key Registration Failed**
   ```bash
   # Check backend logs for registration errors
   kubectl logs -f deployment/yubimgr-services-backend -n yubimgr | grep -i register
   
   # Check database for agent keys
   kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
     psql -U yubiuser -d yubimgr -c "SELECT * FROM user_sessions WHERE agent_pubkey IS NOT NULL;"
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
   kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
     psql -U yubiuser -d yubimgr -c \
     "SELECT id, serial, is_active, deleted_at FROM yubikeys WHERE serial = '<serial-number>';"
   ```

3. **Verify Secrets Removed**:
   ```bash
   # Check Vault secrets (should be removed)
   kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
     vault kv list yubikeys/data/ | grep <serial-number>
   ```

4. **Verify Certificates Revoked**:
   ```bash
   # Check audit logs for certificate revocation
   kubectl logs -f deployment/yubimgr-services-backend -n yubimgr | grep -i "revoke.*certificate"
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

## Vault 403 Errors

### Symptom
Backend returns 403 errors when accessing Vault.

### Diagnosis

```bash
# Check Vault status
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault status

# Check backend Vault authentication
kubectl logs -f deployment/yubimgr-services-backend -n yubimgr | grep -i vault

# Check AppRole credentials
kubectl get secret vault-approle -n yubimgr

# Test Vault authentication
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
  vault write auth/approle/login \
    role_id=<role-id> \
    secret_id=<secret-id>
```

### Resolution

1. **Policy Issues**
   ```bash
   # Check backend policy
   kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
     vault policy read yubimgr-backend
   
   # Update policy if needed
   kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
     vault policy write yubimgr-backend - <<EOF
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
   kubectl rollout restart deployment/yubimgr-services-backend -n yubimgr
   ```

## TLS Certificate Expiry

### Symptom
Browser shows certificate errors or certificate expired warnings.

### Diagnosis

```bash
# Check certificate expiration
echo | openssl s_client -connect yubimgr.example.com:443 2>/dev/null | \
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
curl http://127.0.0.1:56123/.well-known/yubimgr-agent

# Check backend logs
kubectl logs -f deployment/yubimgr-services-backend -n yubimgr | grep -i agent
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
   kubectl delete jobs --field-selector status.successful=1 -n yubimgr
   
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
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "SELECT count(*) FROM pg_stat_activity;"

# Check slow queries
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "
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
   kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
     psql -U yubiuser -d yubimgr -c "VACUUM ANALYZE;"
   
   # Check for missing indexes
   kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
     psql -U yubiuser -d yubimgr -c "
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
kubectl get pods -n yubimgr

# Check pod logs
kubectl logs -f <pod-name> -n yubimgr

# Check pod events
kubectl describe pod <pod-name> -n yubimgr
```

### Resolution

1. **Application Errors**
   - Check application logs for errors
   - Verify configuration
   - Check dependencies

2. **Resource Constraints**
   ```bash
   # Check resource limits
   kubectl describe pod <pod-name> -n yubimgr | grep -A 5 "Limits"
   
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
kubectl rollout restart deployment -n yubimgr
```

### Database Recovery

```bash
# Stop backend
kubectl scale deployment/yubimgr-services-backend --replicas=0 -n yubimgr

# Restore from backup
gunzip -c backups/20250115/database.sql.gz | \
  kubectl exec -i yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr

# Restart backend
kubectl scale deployment/yubimgr-services-backend --replicas=2 -n yubimgr
```

### Vault Recovery

```bash
# Stop backend
kubectl scale deployment/yubimgr-services-backend --replicas=0 -n yubimgr

# Restore Vault snapshot
kubectl cp backups/20250115/vault-backup.snap \
  yubimgr-platform-openbao-0:/tmp/vault-backup.snap -n yubimgr

kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
  vault operator raft snapshot restore /tmp/vault-backup.snap

# Restart backend
kubectl scale deployment/yubimgr-services-backend --replicas=2 -n yubimgr
```

## Related Documentation

- [Daily Operations](daily-operations.md)
- [Monitoring and Logs](monitoring-and-logs.md)
- [Backups and Restore](backups-and-restore.md)
- [Troubleshooting](../03-deployment/troubleshooting.md)

