# Deployment Troubleshooting

**Audience**: Operations Administrators  
**Prerequisites**: Kubernetes and Helm knowledge  
**Outcome**: Troubleshoot common deployment issues

## Common Issues

### Pods Not Starting

#### Symptoms
- Pods stuck in `Pending` or `CrashLoopBackOff` state
- Pods restarting repeatedly

#### Diagnosis

```bash
# Check pod status
kubectl get pods -n kleidia

# Check pod details
kubectl describe pod <pod-name> -n kleidia

# Check pod logs
kubectl logs -f <pod-name> -n kleidia

# Check events
kubectl get events -n kleidia --sort-by=.metadata.creationTimestamp
```

#### Common Causes

1. **Image Pull Errors**
   - **Symptom**: `ErrImagePull` or `ImagePullBackOff`
   - **Solution**: Check registry connectivity, verify image exists
   ```bash
   kubectl describe pod <pod-name> -n kleidia | grep -i image
   ```

2. **Resource Constraints**
   - **Symptom**: `Insufficient resources`
   - **Solution**: Check node resources, adjust resource requests
   ```bash
   kubectl top nodes
   kubectl describe node | grep -A 5 "Allocated resources"
   ```

3. **Storage Issues**
   - **Symptom**: `Pending` pods, PVC not bound
   - **Solution**: Check storage class, verify disk space
   ```bash
   kubectl get pvc -n kleidia
   kubectl describe pvc <pvc-name> -n kleidia
   df -h
   ```

### Database Connection Issues

#### Symptoms
- Backend cannot connect to database
- `Connection refused` errors in logs

#### Diagnosis

```bash
# Check PostgreSQL pod status
kubectl get pods -l app=postgres-cluster -n kleidia

# Check PostgreSQL logs
kubectl logs -f kleidia-data-postgres-cluster-0 -n kleidia

# Test database connection
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT 1;"

# Check backend logs
kubectl logs -f deployment/kleidia-services-backend -n kleidia | grep -i postgres
```

#### Solutions

1. **PostgreSQL Not Ready**
   ```bash
   # Wait for PostgreSQL to be ready
   kubectl wait --for=condition=ready pod -l app=postgres-cluster -n kleidia --timeout=300s
   ```

2. **Wrong Credentials**
   - Check database credentials in Vault
   - Verify backend environment variables

3. **Network Issues**
   - Verify service name: `postgres-cluster.kleidia.svc.cluster.local`
   - Check network policies

### Vault Connection Issues

#### Symptoms
- Backend cannot connect to Vault
- `403 Forbidden` or `Connection refused` errors

#### Diagnosis

```bash
# Check Vault pod status
kubectl get pods -l app.kubernetes.io/name=openbao -n kleidia

# Check Vault status
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status

# Check Vault logs
kubectl logs -f kleidia-platform-openbao-0 -n kleidia

# Test Vault connectivity
kubectl exec -it deployment/kleidia-services-backend -n kleidia -- \
  curl http://kleidia-platform-openbao:8200/v1/sys/health
```

#### Solutions

1. **Vault Sealed**
   ```bash
   # Check auto-unseal
   kubectl logs kleidia-platform-openbao-0 -n kleidia | grep -i unseal
   
   # Manual unseal (if needed)
   kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault operator unseal <key>
   ```

2. **AppRole Authentication Failed**
   ```bash
   # Check AppRole secret
   kubectl get secret vault-approle -n kleidia
   
   # Verify backend can authenticate
   kubectl exec -it deployment/kleidia-services-backend -n kleidia -- \
     env | grep VAULT
   ```

3. **Policy Issues**
   ```bash
   # Check backend policy
   kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault policy read kleidia-backend
   ```

### SSL Certificate Issues

#### Symptoms
- Browser shows certificate errors
- TLS certificate not valid

#### Diagnosis

```bash
# Check certificate expiration
echo | openssl s_client -connect kleidia.example.com:443 -servername kleidia.example.com 2>/dev/null | \
  openssl x509 -noout -dates

# Test SSL connection
curl -I https://kleidia.example.com
```

#### Solutions

1. **Certificate Expired**
   - Renew certificate through your external load balancer
   - Verify certificate is properly configured

2. **Certificate Not Valid**
   - Check certificate configuration in your load balancer
   - Verify domain name matches certificate
   - Check certificate chain is complete

### Service Not Accessible

#### Symptoms
- Cannot access web interface
- API endpoints return errors

#### Diagnosis

```bash
# Check service status
kubectl get services -n kleidia

# Check NodePort accessibility
curl http://localhost:32570/api/health
curl http://localhost:30805/

# Test external access
curl -I https://kleidia.example.com
curl https://kleidia.example.com/api/health
```

#### Solutions

1. **NodePort Not Accessible**
   - Verify NodePort values match your load balancer configuration
   - Check firewall rules
   - Verify pods are running

2. **Load Balancer Issues**
   - Check load balancer configuration
   - Verify routing rules
   - Check health checks

3. **Routing Issues**
   - Verify load balancer backend configuration
   - Check routing rules
   - Verify host headers

## Diagnostic Commands

### System Health Check

```bash
# Check all pods
kubectl get pods -n kleidia

# Check all services
kubectl get services -n kleidia

# Check persistent volumes
kubectl get pvc -n kleidia

# Check resource usage
kubectl top pods -n kleidia
kubectl top nodes

# Check disk space
df -h
```

### Component-Specific Checks

```bash
# Backend health
curl https://kleidia.example.com/api/health

# Database health
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT 1;"

# Vault health
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status

# Frontend accessibility
curl -I https://kleidia.example.com
```

### Log Analysis

```bash
# Backend logs
kubectl logs -f deployment/kleidia-services-backend -n kleidia

# Frontend logs
kubectl logs -f deployment/kleidia-services-frontend -n kleidia

# Database logs
kubectl logs -f kleidia-data-postgres-cluster-0 -n kleidia

# OpenBao logs
kubectl logs -f kleidia-platform-openbao-0 -n kleidia
```

## Emergency Procedures

### Complete System Restart

```bash
# Restart all pods
kubectl rollout restart deployment -n kleidia
```

### Database Recovery

```bash
# Restore from backup
kubectl exec -i kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia < backup.sql
```

### Vault Recovery

```bash
# Restore Vault snapshot
kubectl cp ./vault-backup.snap kleidia-platform-openbao-0:/tmp/vault-backup.snap -n kleidia

kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
  vault operator raft snapshot restore /tmp/vault-backup.snap
```

## Bootstrap and First-Time Setup Issues

### Admin Account Creation Not Available

#### Symptoms
- Cannot see "Create Admin" form on login page
- Only regular login form is displayed

#### Diagnosis

```bash
# Check if admin users exist
kubectl exec -it deployment/kleidia-services-backend -n kleidia -- \
  curl http://localhost:8080/api/bootstrap/status

# Expected: {"pending": true} if no admin exists
# Expected: {"pending": false} if admin already created
```

#### Solutions

1. **Admin Already Exists**
   - An admin user was already created
   - Use existing admin credentials to log in
   - Contact system administrator for credentials

2. **Database Connection Issues**
   - Check backend can connect to database
   - Verify database is ready
   ```bash
   kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i bootstrap
   ```

### OpenBao Bootstrap Keys Modal Issues

#### Symptoms
- Modal does not appear after first admin login
- Modal appears but keys are empty
- Cannot confirm and delete keys

#### Diagnosis

```bash
# Check if OpenBao initialization keys secret exists
kubectl get secret openbao-init-keys -n kleidia

# Check backend logs for key retrieval
kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i "OPENBAO_KEYS"

# Check backend has RBAC permissions
kubectl get role backend-secret-reader -n kleidia -o yaml
```

#### Solutions

1. **Keys Secret Already Deleted**
   - **Symptom**: Secret not found
   - **Meaning**: Keys were already handled on a previous login
   - **Action**: This is normal - modal only appears once
   - **Recovery**: If keys were not saved, see "Lost OpenBao Keys" section

2. **Backend Cannot Access Secret**
   - **Symptom**: Backend logs show permission denied
   - **Solution**: Verify RBAC permissions
   ```bash
   # Check RoleBinding
   kubectl get rolebinding backend-secret-reader -n kleidia -o yaml
   
   # Verify backend ServiceAccount
   kubectl get sa backend -n kleidia
   ```

3. **Keys Not Generated During Installation**
   - **Symptom**: Secret exists but is empty
   - **Solution**: Check OpenBao initialization job
   ```bash
   # Check initialization job logs
   kubectl logs -n kleidia -l app=openbao-init --tail=100
   
   # Verify OpenBao status
   kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status
   ```

### Lost OpenBao Bootstrap Keys

#### Symptoms
- OpenBao keys were not saved during first-time setup
- Need to recover access to OpenBao root token

#### Impact
- **Normal operations continue**: Daily YubiKey management works fine
- **Limited impact**: Backend uses AppRole authentication (not root token)
- **Emergency operations affected**: Cannot perform root-level Vault operations

#### Diagnosis

```bash
# Check if keys secret still exists (unlikely after confirmation)
kubectl get secret openbao-init-keys -n kleidia

# Check audit logs for key access
kubectl exec -it deployment/kleidia-services-backend -n kleidia -- \
  curl http://localhost:8080/api/admin/audit-logs | grep openbao.keys
```

#### Recovery Options

1. **Secret Still Exists** (Before Modal Confirmation)
   - Get secret directly from Kubernetes
   ```bash
   # Extract root token
   kubectl get secret openbao-init-keys -n kleidia -o jsonpath='{.data.root-token}' | base64 -d
   
   # Extract recovery keys
   kubectl get secret openbao-init-keys -n kleidia -o jsonpath='{.data.recovery-key-1}' | base64 -d
   kubectl get secret openbao-init-keys -n kleidia -o jsonpath='{.data.recovery-key-2}' | base64 -d
   kubectl get secret openbao-init-keys -n kleidia -o jsonpath='{.data.recovery-key-3}' | base64 -d
   ```
   - **Save these keys securely** before clicking "Confirm" in the modal

2. **Secret Already Deleted** (After Modal Confirmation)
   - **Option A**: Continue normal operations (no impact on daily use)
   - **Option B**: Contact Kleidia support for advanced recovery procedures
   - **Option C**: If disaster recovery is required, may need system reinstallation

3. **Prevention for Future**
   - Always save keys before confirming deletion
   - Store keys in multiple secure locations
   - Use enterprise password manager
   - Print and store in physical safe

### Bootstrap Lock Timeout

#### Symptoms
- "Bootstrap in progress" error when trying to create admin
- Cannot access admin creation form

#### Diagnosis

```bash
# Check active bootstrap locks
kubectl exec -it deployment/kleidia-services-backend -n kleidia -- \
  curl http://localhost:8080/api/bootstrap/status

# Check backend logs
kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i bootstrap
```

#### Solutions

1. **Wait for Lock Expiry**
   - Bootstrap locks expire after 10 minutes
   - Wait and retry admin creation

2. **Clear Expired Locks** (Database Access)
   ```bash
   # Connect to database
   kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
     psql -U yubiuser -d kleidia
   
   # Check locks
   SELECT * FROM bootstrap_locks WHERE expires_at > NOW();
   
   # Delete expired locks (if needed)
   DELETE FROM bootstrap_locks WHERE expires_at < NOW();
   ```

## Getting Help

### Information to Collect

When reporting issues, collect:

1. **Pod Status**: `kubectl get pods -n kleidia`
2. **Pod Logs**: `kubectl logs <pod-name> -n kleidia`
3. **Events**: `kubectl get events -n kleidia`
4. **Service Status**: `kubectl get services -n kleidia`
5. **Helm Status**: `helm status kleidia-* -n kleidia`
6. **System Resources**: `kubectl top nodes`

### Support Resources

- Check [Operations Guide](../04-operations/) for operational procedures
- Review [Configuration Guide](configuration.md) for configuration issues
- See [Upgrades Guide](upgrades-and-rollback.md) for upgrade issues

## Related Documentation

- [Helm Installation](helm-install.md)
- [Configuration](configuration.md)
- [Vault Setup](vault-setup.md)
- [Operations Guide](../04-operations/)

