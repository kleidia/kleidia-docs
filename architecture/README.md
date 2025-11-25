# Kleidia Architecture Overview

## Executive Summary

Kleidia implements a **simplified frontend-mediated HTTP architecture** designed for enterprise-scale YubiKey management. The system enables centralized management of YubiKey devices while ensuring sensitive cryptographic operations are performed locally on user workstations through secure HTTP communication with RSA-OAEP encryption.

### Core Architecture Principles

1. **Anonymity-First Design**: Agents are anonymous HTTP services requiring no registration or certificates
2. **Ephemeral Key Security**: RSA-4096 keys generated on each agent startup for forward secrecy
3. **Frontend-Mediated Architecture**: All agent operations go through the browser to localhost
4. **RSA-OAEP Encryption**: All sensitive data encrypted before transmission
5. **Session-Bound Keys**: Agent public keys stored in user sessions and expire on logout
6. **Zero Configuration**: Agents start immediately without setup or pairing
7. **Vault-First Security**: All secrets managed through customer's external OpenBao or HashiCorp Vault
8. **Zero Standing Access**: Keys expire when user sessions end

### High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                    User Workstation                                │
│                                                                    │
│  ┌──────────────┐         HTTP (localhost:56123)                   │
│  │   Browser    │◄─────────────────────────┐                       │
│  │  (Frontend)  │                          │                       │
│  └──────┬───────┘                          ▼                       │
│         │                      ┌────────────────────┐              │
│         │ JWT Auth             │   HTTP Agent       │              │
│         │                      │   :56123           │              │
│         │                      │                    │              │
│         │                      │  • No Auth         │              │
│         │                      │  • No TLS          │              │
│         │                      │  • RSA Keypair     │              │
│         │                      │  • YubiKey Handler │              │
│         │                      └────────┬───────────┘              │
│         │                               │                          │
│         │                               ▼                          │
│         │                      ┌────────────────────┐              │
│         │                      │     YubiKey        │              │
│         │                      │   (USB Device)     │              │
│         │                      └────────────────────┘              │
│         │                                                          │
│         │ HTTPS (User JWT)                                         │
│         │ - Backend communication                                  │
│         │ - Session management                                     │
│         ▼                                                          │
└─────────│───────────────────────────────────────────────────────--─┘
          │
          ▼
┌──────────────────────────────────────────────────────────---───────┐
│                    Kubernetes Cluster                              │
│                                                                    │
│  ┌─────────────────┐                                               │
│  │  Go/Gin API     │                                               │
│  │  Server          │                                              │
│  │                  │                                              │
│  │  • Auth          │                                              │
│  │  • Encryption    │                                              │
│  │  • Session Mgmt  │                                              │
│  └────┬────────────┘                                               │
│       │                                                            │
│       ├──────────────────┬──────────────────┐                      │
│       │                  │                  │                      │
│       ▼                  ▼                  ▼                      │
│  ┌──────-───┐     ┌──────────┐                                      │
│  │PostgreSQL│     │ Frontend │                                      │
│  │ Database │     │ (Nuxt)   │                                      │
│  └──────-───┘     └──────────┘                                      │
│                                                                    │
│       │                                                             │
│       ├─────────────────────► OpenBao Vault (Internal)            │
│       │                     (or External Vault)                     │
│                                                                    │
└────────────────────────────────────────────────────────────────---─┘
```

### Key Components

#### Frontend (Browser)
- **Nuxt.js 4 Web Portal**: Vue 4 with TypeScript and Tailwind CSS
- **Real-time Updates**: Live device status and monitoring
- **Agent Detection**: Automatic detection of local agents
- **Security Warnings**: Visual warnings for default PIN/PUK values

#### Local Agent (User Workstation)
- **HTTP Server**: Anonymous server on localhost:56123
- **RSA Encryption**: Ephemeral RSA-4096 keypair generation
- **YubiKey Handler**: Direct USB device operations via ykman
- **Zero Configuration**: No setup, pairing, or certificates required

#### Backend (Kubernetes Cluster)
- **Go/Gin API Server**: RESTful API with JWT authentication
- **Encryption Service**: RSA-OAEP encryption for sensitive data
- **Session Management**: User session and agent key management
- **Audit Logging**: Comprehensive operation logging

#### Infrastructure (Kubernetes Cluster)
- **PostgreSQL Database**: Persistent storage for users, devices, and audit logs

#### External Infrastructure
- **External Vault**: Customer-managed OpenBao or HashiCorp Vault instance (external to deployment) for enterprise-grade secret storage (PIN/PUK/management keys)

### Security Architecture

#### Encryption Flow

1. **Backend retrieves secrets from external Vault** (customer-managed Vault instance, stored encrypted with Vault's key)
2. **Backend gets agent public key** from `user_sessions.agent_pubkey`
3. **Backend encrypts secrets** using RSA-OAEP with agent's public key
4. **Backend returns encrypted data** to frontend
5. **Frontend sends encrypted data** to agent via HTTP
6. **Agent decrypts** using its private key
7. **Agent executes operation** on YubiKey

#### Security Properties

- **Confidentiality**: RSA-OAEP encryption ensures only agent can decrypt
- **CORS Protection**: All agent endpoints protected with CORS to restrict access to authorized origins
- **Anonymity**: No agent registration or identification required
- **Forward Secrecy**: New keys on each agent restart
- **Zero Standing Access**: Keys expire with user session
- **Audit Trail**: All operations logged in database

### Operational Flow

#### Agent Startup
1. Agent starts and generates RSA-4096 keypair
2. Agent starts HTTP server on localhost:56123
3. Agent exposes public key via `GET /pubkey`

#### User Login and Agent Registration
1. User logs in through web portal
2. Frontend detects agent via `GET /.well-known/kleidia-agent`
3. Frontend fetches agent's public key via `GET /pubkey`
4. Frontend registers agent public key with backend via session ID
5. Backend stores agent public key in `user_sessions.agent_pubkey`

#### Secure Operations
1. User initiates YubiKey operation through web portal
2. Backend retrieves secrets from external Vault
3. Backend encrypts secrets with agent's RSA public key
4. Frontend sends encrypted data to agent via HTTP
5. Agent decrypts and executes operation on YubiKey
6. Agent returns result to frontend
7. Operation is logged in audit trail

## Benefits

✅ **Zero Configuration**: Agents start immediately without setup
✅ **No Certificates**: No certificate management required for agents
✅ **No Registration**: No agent registration or pairing flow required
✅ **Simplified Deployment**: Minimal agent deployment complexity
✅ **RSA-OAEP Encryption**: Industry-standard encryption for security
✅ **Synchronous Operations**: Immediate responses, no polling required
✅ **Minimal Backend Load**: Efficient resource usage

## Architecture Diagrams

Visual diagrams are available in the [diagrams](diagrams/) directory:

- [Architecture Diagram](diagrams/architecture.drawio) - High-level system architecture
- [Component Diagram](diagrams/component.drawio) - Detailed component relationships
- [Deployment Diagram](diagrams/deployment.drawio) - Production deployment topology
- [Workflow Sequence](diagrams/workflow.drawio) - Key user workflows
- [Data Flow Diagram](diagrams/data-flow.drawio) - Data movement flows
- [Sequence Diagram](diagrams/sequence.drawio) - Authentication and pairing sequence

All diagrams are provided in draw.io format and can be viewed using [draw.io](https://app.diagrams.net/) or embedded in documentation.

## Detailed Documentation

For complete technical architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).







