# Data Flows

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Understanding of HTTP and security concepts  
**Outcome**: Understand how data flows through the system for common operations

## Overview

YubiMgr uses a frontend-mediated architecture where the browser orchestrates operations between cloud services and local agents. All sensitive operations are encrypted using RSA-OAEP encryption before transmission.

## Authentication Flow

### User Login

```
┌─────────┐         ┌──────────┐         ┌────────────┐
│ Browser │────────▶│ Backend  │────────▶│ PostgreSQL │
│         │ HTTPS   │          │         │            │
└─────────┘         └──────────┘         └────────────┘
     │                    │
     │                    │ Validate credentials
     │                    │ Generate JWT token
     │◀───────────────────│
     │ JWT token          │
     │                    │
     │ Store token        │
     │ Redirect to dashboard
```

**Steps**:
1. User enters credentials in browser
2. Frontend sends `POST /api/auth/login` to backend
3. Backend queries PostgreSQL to validate credentials
4. Backend generates JWT token with user ID and session info
5. Backend returns JWT token to frontend
6. Frontend stores token and redirects to dashboard

**Data Transmitted**:
- Credentials (HTTPS encrypted)
- JWT token (contains user ID, session ID, expiration)

## Agent Registration Flow

### Agent Discovery and Key Exchange

```
┌─────────┐         ┌──────────┐         ┌────────────┐
│ Browser │────────▶│  Agent   │         │  Backend   │
│         │ HTTP    │ localhost│         │            │
└─────────┘         └──────────┘         └────────────┘
     │                    │                    │
     │ GET /.well-known   │                    │
     │◀───────────────────│                    │
     │ Agent status       │                    │
     │                    │                    │
     │ GET /pubkey        │                    │
     │◀───────────────────│                    │
     │ Public key (PEM)   │                    │
     │                    │                    │
     │ POST /api/session/ │                    │
     │ {id}/register-agent│                    │
     │────────────────────┼───────────────────▶│
     │                    │                    │ Store in PostgreSQL
     │◀───────────────────┼─────────────-──────│
     │ Success            │                    │
```

**Steps**:
1. User logs in → Frontend detects agent
2. Frontend calls `GET http://127.0.0.1:56123/.well-known/yubimgr-agent`
3. Agent responds with status and version
4. Frontend calls `GET http://127.0.0.1:56123/pubkey`
5. Agent returns ephemeral RSA public key
6. Frontend sends public key to backend: `POST /api/session/{id}/register-agent`
7. Backend stores public key in `user_sessions.agent_pubkey`
8. Backend confirms registration

**Data Transmitted**:
- Agent public key (PEM format)
- Session ID (for binding)

## YubiKey Operation Flow

### PIN Change Operation

```
┌─────────┐         ┌──────────┐         ┌──────────┐         ┌──────────┐
│ Browser │────────▶│ Backend  │────────▶│ OpenBao  │         │  Agent   │
│         │ HTTPS   │          │         │ (Vault)  │         │ localhost│
└─────────┘         └──────────┘         └──────────┘         └──────────┘
     │                    │                    │                    │
     │ GET /api/yubikey/  │                    │                    │
     │ {serial}/secrets   │                    │                    │
     │───────────────────▶│                    │                    │
     │                    │ Get agent_pubkey   │                    │
     │                    │ from PostgreSQL    │                    │
     │                    │                    │                    │
     │                    │ Get PIN from Vault │                    │
     │                    │───────────────────▶│                    │
     │                    │◀───────────────────│                    │
     │                    │ PIN (plaintext)    │                    │
     │                    │                    │                    │
     │                    │ Encrypt PIN with   │                    │
     │                    │ agent public key   │                    │
     │                    │ (RSA-OAEP)         │                    │
     │◀───────────────────│                    │                    │
     │ Encrypted PIN      │                    │                    │
     │                    │                    │                    │
     │ POST /piv/set-pin  │                    │                    │
     │ {encrypted: true,  │                    │                    │
     │  pin: "..."}       │                    │                    │
     │─────────────────────────────────────────────────────────────▶│
     │                    │                    │                    │
     │                    │                    │ Decrypt PIN        │
     │                    │                    │ Execute ykman      │
     │                    │                    │ piv change-pin     │
     │◀─────────────────────────────────────────────────────────────│
     │ Success            │                    │                    │
```

**Steps**:
1. User requests PIN change in frontend
2. Frontend requests secrets: `GET /api/yubikey/{serial}/secrets`
3. Backend retrieves agent public key from PostgreSQL
4. Backend retrieves PIN from OpenBao Vault
5. Backend encrypts PIN using agent's RSA public key (RSA-OAEP)
6. Backend returns encrypted PIN to frontend
7. Frontend sends encrypted PIN to agent: `POST http://127.0.0.1:56123/piv/set-pin`
8. Agent decrypts PIN using private key
9. Agent executes `ykman piv change-pin` command
10. Agent returns success/failure to frontend
11. Frontend updates UI with result

**Data Transmitted**:
- Encrypted PIN (RSA-OAEP encrypted)
- Serial number (plaintext)
- Operation result (success/failure)

## Certificate Generation Flow

### CSR Generation and Certificate Signing

```
┌─────────┐         ┌──────────┐         ┌──────────┐         ┌──────────┐
│ Browser │────────▶│  Agent   │         │ Backend  │────────▶│ OpenBao  │
│         │ HTTP    │ localhost│         │          │         │ (Vault)  │
└─────────┘         └──────────┘         └──────────┘         └──────────┘
     │                    │                    │                    │
     │ POST /piv/         │                    │                    │
     │ generate-csr       │                    │                    │
     │───────────────────▶│                    │                    │
     │                    │ Generate CSR using │                    │
     │                    │ YubiKey private key│                    │
     │◀───────────────────│                    │                    │
     │ CSR (PEM)          │                    │                    │
     │                    │                    │                    │
     │ POST /api/yubikey/ │                    │                    │
     │ {serial}/sign-csr  │                    │                    │
     │────────────────────┼───────────────────▶│                    │
     │                    │                    │ Sign CSR via PKI   │
     │                    │                    │───────────────────▶│
     │                    │                    │◀───────────────────│
     │                    │                    │ Signed certificate │
     │◀───────────────────┼─────────────-──────│                    │
     │ Certificate (PEM)  │                    │                    │
     │                    │                    │                    │
     │ POST /piv/         │                    │                    │
     │ import-certificate │                    │                    │
     │───────────────────▶│                    │                    │
     │                    │ Import certificate │                    │
     │                    │ to YubiKey PIV slot│                    │
     │◀───────────────────│                    │                    │
     │ Success            │                    │                    │
```

**Steps**:
1. User requests certificate generation
2. Frontend calls agent: `POST http://127.0.0.1:56123/piv/generate-csr`
3. Agent generates CSR using YubiKey's private key (slot 9a)
4. Agent returns CSR to frontend
5. Frontend sends CSR to backend: `POST /api/yubikey/{serial}/sign-csr`
6. Backend retrieves management key from Vault
7. Backend signs CSR using OpenBao PKI engine
8. Backend returns signed certificate to frontend
9. Frontend sends certificate to agent: `POST http://127.0.0.1:56123/piv/import-certificate`
10. Agent imports certificate to YubiKey PIV slot
11. Agent returns success to frontend

**Data Transmitted**:
- CSR (Certificate Signing Request, PEM format)
- Signed certificate (PEM format)
- Serial number (plaintext)

## Secret Storage Flow

### Storing YubiKey Secrets in Vault

```
┌─────────┐         ┌──────────┐         ┌──────────┐
│ Browser │────────▶│ Backend  │────────▶│ OpenBao  │
│         │ HTTPS   │          │         │ (Vault)  │
└─────────┘         └──────────┘         └──────────┘
     │                    │                    │
     │ POST /api/yubikey/ │                    │
     │ {serial}/secrets   │                    │
     │───────────────────▶│                    │
     │                    │ Store in KV v2     │
     │                    │ yubikeys/data/     │
     │                    │ {serial}/secrets   │
     │                    │───────────────────▶│
     │                    │◀───────────────────│
     │                    │ Success            │
     │◀───────────────────│                    │
     │ Success            │                    │
```

**Steps**:
1. Admin registers YubiKey and provides PIN/PUK/management key
2. Frontend sends secrets to backend: `POST /api/yubikey/{serial}/secrets`
3. Backend encrypts secrets (if needed) and stores in Vault
4. Backend stores at path: `yubikeys/data/{serial}/secrets`
5. Vault encrypts data at rest
6. Backend confirms storage

**Data Stored**:
- PIN (encrypted at rest by Vault)
- PUK (encrypted at rest by Vault)
- Management key (encrypted at rest by Vault)

## Security Considerations

### Encryption Layers

1. **HTTPS/TLS**: All browser-to-backend communication encrypted
2. **RSA-OAEP**: Sensitive data encrypted with agent public key before transmission
3. **Vault Encryption**: Secrets encrypted at rest in Vault
4. **Database Encryption**: PostgreSQL data encrypted at rest (if configured)

### Data Never Transmitted in Plaintext

- PINs: Always encrypted with RSA-OAEP before transmission
- PUKs: Always encrypted with RSA-OAEP before transmission
- Management Keys: Always encrypted with RSA-OAEP before transmission
- Private Keys: Never leave YubiKey hardware

### Session Binding

- Agent public keys stored in `user_sessions` table
- Keys expire when user session expires
- Zero standing access for logged-out users

## Related Documentation

- [System Overview](system-overview.md)
- [Components](components.md)
- [Security Model](../02-security/security-overview.md)
- [Agent Communication](agent-communication.md)

