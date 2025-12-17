# CRL (Certificate Revocation List) Configuration

This guide explains how to configure the Certificate Revocation List (CRL) endpoint for external system integration.

## Overview

When Kleidia issues certificates for YubiKeys, each certificate contains a CRL Distribution Point URL. External systems (Azure Entra ID, Bitbucket, Active Directory) use this URL to check if a certificate has been revoked.

```
Certificate issued by Kleidia:
├── Subject: CN=user@company.com
├── Key Usage: Digital Signature, Client Authentication
└── CRL Distribution Points:
    └── URI: https://kleidia.example.com/api/pki/crl  ← External systems fetch this
```

## Architecture

Kleidia's backend serves CRL requests with in-memory caching to minimize load on OpenBao:

```
External System                  Kleidia Backend                   OpenBao
(Entra ID, AD, etc.)                  │                              │
       │                              │                              │
       │  GET /api/pki/crl            │                              │
       │─────────────────────────────►│                              │
       │                              │                              │
       │                              │  Cache HIT?                  │
       │                              │  ├── Yes: Return cached CRL  │
       │                              │  └── No: Fetch from OpenBao  │
       │                              │         ─────────────────────►
       │                              │◄─────────────────────────────│
       │                              │  Cache CRL (1 hour TTL)      │
       │◄─────────────────────────────│                              │
       │        CRL (DER format)      │                              │
```

### Performance Characteristics

| Metric | Value |
|--------|-------|
| Cache TTL | 1 hour |
| Cache size | ~50KB (typical) |
| Response time (cache hit) | <1ms |
| Response time (cache miss) | 10-50ms |
| Memory overhead | Negligible |

## Configuration

### Automatic URL Detection

**No manual CRL URL configuration is needed.** Kleidia automatically derives the PKI URL from your domain configuration:

| Configuration | Resulting PKI URL |
|---------------|-------------------|
| `global.siteUrl: "https://kleidia.example.com"` | `https://kleidia.example.com/api/pki` |
| `global.domain: "kleidia.example.com"` | `https://kleidia.example.com/api/pki` |
| Neither set | Internal URL (not externally accessible) |

> **⚠️ Important**: The CRL URL is embedded in every issued certificate. Once certificates are issued, the URL cannot be changed without re-issuing all certificates.

### Standard Helm Configuration

Just set your domain during Helm install - PKI URLs are derived automatically:

```yaml
# In your values.yaml
global:
  domain: "kleidia.example.com"    # PKI URL auto-detected from this
  # OR
  siteUrl: "https://kleidia.example.com"  # Takes precedence if set
```

This automatically configures:
- **CRL URL**: `https://kleidia.example.com/api/pki/crl`
- **CA URL**: `https://kleidia.example.com/api/pki/ca`
- **CA Chain**: `https://kleidia.example.com/api/pki/ca_chain`

### Optional: Override PKI URL

Only needed if you want a different URL than `{siteUrl}/api/pki`:

```yaml
openbao:
  pki:
    urls:
      # Override auto-detected URL (rarely needed)
      externalBaseUrl: "https://pki.example.com/custom/path"
      crlExpiry: "24h"
```

### Load Balancer Configuration

Ensure your load balancer routes PKI endpoints to the Kleidia backend:

```
External Request                    Load Balancer                    Backend Service
       │                                  │                                │
       │  GET /api/pki/crl                │                                │
       │─────────────────────────────────►│                                │
       │                                  │  Route to backend:8080         │
       │                                  │───────────────────────────────►│
```

Example HAProxy configuration:

```haproxy
# Kleidia backend (includes PKI endpoints)
frontend kleidia_frontend
    bind *:443 ssl crt /etc/ssl/kleidia.pem
    
    # Route API requests (including /api/pki/*) to backend
    acl is_api path_beg /api
    use_backend kleidia_backend if is_api

backend kleidia_backend
    balance roundrobin
    server backend1 10.0.0.1:32570 check
    server backend2 10.0.0.2:32570 check
```

Example nginx Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kleidia-ingress
spec:
  rules:
  - host: kleidia.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8080
```

## Endpoints

### GET /api/pki/crl

Returns the Certificate Revocation List in DER format.

**Response:**
- Content-Type: `application/pkix-crl`
- Cache-Control: `public, max-age=3600`

**Headers:**
- `X-CRL-Cache`: `HIT` or `MISS` (indicates cache status)
- `X-CRL-Age`: Duration since last fetch (e.g., `5m30s`)

### GET /api/pki/ca

Returns the CA certificate in PEM format.

**Response:**
- Content-Type: `application/x-pem-file`
- Cache-Control: `public, max-age=86400`

### GET /api/pki/ca_chain

Returns the full CA chain in PEM format.

**Response:**
- Content-Type: `application/x-pem-file`
- Cache-Control: `public, max-age=86400`

### GET /api/pki/crl/status

Returns CRL cache status (for monitoring).

**Response:**
```json
{
  "cached": true,
  "size_bytes": 1234,
  "age": "15m30s",
  "expires_in": "44m30s",
  "fetched_at": "2025-12-18T10:00:00Z",
  "cache_ttl": "1h0m0s"
}
```

## Integration Examples

### Azure Entra ID (Certificate-Based Authentication)

1. Configure CRL URL in Helm values before deploying:
   ```yaml
   openbao:
     pki:
       urls:
         externalBaseUrl: "https://kleidia.example.com/api/pki"
   ```

2. Ensure the CRL is accessible via HTTP (Azure requirement):
   - Azure Entra ID requires CRL to be accessible over **HTTP** (not HTTPS)
   - Configure your load balancer to serve `/api/pki/crl` on port 80

3. Export CA certificate and import into Azure:
   ```bash
   curl -o ca.pem https://kleidia.example.com/api/pki/ca
   # Upload ca.pem to Azure Entra ID > Security > Certificate authorities
   ```

### Bitbucket Data Center (Code Signing)

1. Export CA chain:
   ```bash
   curl -o ca_chain.pem https://kleidia.example.com/api/pki/ca_chain
   ```

2. Import into Bitbucket:
   - Navigate to Administration > Security > Signing certificates
   - Click "Add certificate chain"
   - Paste the CA chain content

Bitbucket automatically fetches CRL updates every 24 hours.

### Windows Active Directory

1. Export CA certificate:
   ```bash
   curl -o kleidia-ca.pem https://kleidia.example.com/api/pki/ca
   ```

2. Convert to DER format and import:
   ```powershell
   certutil -decode kleidia-ca.pem kleidia-ca.crt
   certutil -addstore -enterprise -f "Root" kleidia-ca.crt
   ```

Windows caches CRL based on the `Next Update` field (typically 24 hours).

## Monitoring

### Health Check

Check CRL availability:

```bash
# Should return binary CRL data
curl -sf https://kleidia.example.com/api/pki/crl -o /dev/null && echo "CRL OK"

# Check cache status
curl -s https://kleidia.example.com/api/pki/crl/status | jq .
```

### Prometheus Metrics

Monitor CRL endpoint with standard HTTP metrics:

```yaml
# Example Prometheus scrape config
- job_name: 'kleidia-pki'
  metrics_path: /api/pki/crl/status
  static_configs:
    - targets: ['kleidia.example.com']
```

## Troubleshooting

### CRL Not Accessible Externally

**Symptoms:**
- Certificate validation fails in external systems
- "CRL fetch failed" errors in Entra ID / Bitbucket

**Solutions:**
1. Verify the external URL is correctly configured:
   ```bash
   curl -v https://kleidia.example.com/api/pki/crl
   ```

2. Check load balancer is routing to backend service

3. Ensure firewall allows inbound traffic on ports 80/443

### Azure Requires HTTP

**Symptoms:**
- Azure CRL validation fails despite HTTPS working

**Solution:**
Azure Entra ID requires CRL over HTTP (port 80). Configure your load balancer:

```haproxy
# Add HTTP frontend for CRL only
frontend kleidia_http
    bind *:80
    acl is_crl path_beg /api/pki/crl
    use_backend kleidia_backend if is_crl
    # Redirect all other HTTP to HTTPS
    redirect scheme https if !is_crl
```

### Certificates Have Wrong CRL URL

**Symptoms:**
- Issued certificates point to internal Kubernetes URL
- External systems cannot reach CRL

**Solution:**
The `global.domain` or `global.siteUrl` was not set before certificate issuance. You must:

1. Update Helm values with correct `global.domain` or `global.siteUrl`
2. Reinstall OpenBao (or manually reconfigure PKI URLs)
3. Re-enroll affected YubiKeys to get new certificates

## Traffic Estimation

For capacity planning, CRL traffic is minimal due to caching:

| Scenario | Daily CRL Requests | Bandwidth/Day |
|----------|-------------------|---------------|
| 1,000 users | ~1,000 | ~50 MB |
| 10,000 users | ~10,000 | ~500 MB |
| 100,000 users | ~100,000 | ~5 GB |

Notes:
- Each workstation/client fetches CRL once per 24 hours (cached)
- Shared workstations reduce request count significantly
- CRL size is typically 10-50 KB

