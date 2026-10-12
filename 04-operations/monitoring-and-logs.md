# Monitoring and Logs

**Audience**: Operations Administrators  
**Prerequisites**: Kleidia deployed  
**Outcome**: Understand monitoring and log management

## Monitoring Overview

Kleidia provides multiple monitoring points for system health, performance, and security.

## Health Monitoring

### Application Health Endpoints

#### Backend Health

```bash
# Health check endpoint
curl https://kleidia.example.com/api/health

# Response:
{
  "status": "healthy",
  "service": "Kleidia"
}
```

#### Component Health Checks

```bash
# Database health
curl https://kleidia.example.com/api/admin/system/database

# OpenBao (Vault) health
curl https://kleidia.example.com/api/admin/system/openbao
```

### Kubernetes Health

```bash
# Pod health
kubectl get pods -n kleidia

# Service health
kubectl get services -n kleidia

# Resource health
kubectl top pods -n kleidia
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
kubectl logs -f deployment/backend -n kleidia

# Frontend logs
kubectl logs -f deployment/frontend -n kleidia

# Database logs
kubectl logs -f kleidia-db-1 -n kleidia

# OpenBao logs
kubectl logs -f kleidia-platform-openbao-0 -n kleidia
```

### Log Levels

- **INFO**: General informational messages
- **WARN**: Warning messages
- **ERROR**: Error messages

**Note**: DEBUG level logs are available for troubleshooting but not typically needed for normal operations.

### Log Filtering

```bash
# Filter by level
kubectl logs deployment/backend -n kleidia | grep -i error

# Filter by time
kubectl logs deployment/backend -n kleidia --since=1h

# Filter by component
kubectl logs deployment/backend -n kleidia | grep -i vault

# Filter by user
kubectl logs deployment/backend -n kleidia | grep "user_id=123"
```

## Audit Logging

### Audit Log Access

```bash
# Via web interface
# Navigate to Admin → Audit Logs

# Via API
curl https://kleidia.example.com/api/admin/audit-logs \
  -H "Authorization: Bearer <admin-token>"

# Filter by date range
curl "https://kleidia.example.com/api/admin/audit-logs?start=2025-01-01&end=2025-01-31" \
  -H "Authorization: Bearer <admin-token>"
```

### Audit Log Types

- **Authentication**: Login, logout, failed attempts
- **Device Operations**: Registration, PIN/PUK changes, certificate operations
- **Certificate Install** (2.5.0+): `piv_certificate_install` per slot with the install result (`installed`, `unverified`, `failed`, `mismatch`, `unconfirmed`), certificate serial and operation ID
- **Secret Access** (2.5.0+): `piv_secrets_read` and `piv_secrets_write` for every read and write of stored PIV secrets (PIN, management key). Details name the fields only, never their values, plus the YubiKey serial, the operation ID and whether an admin acted on another user's key
- **PUK Scrub** (2.5.0+): one `piv_puk_escrow_scrub` summary row when the startup scrub removed previously stored PUKs or failed for a YubiKey
- **Administrative**: User management, policy changes
- **Security Events**: Permission denials, suspicious activity

## Performance Monitoring

### Resource Metrics

```bash
# CPU and memory usage
kubectl top pods -n kleidia

# Node resources
kubectl top nodes

# Disk usage
df -h

# Docker disk usage
docker system df
```

### Application Metrics (Prometheus)

Since 2.5.0 the backend exports Prometheus counters for its security-relevant PIV events. It does not export request latency, request rate or database metrics.

- **Endpoint**: `GET /metrics` (Prometheus text format) on the backend's own metrics port, `METRICS_PORT`, default **9100** (`0` disables it). Plain HTTP, no authentication.
- **Not on the API or probe port**: the API ports (8080, 8443), the probe port (9000) and the ingress do not serve `/metrics`, and port 9100 is not on the NodePort `backend` Service.
- **Service**: the `kleidia-services` chart renders the ClusterIP Service `backend-metrics` (`backend.metrics.service.enabled`, default `true`) with port `metrics` → 9100. Scrape that Service.
- **Per pod**: every backend replica keeps its own in-memory counters, starting at zero when the pod starts. Aggregate with `sum` over `rate()`/`increase()`.
- **No identifiers in labels**: labels are bounded enums. Who did what is in the audit log; the metrics say how often.

| Metric | Labels | Counts |
|---|---|---|
| `kleidia_piv_certificates_issued_total` | `slot`, `flow` | PIV certificates signed by the PKI |
| `kleidia_piv_certificate_issuance_failures_total` | `slot`, `reason` | PIV certificate requests refused or failed before signing |
| `kleidia_piv_attestation_total` | `slot`, `result` | Attestation outcome per signing request (`verified`, `unverified`, `refused`) |
| `kleidia_piv_certificate_install_total` | `slot`, `result` | Outcome of writing an issued certificate to the YubiKey (`installed`, `unverified`, `failed`, `mismatch`, `unconfirmed`) |
| `kleidia_piv_secret_access_total` | `op`, `kind` | Reads and writes of stored PIV secrets (`op`: `read`/`write`; `kind`: `user`/`admin`) |

`flow` is `sign_all` (self-service, all slots), `sign_slot` (admin, one slot) or `csr_sign` (single CSR). For the install results, see [Certificate Install Verification](../02-security/certificates-and-pki.md#certificate-install-verification).

**Prometheus Operator** (needs the `monitoring.coreos.com` CRDs):

```yaml
# kleidia-services values
backend:
  metrics:
    serviceMonitor:
      enabled: true
      labels:
        release: kube-prometheus-stack   # whatever your Prometheus serviceMonitorSelector matches
      interval: 30s
      scrapeTimeout: 10s
```

**Plain Prometheus**: use `kubernetes_sd_configs` with `role: endpoints` and keep the Service `backend-metrics`, port `metrics`. Keep the `namespace` label; the example alerts select on it. For annotation-based discovery, set `backend.metrics.service.annotations: {prometheus.io/scrape: "true", prometheus.io/port: "9100"}`.

**Network access**: the platform chart's `backend-ingress-policy` NetworkPolicy admits all ingress to backend pods. If you tighten it, allow your Prometheus namespace on TCP 9100.

Example queries:

```promql
# Certificates issued per slot and flow, last 24 hours
sum by (slot, flow) (increase(kleidia_piv_certificates_issued_total[24h]))

# Why requests are refused, last hour
sum by (slot, reason) (increase(kleidia_piv_certificate_issuance_failures_total[1h]))

# Card install outcomes, last 7 days
sum by (result) (increase(kleidia_piv_certificate_install_total[7d]))

# Administrators reading other users' stored PIV secrets, last hour
sum(increase(kleidia_piv_secret_access_total{op="read", kind="admin"}[1h]))
```

## Alerting

### Key Metrics to Monitor

1. **Pod Status**: Pods should be Running
2. **Resource Usage**: CPU/Memory should be below limits
3. **Error Rates**: Error rates should be low
4. **Certificate Expiration**: Certificates should not expire soon
5. **Disk Space**: Disk usage should be below 85%
6. **Database Connections**: Connection pool usage

### PIV Issuance Alerts (PrometheusRule)

The `kleidia-services` chart can install example alerts as a `PrometheusRule` (off by default, needs the Prometheus Operator CRDs):

```yaml
# kleidia-services values
backend:
  metrics:
    prometheusRule:
      enabled: true
      labels:
        release: kube-prometheus-stack   # whatever your Prometheus ruleSelector matches
      issuanceFailureRatio: 0.2
      issuanceFailureMinCount: 3
```

| Alert | Severity | Fires when |
|---|---|---|
| `KleidiaPIVCertificateInstallFailed` | critical | any `failed` or `mismatch` install result in the last 15 minutes |
| `KleidiaPIVCertificateInstallUnconfirmed` | warning | any `unconfirmed` install result in the last hour |
| `KleidiaPIVIssuanceFailureRatioHigh` | warning | failures / (failures + issued) over 15 minutes above `issuanceFailureRatio`, with at least `issuanceFailureMinCount` failures, for 5 minutes |
| `KleidiaPIVAttestationRefused` | warning | any `refused` attestation in the last 15 minutes |

What to do:

- **Install failed / mismatch**: the user has no working certificate in that slot; Kleidia revoked the one it issued. Find the `piv_certificate_install` audit rows (they carry the operation ID) and have the user issue the slot again. Repeated `mismatch` for one key can mean something else writes to the card.
- **Install unconfirmed**: the certificate stays valid. Check the key's slots with the user; reissue only if the card is empty.
- **Issuance failure ratio**: break it down by `reason`. A burst of `pki_error` usually points at OpenBao/Vault or the PKI role.
- **Attestation refused**: an agent older than 2.4.3 with `backend.pivAttestation.enforce: true`, or an attestation for another key, YubiKey or slot. The `generate_certificate_refused`, `generate_all_certificates_refused` and `admin_sign_slot_csr_refused` audit rows name the user and the reason.

### Setting Up Other Alerts

Beyond the PIV issuance alerts above, you can:

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
kubectl logs deployment/backend -n kleidia --since=1h | \
  grep -i error | wc -l

# Group errors by type
kubectl logs deployment/backend -n kleidia --since=1h | \
  grep -i error | sort | uniq -c
```

#### Slow Queries

```bash
# Check PostgreSQL slow queries
kubectl exec -it kleidia-db-1 -n kleidia -- \
  psql -U kleidiauser -d kleidia -c "
    SELECT query, calls, total_time, mean_time
    FROM pg_stat_statements
    ORDER BY mean_time DESC
    LIMIT 10;
  "
```

#### Failed Authentications

```bash
# Check failed login attempts
curl "https://kleidia.example.com/api/admin/audit-logs?action=login&status=failed" \
  -H "Authorization: Bearer <admin-token>"
```

## Related Documentation

- [Daily Operations](daily-operations.md)
- [Backups and Restore](backups-and-restore.md)
- [Runbooks](runbooks.md)

