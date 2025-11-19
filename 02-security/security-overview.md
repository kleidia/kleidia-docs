# Security Overview

**Audience**: Security Professionals, Operations Administrators  
**Prerequisites**: Understanding of security concepts  
**Outcome**: Understand Kleidia's security model and threat mitigation

## Security Principles

Kleidia is designed with security-first principles:

1. **Defense in Depth**: Multiple security layers
2. **Zero Standing Access**: No valid credentials for logged-out users
3. **Local-Only Operations**: Sensitive operations on workstations, not servers
4. **Encryption Everywhere**: All sensitive data encrypted in transit and at rest
5. **Audit Everything**: Complete logging of all operations

## Threat Model

### Threats Addressed

#### 1. Credential Theft
- **Threat**: Attackers steal PINs, PUKs, or management keys
- **Mitigation**: 
  - Secrets stored in Vault (encrypted at rest)
  - RSA-OAEP encryption for all transmission
  - Ephemeral agent keys (expire with sessions)
  - No plaintext secrets in database

#### 2. Session Hijacking
- **Threat**: Attackers hijack user sessions
- **Mitigation**:
  - JWT tokens with expiration
  - Session-bound agent keys
  - Automatic expiration on logout
  - No session transfer between workstations

#### 3. Man-in-the-Middle Attacks
- **Threat**: Attackers intercept network traffic
- **Mitigation**:
- HTTPS/TLS for all external communication
- RSA-OAEP encryption for sensitive data
- Localhost-only agent communication

#### 4. Workstation Compromise
- **Threat**: Attackers compromise user workstation
- **Mitigation**:
  - Ephemeral agent keys (new keys on restart)
  - Session-bound keys (expire with logout)
  - Private keys never persisted to disk
  - YubiKey hardware security (private keys never leave device)

#### 5. Server Compromise
- **Threat**: Attackers compromise backend server
- **Mitigation**:
  - Vault encryption (secrets encrypted at rest)
  - No agent private keys on server
  - Database encryption (if configured)
  - RBAC for admin operations

## Security Architecture

### Encryption Layers

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: HTTPS/TLS                                      │
│ - Browser ↔ Backend communication                       │
│ - Certificate-based encryption                          │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ Layer 2: RSA-OAEP Encryption                            │
│ - Sensitive data encrypted with agent public key        │
│ - PINs, PUKs, management keys                           │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Vault Encryption                               │
│ - Secrets encrypted at rest in Vault                    │
│ - AES-256-GCM encryption                                │
└─────────────────────────────────────────────────────────┘
```

### Authentication and Authorization

#### User Authentication
- **Method**: JWT tokens with Argon2id password hashing
- **Expiration**: Configurable (default 8 hours)
- **Refresh**: Automatic token refresh
- **Revocation**: Immediate on logout

#### Agent Authentication
- **Method**: Ephemeral RSA keypairs (no persistent authentication)
- **Binding**: Keys bound to user sessions
- **Expiration**: Keys expire with user sessions
- **Rotation**: New keys on agent restart

#### RBAC (Role-Based Access Control)
- **Roles**: Admin, User
- **Permissions**: Granular permissions per role
- **Enforcement**: Backend API authorization
- **Audit**: All permission checks logged

## Secret Management

### Vault-First Architecture

All secrets stored in OpenBao, not in database:

- **YubiKey Secrets**: PINs, PUKs, management keys
- **Application Secrets**: JWT signing keys, encryption keys
- **Database Credentials**: Stored in Vault, not in code
- **PKI Certificates**: Root CA and intermediate certificates

### Secret Storage Paths

- `yubikeys/data/{serial}/secrets` - YubiKey PIN/PUK/management keys
- `yubikeys/metadata/{serial}` - Secret metadata and versions
- Application secrets in separate Vault paths

### Secret Encryption

- **At Rest**: Vault AES-256-GCM encryption
- **In Transit**: RSA-OAEP encryption (agent communication)
- **In Database**: Never stored (only metadata)

## Certificate and PKI Security

### PKI Architecture

- **Root CA**: 10-year self-signed certificate (Vault)
- **Certificate Signing**: Vault PKI engine
- **Certificate Lifetime**: Configurable (default 24 hours)
- **Revocation**: CRL support for certificate revocation

### Certificate Lifecycle

1. **CSR Generation**: On YubiKey using hardware private key
2. **Signing**: Vault PKI signs CSR
3. **Import**: Certificate imported to YubiKey PIV slot
4. **Revocation**: Certificates can be revoked via Vault

### Security Properties

- **Hardware Security**: Private keys never leave YubiKey
- **Certificate Authority**: Enterprise-grade PKI (Vault)
- **Certificate Validation**: Standard X.509 validation
- **Revocation Support**: CRL support for certificate revocation

## Network Security

### Communication Channels

#### Browser to Frontend
- **Protocol**: HTTPS/TLS 1.2+
- **Authentication**: JWT tokens
- **Encryption**: TLS encryption
- **Port**: 443 (via external load balancer)

#### Browser to Agent
- **Protocol**: HTTP (localhost only)
- **Authentication**: None
- **Encryption**: RSA-OAEP for sensitive data
- **Port**: 56123 (localhost)

#### Backend to Vault
- **Protocol**: HTTP (internal Kubernetes)
- **Authentication**: AppRole
- **Encryption**: Internal network (can enable TLS)
- **Port**: 8200 (internal service)

#### Backend to Database
- **Protocol**: PostgreSQL (internal Kubernetes)
- **Authentication**: Username/password (from Vault)
- **Encryption**: Internal network (can enable TLS)
- **Port**: 5432 (internal service)

### Network Isolation

- **Kubernetes Network Policies**: Pod-to-pod communication restrictions
- **No External Agent Access**: Agents not accessible from network
- **Internal Services**: Database and Vault internal only
- **External Load Balancer**: Single external entry point

## Audit and Compliance

### Audit Logging

All operations logged for compliance:

- **User Actions**: Login, logout, device operations
- **Admin Actions**: User management, policy changes
- **Security Events**: Failed logins, permission denials
- **System Events**: Agent registration, certificate operations

### Log Storage

- **Database**: Audit logs stored in PostgreSQL
- **Retention**: Configurable retention policies
- **Export**: PDF export for compliance reports
- **Search**: Full-text search capabilities

### Compliance Features

- **Audit Trail**: Complete operation history
- **User Activity**: Track all user actions
- **Device Inventory**: Complete device tracking
- **Certificate Status**: Certificate expiration tracking
- **Security Events**: Failed authentication attempts

## Security Considerations

### Known Limitations

1. **Localhost Trust**: Agent relies on localhost trust model
2. **HTTP Agent**: Agent uses HTTP (not HTTPS) on localhost
3. **Single OpenBao Instance**: No HA OpenBao cluster (can be added)

## Related Documentation

- [Vault and Secrets](vault-and-secrets.md)
- [Certificates and PKI](certificates-and-pki.md)
- [Authentication Model](auth-model.md)
- [Compliance Considerations](compliance-considerations.md)

