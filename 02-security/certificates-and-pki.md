# Certificates and PKI

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Understanding of PKI and certificate management  
**Outcome**: Understand Kleidia's PKI architecture and certificate lifecycle

## Overview

Kleidia uses OpenBao as a Certificate Authority (CA) or intermediate for signing YubiKey PIV certificates. The PKI system provides enterprise-grade certificate management with automatic signing and lifecycle management.

## PKI Architecture

### Certificate Authority

- **Root CA**: Self-signed root certificate (10-year lifetime)
- **PKI Engine**: Vault PKI secrets engine at `pki/` mount
- **Certificate Signing**: Automatic CSR signing via PKI role
- **Certificate Revocation**: CRL support for certificate revocation

### PKI Role Configuration

The system uses a PKI role named `kleidia` with the following settings:

| Setting             | Value   | Purpose                                  |
|---------------------|---------|------------------------------------------|
| `allow_any_name`    | `true`  | Allows certificates with any common name |
| `enforce_hostnames` | `false` | Disables hostname validation             |
| `allow_subdomains`  | `true`  | Permits subdomain certificates           |
| `allow_localhost`   | `true`  | Allows localhost certificates            |
| `allow_ip_sans`     | `true`  | Permits IP address SANs                  |
| `require_cn`        | `true`  | Requires Common Name in certificates     |
| `key_type`          | `rsa`   | RSA key type (YubiKey standard)          |
| `key_bits`          | `2048`  | 2048-bit RSA keys                        |
| `max_ttl`           | `8760h` | Maximum certificate lifetime (1 year)    |
| `ttl`               | `8760h` | Default certificate lifetime (1 year)    |

## Certificate Lifecycle

### 1. CSR Generation

**Location**: User workstation (agent)  
**Process**:
1. User requests certificate generation via web interface
2. Frontend calls agent: `POST http://127.0.0.1:56123/piv/generate-csr`
3. Agent generates CSR using YubiKey's private key (slot 9a)
4. CSR includes:
   - Common Name (CN)
   - Subject Alternative Names (SANs)
   - Key algorithm (RSA 2048-bit)
   - Key usage extensions

**Security**: Private key never leaves YubiKey hardware

### 2. Certificate Signing

**Location**: Backend server  
**Process**:
1. Frontend sends CSR to backend: `POST /api/yubikey/{serial}/sign-csr`
2. Backend authenticates to Vault using AppRole
3. Backend submits CSR to Vault PKI: `POST /v1/pki/sign/kleidia`
4. Vault signs CSR using root CA
5. Backend receives signed certificate

**Certificate Properties**:
- **Issuer**: Kleidia Root CA
- **Validity**: 1 year (8760h, configurable via PKI role)
- **Key Usage**: Digital signature, key encipherment
- **Extended Key Usage**: Client authentication, email protection

### 3. Certificate Import

**Location**: User workstation (agent)  
**Process**:
1. Backend returns signed certificate to frontend
2. Frontend sends certificate to agent: `POST http://127.0.0.1:56123/piv/import-certificate`
3. Agent imports certificate to YubiKey PIV slot (9a, 9c, 9d, or 9e)
4. Certificate stored on YubiKey hardware

**Security**: Certificate stored securely on YubiKey hardware

### 4. Certificate Usage

Certificates can be used for:
- **Client Authentication**: TLS client certificates
- **Email Signing**: S/MIME email signing
- **Code Signing**: Application code signing
- **Document Signing**: PDF and document signing

### 5. Certificate Revocation

**Process**:
1. Admin revokes certificate via web interface
2. Backend calls Vault PKI: `POST /v1/pki/revoke`
3. Certificate serial number added to CRL
4. Certificate marked as revoked in database

**CRL Distribution**: CRL available at `/v1/pki/crl`

## PKI Configuration

### Automatic Setup

PKI is automatically configured during Helm deployment:

1. **Enable PKI Engine**: `vault secrets enable -path=pki pki`
2. **Configure TTL**: `vault secrets tune -max-lease-ttl=8760h pki`
3. **Generate Root CA**: Create self-signed root certificate
4. **Configure URLs**: Set issuing certificate and CRL URLs
5. **Create PKI Role**: Create `kleidia` role with appropriate settings

## Certificate Operations

### Generate Certificate

**User Flow**:
1. User logs into web interface
2. Navigates to YubiKey device
3. Selects "Generate Certificate"
4. Certificate details automatically configured (CN, SANs, etc.)
5. System generates CSR on YubiKey
6. System signs CSR via Vault PKI
7. System imports certificate to YubiKey
8. Certificate ready for use

### View Certificates

**User Flow**:
1. User navigates to YubiKey device
2. System lists all certificates on YubiKey
3. Shows certificate details:
   - Subject (CN, O, OU, etc.)
   - Issuer
   - Validity period
   - Serial number
   - Key algorithm

### Revoke Certificate

**Admin Flow**:
1. Admin navigates to Yubikey management
2. Selects Yubiky to revoke
3. System revokes certificate in Vault
4. Certificate added to CRL
5. Certificate marked as revoked

## Security Considerations

### Certificate Lifetimes

- **Root CA**: 10 years (~87600h) - Long-lived for stability
- **YubiKey Certificates**: 1 year default (8760h)
- **Annual Rotation**: Renew certificates annually to balance security and usability

### Private Key Security

- **Hardware Storage**: Private keys never leave YubiKey hardware
- **No Key Export**: Private keys cannot be exported from YubiKey
- **Hardware Security**: YubiKey provides tamper-resistant key storage

### Certificate Validation

- **Chain Validation**: Certificates validated against root/intermediate CA
- **CRL Support**: Certificate revocation lists available

## Related Documentation

- [Vault and Secrets](vault-and-secrets.md)
- [Security Overview](security-overview.md)
- [Deployment Guide](../03-deployment/vault-setup.md)

