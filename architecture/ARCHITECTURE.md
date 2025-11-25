# Kleidia Enterprise Architecture

**Version**: 2.2.0 
**Last Updated**: November 20245 
**Status**: Production Ready

## System Overview

Kleidia is a distributed enterprise YubiKey management platform that implements a **simplified frontend-mediated HTTP architecture** with anonymous agents and ephemeral RSA encryption. The system enables centralized management of YubiKey devices while ensuring that sensitive cryptographic operations are performed locally on user workstations via direct HTTP communication with RSA-OAEP encryption.

### Core Principles

1. **Anonymity-First Design**: Agents are anonymous HTTP services with no registration
2. **Ephemeral Key Security**: RSA-4096 keys generated on each agent startup
3. **Frontend-Mediated Architecture**: All agent calls go through browser to localhost
4. **RSA-OAEP Encryption**: All sensitive data encrypted before transmission
5. **Session-Bound Keys**: Agent public keys stored in user_sessions table
6. **Zero Configuration**: No setup, no pairing, no certificates required
7. **Vault-First Secret Management**: All secrets encrypted and stored in OpenBao Vault
8. **Zero Standing Access**: Keys expire with user session logout
9. **Enterprise-Ready**: Full audit logging, operation lifecycle management
10. **Simplified Architecture**: No message queues, no certificates, no authentication for agents

### Security Guarantees

✅ **RSA-OAEP Encryption**: All agent communication via encrypted payloads  
✅ **No Plaintext Operations**: PIN/PUK/mgmt keys never transmitted unencrypted  
✅ **Ephemeral Keys**: New keys on each agent restart (forward secrecy)  
✅ **Encrypted Secrets**: All YubiKey secrets encrypted in Vault  
✅ **Audit Trail**: Complete operation logging in PostgreSQL  
✅ **Zero Standing Access**: No valid keys for logged-out users  
✅ **CORS Protection**: All agent endpoints protected with CORS to restrict access to authorized origins  
✅ **HTTP-Only Agent**: Relies on RSA encryption, no TLS required between frontend and agent

## Architecture Components

### Frontend (Nuxt.js 4)

The frontend provides the web interface for users and administrators:

- **Web Portal**: Vue 4 with TypeScript and Tailwind CSS
- **Real-time Updates**: Live device status and monitoring
- **Agent Detection**: Automatic detection of local agents via `.well-known` endpoint
- **Security Warnings**: Visual warnings for default PIN/PUK values
- **PIV Management**: Certificate generation and management interface
- **Device Registration**: Simple workflow for registering YubiKey devices

### Local Agent (Go HTTP Server)

The agent runs on user workstations and provides local YubiKey access:

- **HTTP Server**: Anonymous server on localhost:56123
- **RSA Encryption**: Ephemeral RSA-4096 keypair generation on startup
- **YubiKey Handler**: Direct USB device operations via embedded ykman
- **Zero Configuration**: No setup, pairing, or certificates required
- **Public Key Endpoint**: Exposes public key via `GET /pubkey` endpoint

#### Agent Endpoints

**Note**: All agent endpoints are protected with CORS (Cross-Origin Resource Sharing) to ensure secure communication from the web portal.

**Public Endpoints (No Authentication):**
- `GET /.well-known/kleidia-agent` - Agent discovery
- `GET /health` - Health check
- `GET /pubkey` - Return ephemeral public key (PEM format)
- `GET /discover` - List attached YubiKeys
- `GET /system/info` - System information

**YubiKey Operation Endpoints:**
- `GET /piv/info?serial=<serial>` - Get PIV information
- `POST /piv/set-pin` - Set PIN
- `POST /piv/set-puk` - Set PUK
- `POST /piv/unblock-pin` - Unblock PIN
- `POST /piv/generate-csr` - Generate CSR
- `POST /piv/import-certificate` - Import certificate
- `POST /piv/reset` - Reset PIV
- `GET /piv/check-defaults` - Check defaults
- `POST /piv/rotate-management-key` - Rotate management key

### Backend (Go/Gin API Server)

The backend provides the API server and business logic:

- **Go/Gin API Server**: RESTful API with JWT authentication
- **Encryption Service**: RSA-OAEP encryption for sensitive data
- **Session Management**: User session and agent key management
- **Audit Logging**: Comprehensive operation logging
- **Vault Integration**: Secure secret storage and retrieval
- **OIDC Support**: Universal identity provider integration

### Database (PostgreSQL)

PostgreSQL provides persistent storage for:

- **Users Table**: User accounts and authentication
- **user_sessions Table**: User sessions with `agent_pubkey` column
- **yubikeys Table**: Device registration and management
- **audit_logs Table**: Complete audit trail of operations
- **PIV Certificates**: Certificate metadata

**PostgreSQL Deployment Options:**

**Standalone Server Deployment:**
- **PostgreSQL**: Deployed within Kubernetes cluster on standalone server
- **Storage**: Automatically provisioned with local persistent volumes
- **Management**: Fully managed by the Helm chart deployment

**Existing Kubernetes Cluster Deployment:**
- **Option 1 - External PostgreSQL**: Customer-managed PostgreSQL cluster outside Kubernetes
  - Backend connects to external PostgreSQL via connection string
  - Customer responsible for PostgreSQL infrastructure and management
  - No Kubernetes resources required for PostgreSQL
- **Option 2 - PostgreSQL within Kubernetes**: PostgreSQL deployed within customer's Kubernetes cluster
  - Requires customer-provided Persistent Volume Claims (PVCs)
  - Managed by Helm chart but uses customer storage infrastructure

### Secret Management (OpenBao/HashiCorp Vault)

Kleidia supports two Vault deployment options for enterprise-grade secret storage:

**Option 1 - Internal Vault (Deployed within Kubernetes):**
- **Vault Pod**: OpenBao Vault deployed within Kubernetes cluster
- **Automatic Configuration**: Helm chart automatically configures Vault with required engines, policies, and AppRole credentials
- **Persistent Storage**: Requires PVCs for Vault data (automatic for standalone, customer-provided for existing cluster)
- **KV v2 Secrets Engine**: Automatically enabled at `yubikeys/` path
- **PKI Engine**: Automatically configured for certificate signing and management
- **AppRole Authentication**: Automatically configured with generated credentials
- **Fully Managed**: Vault lifecycle managed by Helm chart deployment

**Option 2 - External Vault (Customer-managed):**
- **External Vault**: Customer-managed OpenBao or HashiCorp Vault instance outside of Kleidia deployment
- **Manual Configuration**: Customer must configure Vault with required engines, policies, and AppRole credentials before deployment
- **KV v2 Secrets Engine**: Encrypted storage for PIN/PUK/management keys (expected at `yubikeys/` path)
- **PKI Engine**: Certificate signing and management (optional, if customer has PKI configured)
- **AppRole Authentication**: Secure service authentication (backend authenticates using AppRole)
- **Policy-Based Access Control**: Fine-grained permissions managed by customer
- **Network Access**: Backend connects to external Vault via HTTPS (customer-provided Vault endpoint)

## Security Model

### Encryption Flow

1. **Backend retrieves secrets from Vault** (internal Vault pod or external customer-managed Vault instance, stored encrypted with Vault's key)
2. **Backend gets agent public key** from `user_sessions.agent_pubkey`
3. **Backend encrypts secrets** using RSA-OAEP with agent's public key
4. **Backend returns encrypted data** to frontend
5. **Frontend sends encrypted data** to agent via HTTP
6. **Agent decrypts** using its private key
7. **Agent executes operation** on YubiKey

### Security Properties

- **Confidentiality**: RSA-OAEP encryption ensures only agent can decrypt
- **Anonymity**: No agent registration or identification required
- **Forward Secrecy**: New keys on each agent restart
- **Zero Standing Access**: Keys expire with user session
- **Audit Trail**: All operations logged in database

## Operational Flow

### Agent Startup

1. Agent starts and generates RSA-4096 keypair in memory
2. Agent starts HTTP server on localhost:56123
3. Agent exposes public key via `GET /pubkey` endpoint
4. Agent is ready to accept operations

### User Login and Agent Registration

1. User logs in through web portal
2. Frontend detects agent via `GET /.well-known/kleidia-agent`
3. Frontend fetches agent's public key via `GET /pubkey`
4. Frontend registers agent public key with backend via session ID
5. Backend stores agent public key in `user_sessions.agent_pubkey`

### Secure Operations

1. User initiates YubiKey operation through web portal
2. Frontend calls backend API with user JWT
3. Backend retrieves secrets from Vault
4. Backend encrypts secrets with agent's RSA public key
5. Frontend sends encrypted data to agent via HTTP
6. Agent decrypts using its private key
7. Agent executes operation on YubiKey using embedded ykman
8. Agent returns result to frontend
9. Operation is logged in audit trail


## Infrastructure

### Kubernetes Deployment

All server components run in a Kubernetes cluster. Kleidia supports two deployment scenarios:

**Standalone Server Deployment:**
- All components run on a single server with automatic k0s Kubernetes cluster provisioning
- **Frontend Pod**: Nuxt.js 4 application
- **Backend Pod**: Go/Gin API server
- **PostgreSQL Pod**: Database deployed within Kubernetes with persistent storage
- **Vault Options**:
  - **Option 1**: Vault pod deployed within Kubernetes with automatic provisioning (default)
  - **Option 2**: Customer-managed external Vault instance (external to deployment)
- **External Load Balancer (HAProxy)**: Host-level load balancing with SSL termination, communicates with Kubernetes services via NodePort

**Existing Kubernetes Cluster Deployment:**
- Components deployed into customer's existing Kubernetes cluster
- **PostgreSQL Options**:
  - **Option 1**: Customer external PostgreSQL cluster (no Kubernetes resources)
  - **Option 2**: PostgreSQL deployed within Kubernetes with customer-provided PVCs
- **Vault Options**:
  - **Option 1**: Vault pod deployed within Kubernetes with customer-provided PVCs
  - **Option 2**: Customer-managed external Vault instance (external to deployment)
- Uses existing cluster infrastructure (storage, networking, ingress)
- Can leverage customer load balancer or cluster ingress
- Flexible deployment with shared cluster resources

### Network Architecture

- **External Access**: HTTPS via external load balancer (HAProxy) with customer-provided SSL/TLS certificates or Let's Encrypt (optional)
- **Load Balancer Communication**: External load balancer communicates with Kubernetes services via NodePort by default
- **Internal Communication**: HTTP between pods (Kubernetes internal network)
- **Agent Communication**: HTTP on localhost:56123 (workstation only)
- **Vault Access**: 
  - **Internal Vault**: Internal Kubernetes service (HTTP between pods)
  - **External Vault**: Backend connects to customer's external Vault instance via HTTPS (customer-provided Vault endpoint)

### Storage

Storage requirements differ by deployment scenario:

**Standalone Server Deployment:**
- **Database**: PostgreSQL deployed within Kubernetes with persistent volumes automatically provisioned on server
- **Vault Options**:
  - **Option 1 (Internal)**: Vault deployed within Kubernetes with persistent volumes automatically provisioned on server
  - **Option 2 (External)**: Customer-managed external Vault instance (no storage required in deployment)
- **Container Images**: Customer Docker registry or Artifactory (images must be pre-loaded)

**Existing Kubernetes Cluster Deployment:**
- **Database Options**:
  - **Option 1 - External PostgreSQL**: No storage required (external database)
  - **Option 2 - PostgreSQL within Kubernetes**: Customer-provided Persistent Volume Claims (PVCs) required
- **Vault Options**:
  - **Option 1 - Internal Vault**: Vault deployed within Kubernetes with customer-provided Persistent Volume Claims (PVCs) required
  - **Option 2 - External Vault**: Customer-managed external Vault instance (no storage required in deployment)
- **Storage Classes**: Customer-managed storage classes used for PVC provisioning (if PostgreSQL Option 2 or Vault Option 1 selected)
- **Container Images**: Customer Docker registry or Artifactory (images must be pre-loaded)

## Security Considerations

### Localhost Security

- Agent runs on `127.0.0.1:56123` (localhost only)
- No external network access
- Relying on localhost trust model

### Encryption Strength

- RSA-4096 for ephemeral keys
- OAEP padding for chosen-ciphertext security
- Customer Vault's encryption for data at rest (AES-256-GCM typical for Vault)

### Forward Secrecy

- New keys on each agent restart
- Session-bound keys expire on logout
- No persistent key storage

### Access Control

- JWT tokens with automatic expiration
- Role-based access control (RBAC)
- Session-based agent key binding
- Audit logging for all operations

## Monitoring and Observability

### Health Checks

- Application health endpoints for all components
- Kubernetes readiness and liveness probes
- Database connection monitoring
- Vault connectivity and health status (internal Vault pod or external Vault endpoint)

### Logging

- Structured JSON logging for all components
- Centralized log aggregation (via Kubernetes)
- Audit trail for all security-sensitive operations
- Error tracking and alerting

### Metrics

- Performance metrics for API endpoints
- Resource usage monitoring (CPU, memory, disk)
- Agent connectivity status
- Database query performance

## Scalability

### Horizontal Scaling

- Frontend pods can scale independently
- Backend pods can scale independently
- Stateless design enables easy scaling
- Database connection pooling

### Resource Management

- Efficient resource usage with intelligent polling
- Minimal agent resource footprint
- Optimized database queries
- Container resource limits

## Disaster Recovery

### Backup Strategy

- Database backups: Automated PostgreSQL backups
- Vault backups: 
  - **Internal Vault**: Automated snapshot-based backups (managed by Helm chart)
  - **External Vault**: Managed by customer (customer's Vault backup strategy applies)
- Configuration backups: Version-controlled Helm charts
- Restore procedures: Documented recovery processes

### High Availability

- Kubernetes pod health monitoring
- Automatic pod restarts on failures
- Persistent volumes for data durability
- Database replication (optional)

## Performance Optimizations

### Installation Timeouts

- Optimized timeouts for faster deployment
- Reduced retry delays
- Faster check intervals
- Total installation time: ~5-7 minutes







