
# Security Overview for Auditors

**Audience**: Security Auditors, Compliance Officers, Risk Assessors, CISOs  
**Prerequisites**: Familiarity with security frameworks (NIS2, ISO 27001) and PKI concepts  
**Outcome**: Understand Kleidia's security architecture, trust boundaries, and compliance alignment

## Executive Summary

Kleidia is a self-hosted YubiKey and FIDO2 management platform deployed entirely within the customer's infrastructure. There is no external SaaS dependency. All cryptographic private keys remain on hardware tokens (YubiKeys) or within customer-controlled OpenBao/Vault instances.

---

## Architecture and Trust Boundaries

### Deployment Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│              Customer-Owned Infrastructure                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │               Kubernetes Cluster                               │  │
│  │                                                                │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │  │
│  │  │  Frontend   │  │   Backend   │  │     OpenBao         │   │  │
│  │  │  (Web UI)   │  │   (API)     │  │  (Secrets & PKI)    │   │  │
│  │  └─────────────┘  └──────┬──────┘  └─────────────────────┘   │  │
│  │                          │                                    │  │
│  │                          ▼                                    │  │
│  │                   ┌─────────────┐                             │  │
│  │                   │ PostgreSQL  │                             │  │
│  │                   │ (Database)  │                             │  │
│  │                   └─────────────┘                             │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    User Workstation                                  │
│                                                                     │
│  ┌─────────────┐         ┌─────────────┐        ┌─────────────┐    │
│  │   Browser   │ ◄─────► │   Agent     │ ◄────► │   YubiKey   │    │
│  │  (Web UI)   │  HTTP   │ (localhost) │  USB   │  (Hardware) │    │
│  └─────────────┘         └─────────────┘        └─────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### Trust Boundaries

| Boundary | Protection |
|----------|------------|
| User Workstation ↔ Kubernetes | HTTPS/TLS 1.2+ |
| Browser ↔ Local Agent | HTTP localhost only (127.0.0.1), sensitive data RSA-OAEP encrypted |
| Backend ↔ OpenBao | Internal cluster network, AppRole authentication |
| Backend ↔ PostgreSQL | Internal cluster network, credential-based auth |
| Agent ↔ YubiKey | Direct USB, hardware-enforced operations |

---

## Key and Secret Locations

### Where Private Keys Reside

| Key Type | Location | Exportable | Managed By |
|----------|----------|------------|------------|
| **YubiKey PIV private keys** | YubiKey hardware | ❌ No | End user (PIN-protected) |
| **FIDO2 private keys** | YubiKey hardware | ❌ No | End user (PIN-protected) |
| **OpenBao CA/Intermediate keys** | OpenBao seal storage | ❌ No (via seal) | Customer PKI/Security team |
| **Agent session keys** | Agent memory only | ❌ Never persisted | Ephemeral (session-bound) |
| **JWT signing keys** | OpenBao KV | ❌ No | Application |
| **Database credentials** | OpenBao KV | ❌ No | Application |

### Where Secrets Are Stored

| Secret Type | Storage Location | Encryption |
|-------------|------------------|------------|
| YubiKey PINs, PUKs | OpenBao KV v2 | AES-256-GCM (at rest) + RSA-OAEP (in transit to agent) |
| Management keys | OpenBao KV v2 | AES-256-GCM (at rest) |
| Application secrets | OpenBao KV v2 | AES-256-GCM (at rest) |
| User password hashes | PostgreSQL | Argon2id hashed (not encrypted secrets) |
| Session tokens | PostgreSQL | JWT with expiration |

### What Is NOT Stored

- YubiKey private keys (never leave hardware)
- Agent private keys (memory only, never persisted)
- Plaintext PINs in database (OpenBao only)

---

## Logging and Audit Trail

### Events Logged

| Category | Examples |
|----------|----------|
| **Authentication** | Login, logout, failed attempts, session expiration |
| **YubiKey Operations** | Registration, PIN change, certificate generation, revocation |
| **FIDO2 Operations** | Credential registration, removal |
| **Administrative** | User creation, role changes, policy modifications |
| **Security Events** | Permission denials, invalid requests, unusual patterns |

### Audit Log Properties

- **Immutability**: Logs stored in PostgreSQL with timestamps
- **Completeness**: All security-relevant operations logged
- **User Attribution**: Every action tied to authenticated user
- **Retention**: Configurable retention period
- **Export**: PDF and structured export for compliance reporting

### SIEM Integration

Logs can be forwarded to external SIEM systems via:
- Kubernetes log collection (Fluentd, Fluent Bit)
- Database log export
- Syslog forwarding (configurable)

---

## How Kleidia Supports Compliance

> **Note**: Kleidia is a tool that helps organizations implement security controls. It does not by itself guarantee compliance. Your organization must assess how Kleidia fits into your overall compliance program.

### NIS2 Directive Alignment

| NIS2 Requirement Area | How Kleidia Helps |
|----------------------|-------------------|
| **Strong Authentication** | Manages hardware-backed authentication credentials (PIV certificates, FIDO2) |
| **Access Control** | Role-based access, session management, audit logging |
| **Key Management** | Centralized management of hardware security keys with full lifecycle tracking |
| **Incident Response** | Runbooks for lost devices, user departure; immediate credential revocation |
| **Audit & Logging** | Complete audit trail of all authentication credential operations |
| **Supply Chain Security** | Self-hosted deployment; no external SaaS dependencies |

### ISO 27001 Control Mapping

| ISO 27001 Control | How Kleidia Helps |
|-------------------|-------------------|
| **A.9.2 User Access Management** | User provisioning, de-provisioning, access reviews via audit logs |
| **A.9.4 System Access Control** | Strong authentication via YubiKey PIV/FIDO2 |
| **A.10.1 Cryptographic Controls** | PKI integration, certificate lifecycle management |
| **A.12.4 Logging and Monitoring** | Comprehensive audit logging, security event tracking |
| **A.13.2 Information Transfer** | TLS encryption, RSA-OAEP for sensitive data |
| **A.18.1 Compliance** | Audit trail exports for compliance evidence |

### DORA (Digital Operational Resilience Act)

| DORA Requirement | How Kleidia Helps |
|------------------|-------------------|
| **ICT Risk Management** | Managed credential lifecycle reduces authentication-related risks |
| **ICT Incident Management** | Runbooks for security incidents, audit trail for investigation |
| **Digital Operational Resilience Testing** | Self-hosted architecture allows integration into resilience testing |

---

## Security Controls Summary

### Authentication

- JWT tokens with configurable expiration
- Argon2id password hashing
- Optional OIDC/SSO integration (Entra ID, etc.)
- Session-bound agent authentication

### Authorization

- Role-based access control (Admin, User)
- Permission enforcement at API level
- All authorization decisions logged

### Encryption

| Data State | Encryption |
|------------|------------|
| In Transit (external) | TLS 1.2+ |
| In Transit (to agent) | RSA-OAEP |
| At Rest (secrets) | AES-256-GCM (OpenBao) |
| At Rest (database) | PostgreSQL encryption (optional) |

### Network Security

- Kubernetes Network Policies
- No external exposure of database or OpenBao
- Agent accessible only via localhost
- Single external ingress point with TLS termination

---

## Questions Auditors Commonly Ask

| Question | Answer |
|----------|--------|
| **Where are private keys stored?** | YubiKey hardware (non-exportable) and OpenBao (sealed) |
| **Is there any SaaS dependency?** | No. Fully self-hosted in customer infrastructure |
| **Can administrators access user YubiKey PINs?** | PINs encrypted in OpenBao; admin actions logged but PINs not displayed |
| **What happens if a YubiKey is lost?** | Certificates revoked, FIDO2 credentials disabled, logged in audit trail |
| **How long are audit logs retained?** | Configurable; typically aligned with organizational retention policy |
| **Can audit logs be tampered with?** | Logs in PostgreSQL; recommend external SIEM for immutable copy |

---

## Related Documentation

- [Architecture Overview](../architecture/)
- [Authentication Model](auth-model/)
- [Certificates & PKI](certificates-and-pki/)
- [Vault and Secrets](vault-and-secrets/)
- [Compliance Considerations](compliance/)
- [Operational Runbooks](../operations/runbooks/)




