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

- JWT signing keys
- Encryption keys
- Database passwords

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
  capabilities = ["list", "read"]
}

# Application secrets
path "secret/data/kleidia/*" {
  capabilities = ["create", "read", "update"]
}
```

### Authentication

Backend authenticates to Vault using **AppRole**:

- **Role ID**: Stored in Kubernetes secret
- **Secret ID**: Stored in Kubernetes secret
- **Token TTL**: Configurable (default 1 hour)
- **Token Renewal**: Automatic renewal by backend

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
   - Configures Kubernetes authentication
   - Creates backend policies

#### Bootstrap Keys Security Model

**Initialization Keys Generated**:
- **Root Token**: Master administrative token
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

**Security Rationale**:
- Keys must be displayed to admin for disaster recovery scenarios
- Keys should not remain in cluster indefinitely (reduces attack surface)
- Manual deletion ensures admin has secured the keys
- One-time display prevents repeated exposure

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
4. **Create Policies**: Define backend and admin policies
5. **Configure AppRole**: Set up AppRole authentication

### Production Configuration

For production deployments:

- **Persistent Storage**: Use persistent volumes
- **Auto-Unseal**: Configure static key unsealing
- **High Availability**: Use Raft storage backend (optional)
- **Audit Logging**: Enable Vault audit logs

## Security Considerations

### Secret Protection

- **Encryption at Rest**: Vault encrypts all secrets
- **Access Control**: Policies restrict secret access
- **Audit Logging**: All secret access logged
- **Versioning**: Secret versions for rollback

### Operational Security

- **Unseal Keys**: Store securely (use auto-unseal in production)
- **Policy Review**: Regular policy review and updates
- **Access Monitoring**: Monitor secret access patterns

## Troubleshooting

### Common Issues

1. **Vault Unsealed**: Check Vault status, unseal if needed
2. **Policy Denied**: Verify backend policy permissions
3. **Secret Not Found**: Check secret path and serial number
4. **Authentication Failed**: Verify AppRole credentials

## Related Documentation

- [Security Overview](security-overview.md)
- [Certificates and PKI](certificates-and-pki.md)
- [Deployment Guide](../03-deployment/vault-setup.md)

