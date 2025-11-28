# Vault and Secrets Management

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Understanding of secrets management  
**Outcome**: Understand how Kleidia uses Vault for secret storage

## Overview

Kleidia uses OpenBao as the central secrets management system. All sensitive data is stored in OpenBao, not in the database.

## Vault Architecture

### Deployment

- **Location**: Kubernetes cluster (StatefulSet)
- **Mode**: Production mode with persistent storage
- **Storage**: File-based storage (can use Raft for HA)
- **Auto-Unseal**: Static key unsealing (no manual unseal)

### Vault Components

#### KV v2 Secrets Engine
- **Mount Path**: `yubikeys/`
- **Purpose**: Store YubiKey secrets (PINs, PUKs, management keys)
- **Versioning**: Enabled for secret versioning
- **Encryption**: AES-256-GCM encryption at rest

#### PKI Secrets Engine
- **Mount Path**: `pki/`
- **Purpose**: Certificate Authority for YubiKey certificates
- **Root CA**: 10-year self-signed certificate
- **Roles**: Configurable PKI roles for certificate signing

## Secret Storage

### YubiKey Secrets

Secrets stored at path: `yubikeys/data/{serial}/secrets`

**Structure**:
```json
{
  "pin": "123456",
  "puk": "12345678",
  "management_key": "010203040506070801020304050607080102030405060708"
}
```

**Access**:
- Backend retrieves secrets via Vault API
- Secrets encrypted at rest by Vault
- Secrets encrypted in transit (RSA-OAEP) to agent

### Application Secrets

Application secrets stored in separate Vault paths:

- JWT signing keys (`secret/data/kleidia/jwt-secret`)
- Encryption keys (`secret/data/kleidia/encryption-key`)
- Database passwords (`secret/data/kleidia/database`)
- License data (`secret/data/kleidia/licenses/*`)

## Authentication Model

Kleidia uses **AppRole authentication** with dedicated roles for each component, following the principle of least privilege.

### AppRole Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Helm Charts   │     │ Backend Service │     │ License Service │
│                 │     │                 │     │                 │
│  helm-admin     │     │ backend-openbao │     │ license-openbao │
│    AppRole      │     │    AppRole      │     │    AppRole      │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                         OpenBao (Vault)                          │
│                                                                  │
│  • Audit logging enabled                                        │
│  • Least-privilege policies                                     │
│  • Separation of concerns                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Backend Authentication

The backend service authenticates using the `backend-openbao` AppRole:

- **Role ID**: Stored in Kubernetes secret `openbao-backend-approle`
- **Secret ID**: Stored in Kubernetes secret `openbao-backend-approle`
- **Token TTL**: 1 hour (auto-renewed)
- **Token Max TTL**: 4 hours

**Permissions**:
- Read/write YubiKey secrets
- PKI operations (sign, issue, revoke)
- Read application secrets (JWT, encryption, database)
- **Cannot** access license secrets

### License Service Authentication

The license service authenticates using the `license-openbao` AppRole:

- **Role ID**: Stored in Kubernetes secret `openbao-license-approle`
- **Secret ID**: Stored in Kubernetes secret `openbao-license-approle`
- **Token TTL**: 1 hour (auto-renewed)
- **Token Max TTL**: 4 hours

**Permissions**:
- Read/write license secrets
- **Cannot** access YubiKey secrets
- **Cannot** access backend application secrets

### Helm Admin Authentication

For Helm upgrades after initial installation, the `helm-admin` AppRole is used:

- **Role ID**: Stored in Kubernetes secret `openbao-helm-approle`
- **Secret ID**: Stored in Kubernetes secret `openbao-helm-approle`
- **Token TTL**: 1 hour

**Permissions**:
- Manage auth method configurations
- Update policies
- Configure PKI roles
- **Cannot** read any secrets
- **Cannot** create new secrets engines

## Vault Policies

### Backend Policy (`kleidia-backend`)

```hcl
# PKI operations
path "pki/sign/*" {
  capabilities = ["create", "read", "update"]
}

path "pki/issue/*" {
  capabilities = ["create", "read", "update"]
}

path "pki/cert/ca" {
  capabilities = ["read"]
}

path "pki/revoke" {
  capabilities = ["update"]
}

# YubiKey secrets
path "yubikeys/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "yubikeys/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

# Application secrets (specific paths only)
path "secret/data/kleidia/jwt-secret" {
  capabilities = ["create", "read", "update"]
}

path "secret/data/kleidia/encryption-key" {
  capabilities = ["create", "read", "update"]
}

path "secret/data/kleidia/database" {
  capabilities = ["create", "read", "update"]
}

# Explicit deny for license secrets
path "secret/data/kleidia/licenses/*" {
  capabilities = ["deny"]
}
```

### License Service Policy (`license-service`)

```hcl
# License secrets only
path "secret/data/kleidia/licenses/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/kleidia/licenses/*" {
  capabilities = ["list", "read", "delete"]
}

# Explicit deny for backend secrets
path "yubikeys/*" {
  capabilities = ["deny"]
}

path "secret/data/kleidia/jwt-secret" {
  capabilities = ["deny"]
}
```

## Secret Lifecycle

### Secret Creation

1. User registers YubiKey with PIN/PUK/management key
2. Frontend sends secrets to backend
3. Backend stores secrets in Vault: `yubikeys/data/{serial}/secrets`
4. Vault encrypts secrets at rest
5. Backend confirms storage

### Secret Retrieval

1. User requests YubiKey operation
2. Frontend requests secrets: `GET /api/yubikey/{serial}/secrets`
3. Backend authenticates to Vault (AppRole)
4. Backend retrieves secrets from Vault
5. Backend encrypts secrets with agent public key (RSA-OAEP)
6. Backend returns encrypted secrets to frontend

### Secret Rotation

- **Manual Rotation**: User updates secrets via web interface
- **Versioning**: OpenBao maintains secret versions for rollback

## Vault Configuration

### OpenBao Initialization and Bootstrap

During initial Helm deployment, OpenBao (Vault) is automatically initialized:

#### Automatic Initialization Process

1. **OpenBao Pod Starts**: StatefulSet creates the OpenBao pod
2. **Auto-Initialization**: Helm hook job initializes OpenBao:
   - Generates root token
   - Generates 3 recovery keys (for static seal)
   - Stores keys temporarily in Kubernetes secret `openbao-init-keys`
3. **Configuration Applied**: 
   - Enables KV v2 secrets engine at `yubikeys/`
   - Enables PKI secrets engine at `pki/`
   - Enables AppRole authentication
   - Creates AppRoles for backend, license service, and Helm admin
   - Creates policies with least-privilege access
   - Enables audit logging

#### Bootstrap Keys Security Model

**Initialization Keys Generated**:
- **Root Token**: Master administrative token (deleted after bootstrap)
- **Recovery Keys (3)**: Used for emergency recovery operations
- **Unseal Key**: (Legacy compatibility, not used with static seal)

**Key Storage Flow**:

1. **Temporary Storage** (During Installation):
   - Keys stored in Kubernetes secret: `openbao-init-keys` in namespace
   - Secret contains: `root-token`, `recovery-key-1`, `recovery-key-2`, `recovery-key-3`
   - Only accessible to backend service account with specific RBAC permissions

2. **First Admin Login** (Key Retrieval):
   - Admin user logs in for first time
   - Backend detects `openbao-init-keys` secret exists
   - **Modal automatically displays** keys to admin user
   - Admin must copy and securely store keys
   - Admin confirms keys are saved

3. **Secure Deletion** (Post-Confirmation):
   - Backend deletes `openbao-init-keys` secret from Kubernetes
   - Keys no longer exist in cluster
   - Action logged in audit trail
   - Keys only exist in admin's secure storage

4. **Post-Deletion Operations**:
   - Helm upgrades use `helm-admin` AppRole (stored in `openbao-helm-approle`)
   - Backend uses `backend-openbao` AppRole (stored in `openbao-backend-approle`)
   - License service uses `license-openbao` AppRole (stored in `openbao-license-approle`)
   - No root token required for normal operations

**Security Rationale**:
- Keys must be displayed to admin for disaster recovery scenarios
- Keys should not remain in cluster indefinitely (reduces attack surface)
- Manual deletion ensures admin has secured the keys
- One-time display prevents repeated exposure
- AppRoles enable continued operation without root token

#### RBAC Permissions for Bootstrap Keys

Backend service account has scoped permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backend-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["openbao-init-keys"]
  verbs: ["get", "delete"]
```

**Security Features**:
- Scoped to specific secret name only
- Only `get` and `delete` verbs (no create/update)
- Namespace-scoped (not cluster-wide)
- Only backend pod can access

### Post-Initialization Setup

After bootstrap keys are handled, Vault is fully configured:

1. **Enable KV v2**: `vault secrets enable -path=yubikeys kv-v2`
2. **Enable PKI**: `vault secrets enable pki`
3. **Generate Root CA**: Create self-signed root certificate
4. **Create Policies**: Define backend, license, and admin policies
5. **Configure AppRoles**: Set up AppRole authentication for all components
6. **Enable Audit Logging**: File-based audit device at `/openbao/audit/audit.log`

### Production Configuration

For production deployments:

- **Persistent Storage**: Use persistent volumes
- **Auto-Unseal**: Configure static key unsealing
- **High Availability**: Use Raft storage backend (optional)
- **Audit Logging**: Enabled by default

## Audit Logging

All OpenBao operations are logged for security and compliance:

### Audit Log Configuration

- **Device Type**: File
- **Path**: `/openbao/audit/audit.log`
- **Format**: JSON (one entry per line)

### Logged Operations

- Authentication attempts (success/failure)
- Secret read/write/delete operations
- Policy changes
- Configuration changes
- Token creation/renewal/revocation

### Viewing Audit Logs

```bash
# Get OpenBao pod
VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=openbao -n kleidia -o jsonpath='{.items[0].metadata.name}')

# View recent logs
kubectl exec -it $VAULT_POD -n kleidia -- tail -100 /openbao/audit/audit.log

# Search for specific paths
kubectl exec -it $VAULT_POD -n kleidia -- grep "yubikeys/data" /openbao/audit/audit.log
```

## Security Considerations

### Secret Protection

- **Encryption at Rest**: Vault encrypts all secrets
- **Access Control**: Policies restrict secret access per component
- **Audit Logging**: All secret access logged
- **Versioning**: Secret versions for rollback

### Privilege Separation

| Component | YubiKey Secrets | License Secrets | PKI Operations | Config Changes |
|-----------|----------------|-----------------|----------------|----------------|
| Backend | ✅ Full | ❌ Denied | ✅ Full | ❌ No |
| License Service | ❌ Denied | ✅ Full | ❌ No | ❌ No |
| Helm Admin | ❌ No Access | ❌ No Access | ✅ Roles only | ✅ Limited |

### Operational Security

- **Root Token**: Deleted after initial bootstrap
- **AppRole Secrets**: Stored in Kubernetes secrets
- **Policy Review**: Regular policy review and updates
- **Access Monitoring**: Monitor secret access patterns via audit logs

## Troubleshooting

### Common Issues

1. **Vault Unsealed**: Check Vault status, unseal if needed
2. **Policy Denied**: Verify AppRole has correct policy attached
3. **Secret Not Found**: Check secret path and serial number
4. **Authentication Failed**: Verify AppRole credentials in Kubernetes secret

### Checking AppRole Authentication

```bash
# Get OpenBao pod
VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=openbao -n kleidia -o jsonpath='{.items[0].metadata.name}')

# Check AppRole is enabled
kubectl exec -it $VAULT_POD -n kleidia -- bao auth list | grep approle

# Check backend AppRole exists
kubectl exec -it $VAULT_POD -n kleidia -- bao read auth/approle/role/backend-openbao

# Check Kubernetes secrets exist
kubectl get secret openbao-backend-approle -n kleidia
kubectl get secret openbao-license-approle -n kleidia
kubectl get secret openbao-helm-approle -n kleidia
```

## Related Documentation

- [Security Overview](security-overview.md)
- [Certificates and PKI](certificates-and-pki.md)
- [Permissions and Policies](../06-reference/permissions-and-policies.md)
- [Deployment Guide](../03-deployment/vault-setup.md)
