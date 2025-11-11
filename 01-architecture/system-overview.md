# System Architecture Overview

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Basic understanding of distributed systems and Kubernetes  
**Outcome**: Understand the high-level architecture and component relationships

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Workstation                            │
│                                                                     │
│  ┌────────────-──┐         HTTP (localhost:56123)                   │
│  │   Browser     │◄─────────────────────────┐                       │
│  │  (Frontend)   │                          │                       │
│  └──────┬────────┘                          ▼                       │
│         │                      ┌────────────────────┐               │
│         │                      │   HTTP Agent       │               │
│         │                      │   :56123           │               │
│         │                      │                    │               │
│         │                      │  • RSA Keypair     │               │
│         │                      │  • YubiKey Handler │               │
│         │                      └────────┬───────────┘               │
│         │                               │                           │
│         │                               ▼                           │
│         │                      ┌────────────────────┐               │
│         │                      │     YubiKey        │               │
│         │                      │   (USB Device)     │               │
│         │                      └────────────────────┘               │
│         │                                                           │
│         │ HTTPS (User JWT)                                          │
│         │ - Backend communication                                   │
│         │ - Session management                                      │
│         ▼                                                           │
└─────────│───────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                               │
│                                                                     │
│  ┌─────────────────┐                                                │
│  │  Frontend Pod   │  Nuxt.js 4 web application                     │
│  │  (NodePort)     │                                                │
│  └────────┬────────┘                                                │
│           │                                                         │
│           ├──────────────────┬──────────────────┐                   │
│           │                  │                  │                   │
│           ▼                  ▼                  ▼                   │
│  ┌─────────────┐    ┌──────────────┐   ┌─────────────┐              │
│  │ Backend Pod │    │ PostgreSQL   │   │ OpenBao     │              │
│  │ (Go/Gin)    │    │ Database     │   │ (Vault)     │              │
│  │             │    │              │   │             │              │
│  │ • Auth      │    │ • Users      │   │ • PKI CA    │              │
│  │ • Encryption│    │ • Devices    │   │ • Secrets   │              │
│  │ • Session   │    │ • Sessions   │   │ • KV v2     │              │
│  │ • License   │    │ • Audit Logs │   │ • Licenses  │              │
│  └──────┬──────┘    └──────────────┘   └───────▲─────┘              │
│         │                                      │                    │
│         │ License                              │                    │
│         │ Validation                           │ License            │
│         │                                      │ Storage            │
│         ▼                                      │                    │
│  ┌────────────────┐                            │                    │
│  │ License Service│───────────────────────────-┘                    │
│  │ (ClusterIP)    │                                                 │
│  │                │  Cryptographic license validation               │
│  │ • Validation   │  Trial mode (30 days)                           │
│  │                │  Vault storage                                  │
│  └────────────────┘                                                 │
└─────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    External Load Balancer                           │
│                    (SSL Termination)                                │
│                    TLS Certificates                                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### Frontend (Browser + Kubernetes Pod)

**Location**: Kubernetes cluster (NodePort service)  
**Technology**: Vue.js 3 with Nuxt.js 4  
**Responsibilities**:
- User interface for YubiKey management
- User authentication and session management
- Orchestrates operations between backend and local agent
- Makes direct HTTP calls to localhost agent
- Displays real-time status and results

**Communication**:
- HTTPS to backend API (user authentication)
- HTTP to localhost agent (YubiKey operations)

### Backend (Kubernetes Pod)

**Location**: Kubernetes cluster (NodePort service)  
**Technology**: Go/Gin REST API server  
**Responsibilities**:
- User authentication and authorization
- Session management
- Secret encryption (RSA-OAEP with agent public keys)
- Vault integration (secrets and PKI)
- Database operations (users, devices, sessions, audit logs)
- API endpoint for frontend

**Communication**:
- HTTPS from frontend (user requests)
- Internal to PostgreSQL (database queries)
- Internal to OpenBao (secret and PKI operations)
- Internal to License Service (license validation)

### License Service (Kubernetes Pod)

**Location**: Kubernetes cluster (ClusterIP service - internal only)  
**Technology**: Go with Garble obfuscation  
**Responsibilities**:
- Cryptographic license signature validation (Ed25519)
- Installation ID generation and management
- License storage in Vault
- License status reporting (TRIAL, VALID, EXPIRING, EXPIRED)
- 30-day trial mode support
- License history tracking

**Communication**:
- Internal from Backend (license validation requests)
- Internal to OpenBao (license storage in KV v2)
- No external access (ClusterIP with network policy)

**Security**:
- Binary obfuscated with garble to protect public key
- Network policy restricts access to backend only
- Licenses bound to installation ID (cannot be transferred)
- Falls back to TRIAL mode if service unavailable

### Agent (User Workstation)

**Location**: User workstation (localhost:56123)  
**Technology**: Go HTTP server  
**Responsibilities**:
- Generate ephemeral RSA keypair on startup
- Expose public key via HTTP endpoint
- Execute YubiKey operations using ykman (bundled with agent installer)
- Decrypt sensitive data using private key
- Return operation results synchronously

**Communication**:
- HTTP from browser (frontend-mediated operations)
- Direct USB access to YubiKey hardware


### PostgreSQL Database

**Location**: Kubernetes cluster (StatefulSet with persistent storage)  
**Technology**: PostgreSQL 15  
**Responsibilities**:
- User accounts and authentication
- YubiKey device registration
- User sessions and agent public keys
- Audit logs and operation history
- Application configuration

**Data Stored**:
- User accounts (no passwords - Argon2id hashes)
- Device metadata (serial numbers, status, owners)
- Session data (agent public keys, expiration)
- Audit logs (all operations)

**Data NOT Stored**:
- YubiKey PINs, PUKs, or management keys (stored in Vault)
- Agent private keys (never leave agent memory)

### OpenBao (Vault)

**Location**: Kubernetes cluster (StatefulSet with persistent storage)  
**Technology**: OpenBao  
**Responsibilities**:
- Secret storage (KV v2 engine)
- PKI certificate authority
- Certificate signing for YubiKey CSRs
- Secret encryption at rest

**Secrets Stored**:
- YubiKey PINs, PUKs, management keys (`yubikeys/data/{serial}/secrets`)
- Application secrets (JWT keys, encryption keys, database passwords)
- PKI root CA and intermediate certificates

**PKI Operations**:
- Sign Certificate Signing Requests (CSRs)
- Issue certificates for YubiKey PIV slots
- Certificate revocation and CRL management

### External Load Balancer

**Location**: Customer infrastructure (external to Kubernetes)  
**Responsibilities**:
- SSL termination (TLS/HTTPS)
- Load balancing to Kubernetes NodePort services
- HTTP to HTTPS redirection
- DDoS protection and rate limiting

**Configuration**:
- Routes HTTPS traffic to frontend and backend NodePorts
- TLS certificate management (customer-specific)
- Health checks and failover

## Data Flow Patterns

### User Authentication Flow

```
1. User → Frontend: Login credentials
2. Frontend → Backend: POST /api/auth/login
3. Backend → PostgreSQL: Validate credentials
4. Backend → Frontend: JWT token
5. Frontend: Store JWT, redirect to dashboard
```

### Agent Registration Flow

```
1. User logs in → Frontend detects agent
2. Frontend → Agent: GET http://127.0.0.1:56123/.well-known/yubimgr-agent
3. Agent → Frontend: { status: "ok", version: "2.2" }
4. Frontend → Agent: GET http://127.0.0.1:56123/pubkey
5. Agent → Frontend: { public_key: "-----BEGIN PUBLIC KEY-----..." }
6. Frontend → Backend: POST /api/session/{id}/register-agent
7. Backend → PostgreSQL: Store agent_pubkey in user_sessions
8. Backend → Frontend: { status: "ok" }
```

### YubiKey Operation Flow (PIN Change Example)

```
1. User → Frontend: Request PIN change
2. Frontend → Backend: GET /api/yubikey/{serial}/secrets
3. Backend → OpenBao: Retrieve PIN from yubikeys/data/{serial}/secrets
4. Backend → PostgreSQL: Get agent_pubkey from user_sessions
5. Backend: Encrypt PIN with agent's RSA public key (RSA-OAEP)
6. Backend → Frontend: { encrypted: true, pin: "encrypted_data" }
7. Frontend → Agent: POST http://127.0.0.1:56123/piv/set-pin
   Body: { encrypted: true, pin: "encrypted_data", serial: "..." }
8. Agent: Decrypt PIN using private key
9. Agent: Execute ykman piv change-pin
10. Agent → Frontend: { success: true }
11. Frontend: Update UI with success message
```

### Certificate Generation Flow

```
1. User → Frontend: Request certificate generation
2. Frontend → Agent: POST http://127.0.0.1:56123/piv/generate-csr
3. Agent: Generate CSR using YubiKey's private key
4. Agent → Frontend: { csr: "-----BEGIN CERTIFICATE REQUEST-----..." }
5. Frontend → Backend: POST /api/yubikey/{serial}/sign-csr
6. Backend → OpenBao: Sign CSR using PKI engine
7. OpenBao → Backend: Signed certificate
8. Backend → Frontend: { certificate: "-----BEGIN CERTIFICATE-----..." }
9. Frontend → Agent: POST http://127.0.0.1:56123/piv/import-certificate
10. Agent: Import certificate to YubiKey PIV slot
11. Agent → Frontend: { success: true }
```

## Security Boundaries

### Network Security

- **External Access**: HTTPS only via external load balancer
- **Internal Communication**: Kubernetes service mesh (ClusterIP)
- **Agent Communication**: HTTP on localhost only (no external access)
- **Vault Access**: Internal Kubernetes service (no external exposure)

### Data Security

- **In Transit**: HTTPS/TLS for all external communication
- **At Rest**: Vault encryption for secrets, PostgreSQL encryption for database
- **In Memory**: Agent private keys never persisted to disk
- **Session Binding**: Agent keys expire with user sessions

### Access Control

- **User Authentication**: JWT tokens with expiration
- **Session Management**: Session-bound agent keys
- **RBAC**: Role-based access control for admin operations
- **Audit Logging**: All operations logged for compliance

## Scalability Considerations

### Horizontal Scaling

- **Frontend**: Stateless, easily scalable (multiple replicas)
- **Backend**: Stateless API servers (multiple replicas)
- **Database**: PostgreSQL with connection pooling
- **Vault**: Single instance (can be clustered for HA)

### Resource Efficiency

- **Agent CPU**: <1% when idle, ~10% during operations
- **Backend Load**: Minimal (no polling, direct HTTP operations)
- **Database Load**: Low (session-based, not constant polling)
- **Network Traffic**: Minimal (synchronous operations only)

### Capacity Planning

- **Users**: Supports 10,000+ users
- **Devices**: Unlimited (limited by database storage)
- **Concurrent Operations**: Limited by backend replicas and database connections
- **Agent Connections**: Each agent independent (no shared resources)

## Related Documentation

- [Component Details](components.md)
- [Data Flows](data-flows.md)
- [Security Model](../02-security/security-overview.md)
- [Deployment Guide](../03-deployment/prerequisites.md)

