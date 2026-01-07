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

### Component Connection Security Matrix

The following table summarizes how each connection between components is secured:

| Source | Destination | Protocol | Port | Encryption | Authentication | Notes |
|:-------|:------------|:---------|:-----|:-----------|:---------------|:------|
| Browser | Frontend | HTTPS | 443 | TLS 1.2+ | JWT tokens | Via external load balancer |
| Browser | Backend API | HTTPS | 443 | TLS 1.2+ | JWT tokens | Via external load balancer |
| Browser | Agent | HTTP | 56123 | RSA-OAEP¹ | None | Localhost only |
| Frontend | Backend API | HTTP | 8080 | None² | JWT tokens | Internal K8s network |
| Backend | OpenBao | HTTP | 8200 | None² | AppRole | Internal K8s network |
| Backend | PostgreSQL (CNPG) | PostgreSQL | 5432 | TLS 1.3 | scram-sha-256 + client certs | K8s 1.32+ only |
| Backend | PostgreSQL (Legacy) | PostgreSQL | 5432 | None² | Password | K8s < 1.32 |
| Backend | License Service | HTTP | 8081 | None² | Internal | Internal K8s network |
| Agent | YubiKey | USB/CCID | — | Hardware | PIN/Touch | Local hardware |

**Legend:**
- ¹ RSA-OAEP: Sensitive data (PINs, PUKs, keys) is encrypted at application layer with RSA-OAEP even over HTTP
- ² None: No transport encryption, but isolated within Kubernetes internal network (not exposed externally)

### External vs Internal Connections

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL (Internet)                              │
│  ┌──────────┐                                    ┌──────────┐           │
│  │ Browser  │◄──────── HTTPS/TLS ───────────────►│   Load   │           │
│  └──────────┘                                    │ Balancer │           │
│       │                                          └────┬─────┘           │
│       │ HTTP + RSA-OAEP                               │                 │
│       ▼ (localhost only)                              │                 │
│  ┌──────────┐                                         │                 │
│  │  Agent   │                                         │                 │
│  └──────────┘                                         │                 │
└───────────────────────────────────────────────────────┼─────────────────┘
                                                        │
┌───────────────────────────────────────────────────────┼─────────────────┐
│                    INTERNAL (Kubernetes Cluster)      │                 │
│                                                       ▼                 │
│  ┌──────────┐    HTTP     ┌──────────┐    HTTP    ┌──────────┐         │
│  │ Frontend │◄───────────►│ Backend  │◄──────────►│ OpenBao  │         │
│  └──────────┘             └────┬─────┘            └──────────┘         │
│                                │                                        │
│                    PostgreSQL + TLS 1.3 (CNPG)                          │
│                    or PostgreSQL (Legacy)                               │
│                                │                                        │
│                                ▼                                        │
│                          ┌──────────┐                                   │
│                          │PostgreSQL│                                   │
│                          └──────────┘                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

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
- **Authentication**: Username/password (from Vault) with scram-sha-256
- **Encryption**: TLS 1.3 with certificate verification (verify-full mode)
- **Port**: 5432 (internal service)

When using CloudNativePG (CNPG), TLS is automatically configured:
- Server certificates issued by cert-manager
- Client certificates for mutual TLS authentication
- `verify-full` SSL mode validates server certificate and hostname

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

### Database TLS (CloudNativePG)

When using CloudNativePG for PostgreSQL (**requires Kubernetes 1.32+**), full TLS encryption is enabled:

- **TLS Version**: TLS 1.3 (latest, most secure)
- **Cipher Suite**: TLS_AES_256_GCM_SHA384 (256-bit encryption)
- **SSL Mode**: `verify-full` (validates server certificate and hostname)
- **Certificate Management**: Automatic via cert-manager
- **Authentication**: scram-sha-256 password hashing with TLS encryption

This provides defense-in-depth for database connections even within the Kubernetes cluster.

> ⚠️ **Legacy PostgreSQL (K8s < 1.32)**: On older Kubernetes versions, the legacy PostgreSQL StatefulSet is used, which does not support TLS. Database connections remain unencrypted but are restricted to the internal Kubernetes network. For production deployments requiring encrypted database connections, upgrade to Kubernetes 1.32+.

### Known Limitations

1. **Localhost Trust**: Agent relies on localhost trust model
2. **HTTP Agent**: Agent uses HTTP (not HTTPS) on localhost
3. **Single OpenBao Instance**: No HA OpenBao cluster (can be added)

## Related Documentation

- [Vault and Secrets](vault-and-secrets.md)
- [Certificates and PKI](certificates-and-pki.md)
- [Authentication Model](auth-model.md)
- [Compliance Considerations](compliance-considerations.md)

