# Configuration Management

**Audience**: Operations Administrators  
**Prerequisites**: Helm installed, understanding of Kubernetes configuration  
**Outcome**: Understand how to configure Kleidia deployment

## Overview

Kleidia configuration is managed through Helm values files. Configuration can be provided via:

1. **values.yaml files** (recommended for production)
2. **Command-line overrides** (for quick changes)
3. **Environment-specific files** (dev, staging, production)

## Configuration Structure

### Global Configuration

```yaml
global:
  domain: kleidia.example.com          # Your domain name
  namespace: kleidia                    # Kubernetes namespace
```

### Backend Configuration

```yaml
backend:
  replicas: 2                           # Number of backend replicas
  image:
    repository: kleidia-backend
    tag: latest                          # Image tag
  service:
    nodePort: 32570                     # NodePort for external load balancer
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

### Frontend Configuration

```yaml
frontend:
  replicas: 2                           # Number of frontend replicas
  image:
    repository: kleidia-frontend
    tag: latest                          # Image tag
  service:
    nodePort: 30805                     # NodePort for external load balancer
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
```

### OpenBao (Vault) Configuration

```yaml
openbao:
  enabled: true
  server:
    standalone:
      enabled: true
    dataStorage:
      enabled: true
      size: 10Gi                        # Storage size
    auditStorage:
      enabled: true
      size: 10Gi                        # Audit log storage
  pki:
    mode: root                          # PKI mode (root or intermediate)
    rootCA:
      commonName: "Kleidia Root CA"
      ttl: "87600h"                     # 10 years
```

### PostgreSQL Configuration

```yaml
postgres:
  enabled: true
  version: "18"                         # PostgreSQL version
  database: kleidia                     # Database name
  username: kleidiauser                  # Database user
  storage:
    size: 10Gi                          # Storage size
```

### Database TLS Configuration (CloudNativePG)

> ⚠️ **Kubernetes Version Requirement**: Database TLS is only available when using CloudNativePG, which requires **Kubernetes 1.32+**. On older Kubernetes versions, the legacy PostgreSQL StatefulSet is used, which does not support TLS (connections remain unencrypted but within the internal Kubernetes network).

When using CloudNativePG (K8s 1.32+), enable TLS for secure database connections:

```yaml
database:
  tls:
    enabled: true                       # Enable TLS for database connections
    sslMode: verify-full                # SSL verification mode
    clientCertSecret: kleidia-db-client-tls  # Client certificate secret
    caSecret: kleidia-db-ca             # CA certificate secret
```

**SSL Modes**:
- `disable`: No SSL (not recommended)
- `require`: Use SSL but don't verify certificates
- `verify-ca`: Verify the server certificate is signed by a trusted CA
- `verify-full`: Verify certificate and that the hostname matches (recommended)

**Certificate Secrets**:
The TLS certificates are automatically provisioned by cert-manager when using CloudNativePG:
- `kleidia-db-client-tls`: Client certificate and key for backend authentication
- `kleidia-db-ca`: CA certificate for server verification

**Verification**:
To verify TLS is working, check the PostgreSQL connection:

```bash
kubectl exec kleidia-db-1 -n kleidia -c postgres -- psql -U kleidiauser -d kleidia -c \
  "SELECT datname, ssl, version, cipher FROM pg_stat_ssl JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid WHERE datname = 'kleidia';"
```

Expected output shows `ssl = t` (true) with TLS 1.3 and AES-256 encryption.

## Common Configuration Scenarios

### Production Deployment

```yaml
global:
  domain: kleidia.production.example.com
  namespace: kleidia-prod
  registry:
    host: registry.production.example.com:5000

backend:
  replicas: 3                           # Higher availability
  image:
    tag: v2.2.0                          # Specific version
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

frontend:
  replicas: 2
  image:
    tag: v2.2.0

postgres:
  storage:
    size: 50Gi                          # Larger storage

openbao:
  server:
    dataStorage:
      size: 20Gi
    auditStorage:
      size: 20Gi
```

### Development Deployment

```yaml
global:
  domain: kleidia.dev.example.com
  namespace: kleidia-dev

backend:
  replicas: 1                           # Single replica for dev
  image:
    tag: latest

frontend:
  replicas: 1
  image:
    tag: latest

postgres:
  storage:
    size: 5Gi                           # Smaller storage

openbao:
  server:
    dataStorage:
      size: 5Gi
```

## Environment Variables

### Backend Environment Variables

Backend configuration via environment variables (set in Helm values):

```yaml
backend:
  env:
    - name: DATABASE_URL
      value: "postgresql://kleidiauser:password@postgres-cluster:5432/kleidia"
    - name: VAULT_ADDR
      value: "http://kleidia-platform-openbao:8200"
    - name: VAULT_AUTH_METHOD
      value: "approle"
    - name: JWT_SECRET_KEY
      valueFrom:
        secretKeyRef:
          name: kleidia-secrets
          key: jwt-secret
```

### OIDC Environment Variables

OIDC is primarily configured through the **Admin UI** (settings stored in the database). Environment variables provide initial/fallback values and control advanced settings not exposed in the UI.

**Core OIDC settings** (UI-configurable, env vars used as initial values):

| Variable | Description | Default |
|----------|-------------|---------|
| `OIDC_ENABLED` | Enable OIDC authentication | `false` |
| `OIDC_PROVIDER` | Provider type: `keycloak`, `azure_entra`, `google`, `okta`, `generic` | `generic` |
| `OIDC_ISSUER` | Issuer URL (base URL of OIDC provider) | — |
| `OIDC_DISCOVERY_ENDPOINT` | Full discovery URL override (optional) | — |
| `OIDC_CLIENT_ID` | OAuth 2.0 client ID | — |
| `OIDC_CLIENT_SECRET` | OAuth 2.0 client secret | — |
| `OIDC_REDIRECT_URI` | Authorization callback URL | — |
| `OIDC_SCOPES` | Space-separated scopes | `openid profile email` |
| `OIDC_DISABLE_LOCAL_LOGIN` | Hide local login when OIDC enabled | `false` |

**Advanced settings** (env vars only, not in Admin UI):

| Variable | Description | Default |
|----------|-------------|---------|
| `OIDC_PKCE_ENABLED` | Enable PKCE (RFC 7636) | `true` |
| `OIDC_STATE_VALIDATION` | Validate OAuth state parameter | `true` |
| `OIDC_NONCE_VALIDATION` | Validate OpenID nonce | `true` |
| `OIDC_RESPONSE_TYPE` | OAuth response type | `code` |
| `OIDC_RESPONSE_MODE` | Response mode (`query`, `fragment`) | `query` |
| `OIDC_PROMPT` | Prompt behavior | `consent` |
| `OIDC_ACCESS_TYPE` | Access type | `offline` |
| `OIDC_TOKEN_ENDPOINT_AUTH_METHOD` | Client auth method | `client_secret_post` |
| `OIDC_SKIP_TLS_VERIFY` | Skip TLS verification (non-production only) | `false` |
| `OIDC_CA_CERT_FILE` | Custom CA certificate file path | — |
| `OIDC_MFA_REQUIRED` | Require MFA | `false` |
| `OIDC_CONDITIONAL_ACCESS` | Enable conditional access | `false` |

See [Admin Guide - OIDC Configuration](../05-using-the-system/admin-guide.md) for provider-specific settings and setup instructions.

### Frontend Environment Variables

```yaml
frontend:
  env:
    - name: API_BASE_URL
      value: "https://kleidia.example.com/api"
    - name: WS_BASE_URL
      value: "wss://kleidia.example.com"
```

## Secrets Management

### Automatic Secret Generation

Helm charts automatically generate secrets:

- JWT signing keys
- Database passwords
- Vault AppRole credentials
- Encryption keys

### Custom Secrets

To use custom secrets:

```yaml
backend:
  secrets:
    jwtSecret:
      secretName: custom-jwt-secret
      secretKey: jwt-key
    vaultRoleId:
      secretName: custom-vault-secret
      secretKey: role-id
    vaultSecretId:
      secretName: custom-vault-secret
      secretKey: secret-id
```

## Storage Configuration

### Storage Classes

```yaml
storage:
  className: local-path                 # Storage class name
  localPath:
    enabled: true
    path: /opt/local-path-provisioner
```

### Persistent Volume Sizes

```yaml
postgres:
  storage:
    size: 10Gi                          # Database storage

openbao:
  server:
    dataStorage:
      size: 10Gi                        # Vault data storage
    auditStorage:
      size: 10Gi                        # Audit log storage
```

## Resource Limits

### Backend Resources

```yaml
backend:
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

### Frontend Resources

```yaml
frontend:
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
```

## Network Configuration

### NodePort Services

```yaml
backend:
  service:
    type: NodePort
    nodePort: 32570                     # Static NodePort

frontend:
  service:
    type: NodePort
    nodePort: 30805                     # Static NodePort
```

### Service Annotations

```yaml
backend:
  service:
    annotations:
```

## Applying Configuration

### Using values.yaml

```bash
# Create values file
cat > my-values.yaml <<EOF
global:
  domain: kleidia.example.com
backend:
  replicas: 3
EOF

# Install with values file
helm install kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --values my-values.yaml
```

### Using Command-Line Overrides

```bash
helm install kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set backend.replicas=3
```

### Updating Configuration

```bash
# Update values file
nano my-values.yaml

# Upgrade with new values
helm upgrade kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --values my-values.yaml
```

## Configuration Validation

### Dry Run

```bash
# Validate configuration without installing
helm install kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --values my-values.yaml \
  --dry-run
```

### Template Rendering

```bash
# Render templates to see final configuration
helm template kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --values my-values.yaml
```

## Best Practices

### Configuration Management

- ✅ Use version-controlled values files
- ✅ Separate values files per environment
- ✅ Document all custom configurations
- ✅ Test configuration changes in dev first
- ✅ Use specific image tags in production

### Security

- ✅ Never commit secrets to version control
- ✅ Use Kubernetes secrets for sensitive data
- ✅ Rotate secrets regularly
- ✅ Use least-privilege access

### Performance

- ✅ Set appropriate resource limits
- ✅ Configure storage sizes appropriately
- ✅ Use multiple replicas for high availability
- ✅ Monitor resource usage

## Related Documentation

- [Helm Installation](helm-install.md)
- [Prerequisites](prerequisites.md)
- [Vault Setup](vault-setup.md)
- [Troubleshooting](troubleshooting.md)

