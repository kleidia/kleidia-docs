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
kubectl get pods -n yubimgr

# Check pod details
kubectl describe pod <pod-name> -n yubimgr

# Check pod logs
kubectl logs -f <pod-name> -n yubimgr

# Check events
kubectl get events -n yubimgr --sort-by=.metadata.creationTimestamp
```

#### Common Causes

1. **Image Pull Errors**
   - **Symptom**: `ErrImagePull` or `ImagePullBackOff`
   - **Solution**: Check registry connectivity, verify image exists
   ```bash
   kubectl describe pod <pod-name> -n yubimgr | grep -i image
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
   kubectl get pvc -n yubimgr
   kubectl describe pvc <pvc-name> -n yubimgr
   df -h
   ```

### Database Connection Issues

#### Symptoms
- Backend cannot connect to database
- `Connection refused` errors in logs

#### Diagnosis

```bash
# Check PostgreSQL pod status
kubectl get pods -l app=postgres-cluster -n yubimgr

# Check PostgreSQL logs
kubectl logs -f yubimgr-data-postgres-cluster-0 -n yubimgr

# Test database connection
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "SELECT 1;"

# Check backend logs
kubectl logs -f deployment/yubimgr-services-backend -n yubimgr | grep -i postgres
```

#### Solutions

1. **PostgreSQL Not Ready**
   ```bash
   # Wait for PostgreSQL to be ready
   kubectl wait --for=condition=ready pod -l app=postgres-cluster -n yubimgr --timeout=300s
   ```

2. **Wrong Credentials**
   - Check database credentials in Vault
   - Verify backend environment variables

3. **Network Issues**
   - Verify service name: `postgres-cluster.yubimgr.svc.cluster.local`
   - Check network policies

### Vault Connection Issues

#### Symptoms
- Backend cannot connect to Vault
- `403 Forbidden` or `Connection refused` errors

#### Diagnosis

```bash
# Check Vault pod status
kubectl get pods -l app.kubernetes.io/name=openbao -n yubimgr

# Check Vault status
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault status

# Check Vault logs
kubectl logs -f yubimgr-platform-openbao-0 -n yubimgr

# Test Vault connectivity
kubectl exec -it deployment/yubimgr-services-backend -n yubimgr -- \
  curl http://yubimgr-platform-openbao:8200/v1/sys/health
```

#### Solutions

1. **Vault Sealed**
   ```bash
   # Check auto-unseal
   kubectl logs yubimgr-platform-openbao-0 -n yubimgr | grep -i unseal
   
   # Manual unseal (if needed)
   kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault operator unseal <key>
   ```

2. **AppRole Authentication Failed**
   ```bash
   # Check AppRole secret
   kubectl get secret vault-approle -n yubimgr
   
   # Verify backend can authenticate
   kubectl exec -it deployment/yubimgr-services-backend -n yubimgr -- \
     env | grep VAULT
   ```

3. **Policy Issues**
   ```bash
   # Check backend policy
   kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault policy read yubimgr-backend
   ```

### SSL Certificate Issues

#### Symptoms
- Browser shows certificate errors
- TLS certificate not valid

#### Diagnosis

```bash
# Check certificate expiration
echo | openssl s_client -connect yubimgr.example.com:443 -servername yubimgr.example.com 2>/dev/null | \
  openssl x509 -noout -dates

# Test SSL connection
curl -I https://yubimgr.example.com
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
kubectl get services -n yubimgr

# Check NodePort accessibility
curl http://localhost:32570/api/health
curl http://localhost:30805/

# Test external access
curl -I https://yubimgr.example.com
curl https://yubimgr.example.com/api/health
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
kubectl get pods -n yubimgr

# Check all services
kubectl get services -n yubimgr

# Check persistent volumes
kubectl get pvc -n yubimgr

# Check resource usage
kubectl top pods -n yubimgr
kubectl top nodes

# Check disk space
df -h
```

### Component-Specific Checks

```bash
# Backend health
curl https://yubimgr.example.com/api/health

# Database health
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "SELECT 1;"

# Vault health
kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- vault status

# Frontend accessibility
curl -I https://yubimgr.example.com
```

### Log Analysis

```bash
# Backend logs
kubectl logs -f deployment/yubimgr-services-backend -n yubimgr

# Frontend logs
kubectl logs -f deployment/yubimgr-services-frontend -n yubimgr

# Database logs
kubectl logs -f yubimgr-data-postgres-cluster-0 -n yubimgr

# OpenBao logs
kubectl logs -f yubimgr-platform-openbao-0 -n yubimgr
```

## Emergency Procedures

### Complete System Restart

```bash
# Restart all pods
kubectl rollout restart deployment -n yubimgr
```

### Database Recovery

```bash
# Restore from backup
kubectl exec -i yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr < backup.sql
```

### Vault Recovery

```bash
# Restore Vault snapshot
kubectl cp ./vault-backup.snap yubimgr-platform-openbao-0:/tmp/vault-backup.snap -n yubimgr

kubectl exec -it yubimgr-platform-openbao-0 -n yubimgr -- \
  vault operator raft snapshot restore /tmp/vault-backup.snap
```

## Getting Help

### Information to Collect

When reporting issues, collect:

1. **Pod Status**: `kubectl get pods -n yubimgr`
2. **Pod Logs**: `kubectl logs <pod-name> -n yubimgr`
3. **Events**: `kubectl get events -n yubimgr`
4. **Service Status**: `kubectl get services -n yubimgr`
5. **Helm Status**: `helm status yubimgr-* -n yubimgr`
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

