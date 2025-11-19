# Kleidia Overview

**Audience**: Operations Administrators, Security Professionals, End Users  
**Prerequisites**: None  
**Outcome**: Understand what Kleidia is and what it does

## What is Kleidia?

Kleidia is an enterprise-grade YubiKey management platform that enables centralized management of YubiKey devices across your organization. The system provides secure, web-based administration while ensuring that sensitive cryptographic operations are performed locally on user workstations.

## Key Capabilities

### Centralized Management
- **Web-based Administration**: Manage all YubiKey devices from a single web interface
- **User Self-Service**: Users can manage their own devices and certificates through a user-friendly dashboard
- **Policy Enforcement**: Define and enforce security policies across your organization
- **Audit Trail**: Complete logging of all operations for compliance and security

### YubiKey Operations
- **Device Registration**: Register and track YubiKey devices across your organization
- **PIN/PUK Management**: Set, change, and reset YubiKey PINs and PUKs securely
- **Certificate Management**: Generate, sign, and import PIV certificates using enterprise PKI
- **Device Lifecycle**: Complete lifecycle management from registration to retirement

### Security Features
- **Vault-First Secret Management**: All secrets stored in OpenBao
- **Local Agent Architecture**: Sensitive operations performed on user workstations, not servers
- **RSA-OAEP Encryption**: All sensitive data encrypted before transmission
- **Session-Based Security**: Agent keys expire with user sessions for zero standing access
- **Enterprise PKI**: Integration with OpenBao PKI for certificate signing

## System Architecture

Kleidia uses a **hybrid architecture** that combines:

1. **Cloud-Hosted Services**: Web frontend, API backend, database, and Vault running in Kubernetes
2. **Local Agents**: HTTP-based agents running on user workstations for YubiKey operations
3. **Frontend-Mediated Communication**: Browser orchestrates operations between cloud and local components


## High-Level Components

### Frontend
- **Technology**: Vue.js with Nuxt.js 4
- **Purpose**: User interface for managing YubiKeys
- **Deployment**: Runs in Kubernetes cluster
- **Access**: Web browser via HTTPS

### Backend
- **Technology**: Go/Gin REST API server
- **Purpose**: Authentication, authorization, secret encryption, Vault integration
- **Deployment**: Runs in Kubernetes cluster
- **Communication**: HTTPS API endpoints

### Agent
- **Technology**: Go HTTP server
- **Purpose**: Execute YubiKey operations locally on workstations
- **Deployment**: Runs on user workstations (localhost:56123)
- **Communication**: Direct HTTP from browser to localhost

### Infrastructure
- **PostgreSQL**: Database for users, devices, sessions, and audit logs
- **OpenBao**: Secrets management and PKI certificate authority
- **Kubernetes**: Container orchestration platform

## Value Proposition

### For Organizations
- **Centralized Control**: Manage all YubiKeys from a single platform
- **Security Compliance**: Complete audit trails and policy enforcement
- **Scalability**: Supports thousands of users and devices
- **Enterprise Integration**: Works with existing PKI and identity providers

### For Administrators
- **Easy Deployment**: Helm chart-based deployment with automated setup
- **Operational Simplicity**: Kubernetes-native architecture with standard tooling
- **Monitoring**: Built-in health checks and logging
- **Maintenance**: Automated backups and upgrade procedures

### For End Users
- **Self-Service**: Manage your own YubiKey devices
- **Simple Interface**: Intuitive web interface for common operations
- **Secure Operations**: All operations performed securely on your workstation
- **Zero Configuration**: Agent works automatically after installation

## Use Cases

### Enterprise YubiKey Management
- Register and track YubiKey devices across the organization
- Enforce security policies and PIN requirements
- Generate and manage PIV certificates for authentication, code signing
- Monitor device usage and security events

### Certificate Lifecycle Management
- Generate Certificate Signing Requests (CSRs) from YubiKeys
- Sign certificates using enterprise PKI (Vault)
- Import signed certificates to YubiKey PIV slots
- Track certificate expiration and renewal

### Security Compliance
- Complete audit logging of all operations
- Policy enforcement and compliance reporting
- Secure secret management in Vault
- Session-based access control

## Next Steps

- **Understanding Architecture**: See [Architecture Overview](../01-architecture/system-overview.md)
- **Planning Deployment**: See [Deployment Prerequisites](../03-deployment/prerequisites.md)
- **Security Details**: See [Security Overview](../02-security/security-overview.md)
- **Using the System**: See [User Guides](../05-using-the-system/)

