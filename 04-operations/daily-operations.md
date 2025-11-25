# Daily Operations

**Audience**: Operations Administrators  
**Prerequisites**: Kleidia deployed and running  
**Outcome**: Understand daily operational tasks and procedures

## Daily Checklist

### Morning Checks

- [ ] Check system health: `curl https://kleidia.example.com/api/health`
- [ ] Verify all pods are running: `kubectl get pods -n kleidia`
- [ ] Check disk space: `df -h`
- [ ] Review error logs: `kubectl logs -f deployment/kleidia-services-backend -n kleidia | grep -i error`
- [ ] Check certificate expiration: `echo | openssl s_client -connect kleidia.example.com:443 2>/dev/null | openssl x509 -noout -dates`

### Ongoing Monitoring

- [ ] Monitor resource usage: `kubectl top pods -n kleidia`
- [ ] Check audit logs for security events
- [ ] Monitor failed login attempts
- [ ] Review user activity patterns
- [ ] Check backup completion status

## Health Checks

### Application Health

```bash
# Backend health endpoint
curl https://kleidia.example.com/api/health

# Expected response:
# {"status":"ok","version":"2.2.0","database":"connected","vault":"connected"}
```

### Component Health

```bash
# Check all pods
kubectl get pods -n kleidia

# Check services
kubectl get services -n kleidia

# Check persistent volumes
kubectl get pvc -n kleidia

# Check resource usage
kubectl top pods -n kleidia
kubectl top nodes
```

### Database Health

```bash
# Check PostgreSQL status
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT version();"

# Check database connections
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT count(*) FROM pg_stat_activity;"
```

### Vault Health

```bash
# Check Vault status
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- vault status

# Expected output:
# Key             Value
# ---             -----
# Seal Type       shamir
# Initialized     true
# Sealed          false
# ...
```

## Log Management

### Viewing Logs

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

### Log Filtering

```bash
# Filter errors
kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i error

# Filter by time
kubectl logs deployment/kleidia-services-backend -n kleidia --since=1h

# Filter by component
kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i vault
```

## User Management

### Create User

```bash
# Via web interface (recommended)
# Navigate to Admin → Users → Create User

# Or via API (if needed)
curl -X POST https://kleidia.example.com/api/admin/users \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser",
    "email": "user@example.com",
    "password": "secure-password",
    "is_admin": false
  }'
```

### Disable User

```bash
# Via web interface
# Navigate to Admin → Users → Select User → Disable

# Or via API
curl -X PATCH https://kleidia.example.com/api/admin/users/{id} \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{"is_active": false}'
```

## System Maintenance

### Restart Services

```bash
# Restart backend
kubectl rollout restart deployment/kleidia-services-backend -n kleidia

# Restart frontend
kubectl rollout restart deployment/kleidia-services-frontend -n kleidia

# Restart all services
kubectl rollout restart deployment -n kleidia
```

### Clean Up Resources

```bash
# Clean up completed jobs
kubectl delete jobs --field-selector status.successful=1 -n kleidia

# Clean up old logs (if log rotation not configured)
# Manual cleanup of log files if needed
```

## Monitoring

### Resource Monitoring

```bash
# Check CPU and memory usage
kubectl top pods -n kleidia

# Check node resources
kubectl top nodes

# Check disk usage
df -h

# Check Docker disk usage
docker system df
```

### Application Monitoring

- **Health Endpoints**: Monitor `/api/health` endpoint
- **Error Rates**: Monitor error logs and metrics
- **Response Times**: Monitor API response times
- **User Activity**: Review audit logs for activity patterns

## Common Tasks

### Certificate Renewal

Certificates are managed by your external load balancer. Verify certificate expiration:

```bash
# Check certificate expiration
echo | openssl s_client -connect kleidia.example.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### Secret Rotation

```bash
# Rotate JWT secret (via web interface)
# Navigate to Admin → Security → Rotate Secrets

# Or manually update in Vault
kubectl exec -it kleidia-platform-openbao-0 -n kleidia -- \
  vault kv put secret/kleidia/jwt-secret secret="new-secret"
```

### Database Maintenance

```bash
# Vacuum database
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "VACUUM ANALYZE;"

# Check database size
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT pg_size_pretty(pg_database_size('kleidia'));"
```

## Troubleshooting Common Issues

### High Resource Usage

```bash
# Identify resource-heavy pods
kubectl top pods -n kleidia --sort-by=memory
kubectl top pods -n kleidia --sort-by=cpu

# Check for memory leaks
kubectl logs deployment/kleidia-services-backend -n kleidia | grep -i "out of memory"
```

### Slow Response Times

```bash
# Check database query performance
kubectl exec -it kleidia-data-postgres-cluster-0 -n kleidia -- \
  psql -U yubiuser -d kleidia -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# Check network latency
ping kleidia.example.com
```

### Connection Issues

```bash
# Test backend connectivity
curl http://localhost:32570/api/health

# Test frontend connectivity
curl http://localhost:30805/

# Test external access
curl https://kleidia.example.com/api/health
```

## Best Practices

- ✅ Perform daily health checks
- ✅ Monitor logs regularly
- ✅ Review audit logs weekly
- ✅ Keep backups current
- ✅ Monitor resource usage
- ✅ Test disaster recovery procedures
- ✅ Keep documentation updated
- ✅ Communicate changes to users

## Related Documentation

- [Monitoring and Logs](monitoring-and-logs.md)
- [Backups and Restore](backups-and-restore.md)
- [Runbooks](runbooks.md)
- [Troubleshooting](../03-deployment/troubleshooting.md)

