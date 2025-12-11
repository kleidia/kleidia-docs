
# Certificates and PKI

**Audience**: PKI Engineers, Security Architects, Operations Administrators  
**Prerequisites**: Understanding of PKI concepts, certificate hierarchies, and X.509 certificates  
**Outcome**: Understand Kleidia's PKI architecture, integration patterns, and certificate lifecycle management

## Overview

Kleidia uses OpenBao (HashiCorp Vault-compatible) as its PKI engine for signing YubiKey PIV certificates. The recommended production configuration positions OpenBao as an **intermediate CA** under your existing enterprise PKI, ensuring certificates chain to your organization's trusted root.

> **Important**: In production environments, configure Kleidia's OpenBao PKI as an intermediate CA subordinate to your existing root or issuing CA. The self-signed root configuration described below is intended **only for lab, PoC, and evaluation deployments**.

## PKI Architecture Patterns

### Production Pattern: Intermediate CA (Recommended)

In production, OpenBao operates as an intermediate CA under your existing PKI hierarchy:

```
┌─────────────────────────────────┐
│   Your Enterprise Root CA       │  (Offline, air-gapped)
│   (AD CS, EJBCA, other)         │
└───────────────┬─────────────────┘
                │ Signs intermediate
                ▼
┌─────────────────────────────────┐
│   Your Issuing CA (optional)    │  (Online issuing CA)
└───────────────┬─────────────────┘
                │ Signs Kleidia intermediate
                ▼
┌─────────────────────────────────┐
│   OpenBao Intermediate CA       │  (Kleidia PKI engine)
│   (pki/ mount in OpenBao)       │
└───────────────┬─────────────────┘
                │ Signs end-entity certs
                ▼
┌─────────────────────────────────┐
│   YubiKey PIV Certificates      │  (Slots 9a, 9c, 9d, 9e)
└─────────────────────────────────┘
```

**Benefits**:
- Certificates chain to your organization's trusted root
- Existing trust relationships preserved
- CRL/OCSP integration with enterprise PKI
- Compliance with organizational PKI policies

### PoC/Lab Pattern: Self-Signed Root

For evaluation and testing only, OpenBao can generate a self-signed root CA:

```
┌─────────────────────────────────┐
│   OpenBao Self-Signed Root CA   │  (PoC only)
│   (pki/ mount in OpenBao)       │
└───────────────┬─────────────────┘
                │ Signs end-entity certs
                ▼
┌─────────────────────────────────┐
│   YubiKey PIV Certificates      │
└─────────────────────────────────┘
```

> **Warning**: Self-signed root certificates are not trusted by enterprise systems. Use this pattern only for isolated testing environments.

## PKI Role Configuration

The system uses a PKI role named `kleidia` configured for YubiKey PIV certificate issuance:

| Setting | Value | Purpose | Security Notes |
|---------|-------|---------|----------------|
| `allow_any_name` | `true` | Permits certificates with any common name | Scoped to PIV certificates on hardware tokens; not used for server TLS |
| `enforce_hostnames` | `false` | Disables hostname validation | PIV certificates use user principals, not hostnames |
| `allow_subdomains` | `true` | Permits subdomain-style names | Supports email-style SANs (user@domain) |
| `allow_localhost` | `true` | Allows localhost in SANs | May be needed for local testing scenarios |
| `allow_ip_sans` | `true` | Permits IP address SANs | Rarely used; available for edge cases |
| `require_cn` | `true` | Requires Common Name | Ensures certificates have identifying CN |
| `key_type` | `rsa` | RSA key algorithm | YubiKey PIV standard; EC also supported |
| `key_bits` | `2048` | RSA key size | Minimum for PIV; 4096 recommended for high-security |
| `max_ttl` | `8760h` | Maximum certificate lifetime | 1 year; adjust per organizational policy |
| `ttl` | `8760h` | Default certificate lifetime | 1 year; shorter values increase rotation burden |

> **Note**: The "permissive" settings like `allow_any_name=true` are appropriate because these certificates are issued exclusively to hardware-backed YubiKey PIV slots—not for general server TLS. The private keys cannot be exported from the YubiKey hardware.

## Certificate Types and PIV Slots

Kleidia manages certificates across YubiKey PIV slots:

| PIV Slot | Purpose | Typical Use Cases |
|----------|---------|-------------------|
| **9a** (Authentication) | User authentication | Smart card logon, VPN, SSH |
| **9c** (Digital Signature) | Non-repudiation signing | Document signing, code signing |
| **9d** (Key Management) | Encryption/decryption | Email encryption (S/MIME) |
| **9e** (Card Authentication) | Physical access | Door access, badge systems |

## Certificate Lifecycle

### 1. CSR Generation

**Location**: User workstation (Kleidia Agent)

1. User requests certificate via web interface
2. Frontend calls Agent: `POST http://127.0.0.1:56123/piv/generate-csr`
3. Agent generates CSR using YubiKey's on-device private key
4. CSR returned to frontend (private key never leaves YubiKey)

### 2. Certificate Signing

**Location**: Backend server → OpenBao

1. Frontend sends CSR to backend: `POST /api/yubikey/{serial}/sign-csr`
2. Backend authenticates to OpenBao using AppRole
3. Backend submits CSR to PKI engine: `POST /v1/pki/sign/kleidia`
4. OpenBao signs CSR using intermediate (or root in PoC mode)
5. Signed certificate returned to backend

**Certificate Properties**:
- **Issuer**: Your intermediate CA (production) or Kleidia Root CA (PoC)
- **Validity**: Configurable, default 1 year
- **Key Usage**: Digital signature, key encipherment
- **Extended Key Usage**: Client authentication, email protection

### 3. Certificate Import

**Location**: User workstation (Kleidia Agent)

1. Signed certificate sent to Agent: `POST http://127.0.0.1:56123/piv/import-certificate`
2. Agent imports certificate to specified PIV slot
3. Certificate stored on YubiKey hardware alongside private key

### 4. Certificate Renewal

Certificates should be renewed before expiration:

1. User or admin initiates renewal via web interface
2. New CSR generated (optionally with new key pair)
3. New certificate signed and imported
4. Old certificate remains valid until expiration (or revoked)

### 5. Certificate Revocation

1. Admin revokes certificate via web interface
2. Backend calls OpenBao: `POST /v1/pki/revoke`
3. Certificate serial added to CRL
4. Certificate marked revoked in Kleidia database

**CRL Distribution**: Available at `/v1/pki/crl` on your OpenBao instance

## Security Considerations

### Private Key Protection

| Aspect | Implementation |
|--------|----------------|
| **Key Generation** | Performed on YubiKey hardware |
| **Key Storage** | Hardware-backed, tamper-resistant |
| **Key Export** | Impossible—YubiKey enforces non-exportability |
| **Key Usage** | Requires PIN entry for operations |

### Certificate Lifetime Recommendations

| Certificate Type | Recommended Lifetime | Rationale |
|------------------|---------------------|-----------|
| Root CA | 10–20 years | Rarely changes; offline storage |
| Intermediate CA | 3–5 years | Balance between security and operational burden |
| End-entity (PIV) | 1–2 years | Regular rotation; manageable renewal cycle |

### Revocation Considerations

- **CRL**: OpenBao publishes CRL; configure CRL distribution points in your environment
- **OCSP**: OpenBao supports OCSP; configure if real-time revocation checking required
- **Grace Period**: Plan certificate renewal before expiration to avoid service disruption

## Integration with Enterprise PKI

For production deployments, see [PKI Integration Patterns](../deployment/pki-integration/) for detailed guidance on:

- Integrating with Microsoft AD CS
- Integrating with EJBCA or other CAs
- Using existing Vault/OpenBao infrastructure
- Key ceremony and CSR signing procedures

## Related Documentation

- [PKI Integration Patterns](../deployment/pki-integration/)
- [Vault and Secrets](vault-and-secrets/)
- [Security Overview for Auditors](for-auditors/)
- [Vault Setup Guide](../deployment/vault-setup/)
