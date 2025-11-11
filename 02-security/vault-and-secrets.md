# Vault and Secrets Management

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Understanding of secrets management  
**Outcome**: Understand how YubiMgr uses Vault for secret storage

## Overview

YubiMgr uses OpenBao as the central secrets management system. All sensitive data is stored in OpenBao, not in the database.

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

### Backend Policy (`yubimgr-backend`)

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
path "secret/data/yubimgr/*" {
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

### Initial Setup

Vault is automatically configured during Helm deployment:

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

