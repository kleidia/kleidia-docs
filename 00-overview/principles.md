# Core Architectural Principles

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Basic understanding of Kubernetes and security concepts  
**Outcome**: Understand the fundamental principles that guide YubiMgr's architecture

## 1. Kubernetes-First Deployment

YubiMgr is designed to run in Kubernetes environments.

### Key Points
- All server components run in Kubernetes (frontend, backend, database, OpenBao)
- Services are exposed via NodePort for external load balancer integration
- Helm charts provide the primary deployment method
- Persistent storage ensures data survives pod restarts

### Benefits
- Standard Kubernetes tooling and practices
- Scalable and maintainable architecture
- Easy upgrades and rollbacks
- Production-ready deployment model

## 2. Vault-Centric Secret Management

All secrets are stored in **OpenBao**, not in the database.

### Key Points
- **YubiKey Secrets**: PINs, PUKs, and management keys stored in Vault KV v2 (`yubikeys/data/*`)
- **Application Secrets**: JWT signing keys, encryption keys, database passwords stored in Vault
- **PKI Operations**: Certificate signing performed by Vault PKI engine
- **No Database Secrets**: Sensitive data never stored in PostgreSQL

### Benefits
- Centralized secret management
- Automatic secret rotation capabilities
- Audit trail for all secret access
- Compliance with security best practices

## 3. Local-Only Agent Architecture

Agents run on user workstations where YubiKeys are physically connected.

### Key Points
- **Workstation Deployment**: Agents run on user workstations where YubiKeys are connected
- **HTTP Communication**: Agents expose HTTP endpoints on localhost:56123
- **Frontend-Mediated**: Browser orchestrates all operations between cloud services and local agents

### Benefits
- Hardware security: Private keys never leave YubiKey devices
- Network security: No inbound ports required on workstations
- Operational security: Sensitive operations isolated to user workstations
- Scalability: Each agent operates independently

## 4. Intelligent Resource Management

The system uses intelligent polling and session management to optimize resource usage.

### Key Points
- **Session-Based Operations**: Agent keys bound to user sessions
- **Automatic Expiration**: Keys expire when users log out (zero standing access)
- **Efficient Communication**: Direct HTTP requests, no constant polling
- **Resource Optimization**: Minimal CPU and memory usage when idle

### Benefits
- 90% CPU reduction compared to traditional polling architectures
- Scalable to 10,000+ agents with minimal backend load
- Better battery life on laptops
- Lower infrastructure costs

## 5. Frontend-Mediated Architecture

The browser acts as the secure bridge between cloud services and local agents.

### Key Points
- **Browser Orchestration**: All operations initiated from the web interface
- **Direct HTTP Calls**: Browser makes direct HTTP calls to localhost agent
- **Backend Coordination**: Backend handles authentication, secret encryption, and Vault operations
- **Synchronous Operations**: Immediate feedback, no polling required

### Benefits
- Simple architecture: No message queues or complex routing
- Fast operations: Direct request-response communication
- Secure by default: Browser security model enforced
- Easy troubleshooting: Standard HTTP debugging tools

## 6. Security-First Design

Security is built into every layer of the architecture.

### Key Points
- **Encryption**: RSA-OAEP encryption for all sensitive data transmission
- **Session Binding**: Agent keys tied to user sessions
- **Zero Standing Access**: No valid credentials for logged-out users
- **Audit Logging**: Complete logging of all operations
- **PKI Integration**: Enterprise-grade certificate management

### Benefits
- Defense in depth: Multiple security layers
- Compliance ready: Audit trails and policy enforcement
- Threat mitigation: Short-lived credentials and session binding
- Enterprise security: Meets security requirements for sensitive environments

## 7. Operational Simplicity

The system is designed to be easy to deploy, operate, and maintain.

### Key Points
- **Helm Charts**: Standard Kubernetes deployment method
- **Automated Setup**: Vault configuration and database initialization automated
- **Health Monitoring**: Built-in health checks and readiness probes
- **Standard Tooling**: Uses standard Kubernetes and Linux tools

### Benefits
- Faster deployment: Automated setup reduces manual steps
- Easier maintenance: Standard Kubernetes operations
- Better reliability: Health checks and automatic recovery
- Lower operational overhead: Less manual intervention required

## Related Documentation

- [System Architecture](../01-architecture/system-overview.md)
- [Security Model](../02-security/security-overview.md)
- [Deployment Guide](../03-deployment/prerequisites.md)
- [Operations Guide](../04-operations/daily-operations.md)

