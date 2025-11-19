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

