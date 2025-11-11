# System Components

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Understanding of distributed systems  
**Outcome**: Understand the responsibilities and capabilities of each system component

## Component Overview

YubiMgr consists of six main components:

1. **Frontend** - Web user interface
2. **Backend** - API server and business logic
3. **Agent** - Local workstation service for YubiKey operations
4. **License Service** - License validation and management
5. **PostgreSQL** - Database for application data
6. **OpenBao (Vault)** - Secrets management and PKI

## Frontend Component

### Purpose
Web-based user interface for managing YubiKeys and user accounts.

### Technology
- **Framework**: Vue.js with Nuxt.js 4
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State Management**: Pinia

### Responsibilities
- User authentication and session management
- YubiKey device management interface
- Certificate generation and management workflows
- Admin dashboard for user and policy management
- Real-time status updates and notifications
- Orchestrates operations between backend and local agent

### Key Features
- **User Dashboard**: Personal YubiKey management
- **Admin Dashboard**: Organization-wide management
- **Device Registration**: Register and track YubiKey devices
- **Certificate Operations**: Generate CSRs and import certificates
- **PIN/PUK Management**: Secure credential management
- **Audit Logs**: View operation history

### Deployment
- Runs in Kubernetes as a NodePort service
- Exposed via external load balancer with SSL termination
- Stateless (can be scaled horizontally)

### Communication
- **HTTPS to Backend**: User authentication, API calls
- **HTTP to Agent**: Direct calls to localhost:56123 for YubiKey operations

## Backend Component

### Purpose
REST API server handling authentication, authorization, secret encryption, and Vault integration.

### Technology
- **Language**: Go 1.21+
- **Framework**: Gin web framework
- **Database**: PostgreSQL (via GORM)
- **Vault**: OpenBao integration

### Responsibilities
- User authentication and JWT token management
- Session management and agent key registration
- Secret encryption using agent public keys (RSA-OAEP)
- Vault integration for secrets and PKI operations
- Database operations (users, devices, sessions, audit logs)
- API endpoint security and authorization

### Key Features
- **Authentication**: JWT-based user authentication
- **Encryption Service**: Encrypts secrets with agent public keys
- **Vault Integration**: Retrieves secrets and signs certificates
- **Session Management**: Tracks user sessions and agent keys
- **Audit Logging**: Logs all operations for compliance
- **RBAC**: Role-based access control for admin operations

### API Endpoints

#### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout
- `GET /api/auth/me` - Current user info

#### Sessions
- `POST /api/session/{id}/register-agent` - Register agent public key
- `GET /api/session/{id}` - Get session info

#### YubiKeys
- `GET /api/yubikey` - List YubiKeys
- `GET /api/yubikey/{serial}` - Get YubiKey details
- `GET /api/yubikey/{serial}/secrets` - Get encrypted secrets
- `POST /api/yubikey/{serial}/sign-csr` - Sign certificate request

#### Admin
- `GET /api/admin/users` - List users
- `GET /api/admin/audit` - Audit logs
- `GET /api/admin/system/*` - System health checks

### Deployment
- Runs in Kubernetes as a NodePort service
- Multiple replicas for high availability
- Stateless (can be scaled horizontally)

### Communication
- **HTTPS from Frontend**: User requests
- **Internal to PostgreSQL**: Database queries
- **Internal to OpenBao**: Secret and PKI operations
- **Internal to License Service**: License validation and status checks

## Agent Component

### Purpose
Local HTTP server on user workstations for executing YubiKey operations.

### Technology
- **Language**: Go
- **Protocol**: HTTP (localhost:56123)
- **YubiKey Access**: Utilizes system-installed ykman binary

### Responsibilities
- Generate ephemeral RSA keypair on startup
- Expose public key via HTTP endpoint
- Execute YubiKey operations using ykman CLI
- Decrypt sensitive data using private key
- Return operation results synchronously

### Key Features
- **Anonymous Operation**: No registration or authentication required
- **Ephemeral Keys**: New RSA-4096 keypair on each startup
- **YubiKey Operations**: PIN/PUK management, certificate generation, CSR creation
- **USB Monitoring**: Detects YubiKey insertion/removal via system USB hotplug
- **Health Monitoring**: Health check endpoint for status

### HTTP Endpoints

#### Public Endpoints (No Authentication)
- `GET /.well-known/yubimgr-agent` - Agent discovery and status
- `GET /health` - Health check
- `GET /pubkey` - Get agent's ephemeral public key
- `GET /discover` - List connected YubiKeys
- `GET /system/info` - System information

#### YubiKey Operation Endpoints
- `GET /piv/info?serial={serial}` - Get PIV information
- `POST /piv/set-pin` - Set/change PIN
- `POST /piv/set-puk` - Set/change PUK
- `POST /piv/unblock-pin` - Unblock PIN using PUK
- `POST /piv/generate-csr` - Generate Certificate Signing Request
- `POST /piv/import-certificate` - Import certificate to YubiKey
- `POST /piv/reset` - Reset PIV application
- `GET /piv/check-defaults?serial={serial}` - Check default credentials
- `POST /piv/rotate-management-key` - Rotate management key

### Deployment
- **Location**: User workstations (localhost:56123)
- **Installation**: Binary installation or system service

### Communication
- **HTTP from Browser**: Direct calls from frontend
- **USB to YubiKey**: Direct hardware access

### Security Model
- **Localhost Only**: No external network access
- **Ephemeral Keys**: Private keys never persisted to disk
- **RSA-OAEP Encryption**: All sensitive data encrypted before transmission
- **Session Binding**: Public keys expire with user sessions

## License Service Component

### Purpose
Cryptographically-signed license validation and management service for controlling system usage rights and expiration.

### Technology
- **Language**: Go 1.25+
- **Obfuscation**: Garble v0.15.0 for binary protection
- **Storage**: OpenBao Vault KV v2 for license storage
- **Cryptography**: Ed25519 digital signatures

### Responsibilities
- Validate license signatures using embedded public key
- Store and retrieve licenses from Vault
- Generate unique installation IDs
- Provide license status to backend
- Track license history and operations
- Enforce license expiration policies

### Key Features
- **Ed25519 Signatures**: Cryptographically verifies license authenticity
- **Installation ID Binding**: Licenses tied to specific deployments
- **Trial Mode**: Automatic 30-day trial on first installation
- **Vault Storage**: Licenses stored encrypted in Vault KV v2
- **Garble Obfuscation**: Binary obfuscated to protect public key
- **Stateless Operation**: No database dependencies
- **Fallback Behavior**: Falls back to TRIAL mode if service unavailable

### License Status Types
- **TRIAL**: 30-day free trial (system-generated)
- **VALID**: Active license with > 7 days remaining
- **EXPIRING**: Active license with ≤ 7 days remaining
- **EXPIRED**: License past expiry date
- **INVALID**: Signature verification or installation ID mismatch
- **MISSING**: No license found in storage

### HTTP Endpoints

#### License Operations
- `GET /health` - Health check endpoint
- `GET /license/installation-id` - Get or generate installation ID
- `GET /license/status` - Get current license status
- `POST /license/upload` - Upload and validate new license
- `DELETE /license` - Remove current license
- `GET /license/history` - Get license operation history

### Deployment
- Runs in Kubernetes as ClusterIP service (internal only)
- Multiple replicas for high availability
- Minimal resource requirements (32MB RAM, 50m CPU)
- Network policy restricts access to backend only

### Communication
- **Internal from Backend**: License validation requests
- **Internal to OpenBao**: Store/retrieve licenses from Vault
- **No External Access**: Not exposed outside cluster

### Security Model

#### Cryptographic Protection
- **Ed25519 Signatures**: Licenses signed with private key held by vendor
- **Public Key Embedding**: Public key compiled into binary for verification
- **Garble Obfuscation**: Binary obfuscated to prevent public key extraction
- **Installation ID**: Cryptographic hash binds license to specific deployment

#### Binary Obfuscation
The license service binary is built with garble:
- `-literals`: Encrypts string literals (public key, error messages)
- `-tiny`: Minimizes binary size and obfuscates control flow
- `-seed=random`: Each build is unique to prevent pattern matching

This prevents reverse engineering of the public key from the binary.

#### Vault Integration
- **Kubernetes Auth**: Authenticates using ServiceAccount token
- **Limited Policy**: Access only to `yubikeys/data/license/*` path
- **Encrypted Storage**: Licenses stored in Vault KV v2 (encrypted at rest)
- **24-hour TTL**: Vault token refreshed automatically

#### Network Isolation
- **ClusterIP Service**: Only accessible within Kubernetes cluster
- **Network Policy**: Ingress restricted to backend pods only
- **No External Access**: Cannot be reached from outside cluster

### License Data Flow

#### License Upload
1. Admin → Frontend: Paste license JSON
2. Frontend → Backend: POST /api/admin/license/upload
3. Backend: Decode license JSON
4. Backend → License Service: POST /license/upload
5. License Service: Verify signature with embedded public key
6. License Service: Validate installation ID match
7. License Service: Check expiry date
8. License Service → Vault: Store validated license
9. License Service → Backend: Success response
10. Backend → PostgreSQL: Store license history record
11. Backend → Frontend: Display license details

#### License Validation
1. Backend → License Service: GET /license/status
2. License Service → Vault: Retrieve current license
3. License Service: Validate signature and expiry
4. License Service → Backend: Status (VALID, TRIAL, EXPIRED, etc.)
5. Backend: Enforce restrictions based on status

### Installation ID Generation

The installation ID is a unique cryptographic hash generated from:
- MAC address (primary network interface)
- Hostname (system hostname)
- UUID (random UUID generated on first run)

Combined and hashed with SHA-256, then base64-encoded. This creates a unique identifier that:
- Cannot be easily forged or transferred
- Remains stable across pod restarts (stored in Vault)
- Uniquely identifies the deployment

### License File Format

Licenses are JSON documents with signature:

```json
{
  "license": {
    "installation_id": "ABC123...",
    "customer_name": "Acme Corporation",
    "customer_email": "admin@acme.com",
    "issue_date": "2025-01-15T00:00:00Z",
    "expiry_date": "2026-01-15T00:00:00Z",
    "license_type": "standard"
  },
  "signature": "base64-encoded-ed25519-signature"
}
```

The signature covers the entire `license` object in canonical JSON format.

### Failure Modes

#### License Service Unavailable
- Backend falls back to TRIAL mode
- System remains operational
- Warning logged for monitoring

#### License Expired
- Status changes to EXPIRED
- System may restrict certain features
- Admin receives expiry notifications

#### Invalid Signature
- License upload rejected
- Error message returned to admin
- Operation logged for audit

### Monitoring

Monitor these metrics:
- License service health: `GET /health` should return 200
- License expiry date: Days remaining before expiration
- Vault connectivity: License service logs Vault authentication
- License status: Check via `GET /license/status`

### Troubleshooting

#### License Validation Fails
- Check Installation ID matches license
- Verify license JSON is complete and unmodified
- Check license has not expired
- Review license-service logs for signature errors

#### License Service Unavailable
- Check pod status: `kubectl get pods -l app=license-service`
- Check Vault connectivity in license-service logs
- Verify Vault role `license-service` exists
- Check network policy allows backend → license-service

## PostgreSQL Database

### Purpose
Relational database for application data, user accounts, and audit logs.

### Technology
- **Database**: PostgreSQL 15
- **ORM**: GORM (from Go backend)
- **Storage**: Persistent volumes in Kubernetes

### Data Stored

#### Users Table
- User accounts and authentication
- Password hashes (Argon2id)
- User roles and permissions

#### YubiKeys Table
- Device registration and metadata
- Serial numbers and device information
- Ownership and status

#### User Sessions Table
- Active user sessions
- Agent public keys (ephemeral)
- Session expiration timestamps

#### Audit Logs Table
- All operations and events
- User actions and system events
- Timestamps and metadata

### Data NOT Stored
- YubiKey PINs, PUKs, or management keys (stored in Vault)
- Agent private keys (never leave agent memory)
- Plaintext passwords (only Argon2id hashes)

### Deployment
- Runs in Kubernetes as a StatefulSet
- Persistent storage for data durability
- Automated backups recommended

### Access Control
- Internal Kubernetes service (no external access)
- Backend connects via connection pooling
- Credentials stored in Vault

## OpenBao (Vault)

### Purpose
Secrets management and PKI certificate authority. Installed as CA, configurable to intermediate.

### Technology
- **Product**: OpenBao
- **Mode**: Production mode with persistent storage
- **Storage**: File-based storage in Kubernetes

### Responsibilities

#### Secrets Management (KV v2 Engine)
- Store YubiKey PINs, PUKs, and management keys
- Store application secrets (JWT keys, encryption keys)
- Automatic secret rotation capabilities
- Versioned secret storage

#### PKI Operations
- Certificate Authority for YubiKey certificates
- Sign Certificate Signing Requests (CSRs)
- Issue certificates for PIV slots
- Certificate revocation and CRL management

### Key Features
- **KV v2 Secrets Engine**: `yubikeys/data/*` path for YubiKey secrets
- **PKI Secrets Engine**: Certificate signing and management
- **Auto-Unseal**: Static key unsealing (no manual unseal required)
- **Persistent Storage**: Data survives pod restarts
- **Audit Logging**: Complete audit trail of all operations

### Secret Storage Paths
- `yubikeys/data/{serial}/secrets` - YubiKey PIN/PUK/management keys
- `yubikeys/metadata/{serial}` - Secret metadata and versions

### PKI Configuration
- Root CA: 10-year self-signed certificate
- PKI Role: `yubimgr` with flexible certificate policies
- Certificate TTL: Configurable (default 1 year)

### Deployment
- Runs in Kubernetes as a StatefulSet
- Persistent storage for secrets and PKI data
- Single instance (can be clustered for HA)

### Access Control
- Internal Kubernetes service (no external access)
- Backend authenticates using AppRole
- Fine-grained policies for secret access

## Component Interactions

### User Login Flow
1. Frontend → Backend: Login request
2. Backend → PostgreSQL: Validate credentials
3. Backend → Frontend: JWT token
4. Frontend: Store token, redirect to dashboard

### Agent Registration Flow
1. Frontend → Agent: GET /.well-known/yubimgr-agent
2. Frontend → Agent: GET /pubkey
3. Frontend → Backend: POST /api/session/{id}/register-agent
4. Backend → PostgreSQL: Store agent_pubkey

### YubiKey Operation Flow
1. Frontend → Backend: GET /api/yubikey/{serial}/secrets
2. Backend → OpenBao: Retrieve secrets
3. Backend → PostgreSQL: Get agent_pubkey
4. Backend: Encrypt secrets with agent public key
5. Backend → Frontend: Encrypted secrets
6. Frontend → Agent: POST /piv/set-pin (with encrypted data)
7. Agent: Decrypt and execute operation
8. Agent → Frontend: Operation result

## Related Documentation

- [System Overview](system-overview.md)
- [Data Flows](data-flows.md)
- [Security Model](../02-security/security-overview.md)
- [Deployment Guide](../03-deployment/prerequisites.md)

