# Monitoring and Logs

**Audience**: Operations Administrators  
**Prerequisites**: YubiMgr deployed  
**Outcome**: Understand monitoring and log management

## Monitoring Overview

YubiMgr provides multiple monitoring points for system health, performance, and security.

## Health Monitoring

### Application Health Endpoints

#### Backend Health

```bash
# Health check endpoint
curl https://yubimgr.example.com/api/health

# Response:
{
  "status": "ok",
  "version": "2.2.0",
  "database": "connected",
  "vault": "connected",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### Component Health Checks

```bash
# Database health
curl https://yubimgr.example.com/api/admin/system/database

# Vault health
curl https://yubimgr.example.com/api/admin/system/vault

# System health (all components)
curl https://yubimgr.example.com/api/admin/system/health
```

### Kubernetes Health

```bash
# Pod health
kubectl get pods -n yubimgr

# Service health
kubectl get services -n yubimgr

# Resource health
kubectl top pods -n yubimgr
kubectl top nodes
```

## Log Management

### Log Locations

#### Application Logs

- **Backend**: Kubernetes pod logs
- **Frontend**: Kubernetes pod logs
- **Database**: PostgreSQL pod logs
- **OpenBao**: OpenBao pod logs

#### Accessing Logs

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

### Log Levels

- **INFO**: General informational messages
- **WARN**: Warning messages
- **ERROR**: Error messages

**Note**: DEBUG level logs are available for troubleshooting but not typically needed for normal operations.

### Log Filtering

```bash
# Filter by level
kubectl logs deployment/yubimgr-services-backend -n yubimgr | grep -i error

# Filter by time
kubectl logs deployment/yubimgr-services-backend -n yubimgr --since=1h

# Filter by component
kubectl logs deployment/yubimgr-services-backend -n yubimgr | grep -i vault

# Filter by user
kubectl logs deployment/yubimgr-services-backend -n yubimgr | grep "user_id=123"
```

## Audit Logging

### Audit Log Access

```bash
# Via web interface
# Navigate to Admin → Audit Logs

# Via API
curl https://yubimgr.example.com/api/admin/audit \
  -H "Authorization: Bearer <admin-token>"

# Filter by date range
curl "https://yubimgr.example.com/api/admin/audit?start=2025-01-01&end=2025-01-31" \
  -H "Authorization: Bearer <admin-token>"
```

### Audit Log Types

- **Authentication**: Login, logout, failed attempts
- **Device Operations**: Registration, PIN/PUK changes, certificate operations
- **Administrative**: User management, policy changes
- **Security Events**: Permission denials, suspicious activity

## Performance Monitoring

### Resource Metrics

```bash
# CPU and memory usage
kubectl top pods -n yubimgr

# Node resources
kubectl top nodes

# Disk usage
df -h

# Docker disk usage
docker system df
```

### Application Metrics

- **Response Times**: Monitor API response times
- **Error Rates**: Track error rates over time
- **Request Rates**: Monitor request volume
- **Database Performance**: Track query performance

## Alerting

### Key Metrics to Monitor

1. **Pod Status**: Pods should be Running
2. **Resource Usage**: CPU/Memory should be below limits
3. **Error Rates**: Error rates should be low
4. **Certificate Expiration**: Certificates should not expire soon
5. **Disk Space**: Disk usage should be below 85%
6. **Database Connections**: Connection pool usage

### Setting Up Alerts

While YubiMgr doesn't include built-in alerting, you can:

1. **Use Kubernetes monitoring**: Prometheus, Grafana
2. **External monitoring**: Nagios, Zabbix, Datadog
3. **Log aggregation**: ELK stack, Splunk
4. **Custom scripts**: Monitor health endpoints

## Log Retention

### Database Logs

- **Audit Logs**: Stored in PostgreSQL
- **Retention**: Configurable (default: 90 days)
- **Archival**: Export before cleanup

### Application Logs

- **Kubernetes Logs**: Managed by Kubernetes
- **Retention**: Configurable via log rotation
- **Archival**: Export important logs

### Vault Audit Logs

- **Location**: Vault audit storage
- **Retention**: Configurable
- **Archival**: Vault snapshot includes audit logs

## Log Analysis

### Common Patterns

#### High Error Rates

```bash
# Count errors in last hour
kubectl logs deployment/yubimgr-services-backend -n yubimgr --since=1h | \
  grep -i error | wc -l

# Group errors by type
kubectl logs deployment/yubimgr-services-backend -n yubimgr --since=1h | \
  grep -i error | sort | uniq -c
```

#### Slow Queries

```bash
# Check PostgreSQL slow queries
kubectl exec -it yubimgr-data-postgres-cluster-0 -n yubimgr -- \
  psql -U yubiuser -d yubimgr -c "
    SELECT query, calls, total_time, mean_time
    FROM pg_stat_statements
    ORDER BY mean_time DESC
    LIMIT 10;
  "
```

#### Failed Authentications

```bash
# Check failed login attempts
curl "https://yubimgr.example.com/api/admin/audit?action=login&status=failed" \
  -H "Authorization: Bearer <admin-token>"
```

## Best Practices

- ✅ Monitor health endpoints regularly
- ✅ Set up automated health checks
- ✅ Review logs daily
- ✅ Archive important logs
- ✅ Monitor resource usage
- ✅ Set up alerting for critical metrics
- ✅ Review audit logs weekly
- ✅ Keep log retention policies current

## Related Documentation

- [Daily Operations](daily-operations.md)
- [Backups and Restore](backups-and-restore.md)
- [Runbooks](runbooks.md)

