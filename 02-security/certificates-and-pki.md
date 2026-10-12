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

The system uses a general-purpose PKI role named `yubikey-piv`, plus slot-specific roles (`yubikey-piv-auth`, `yubikey-piv-code-signing`, `yubikey-piv-email-signing`) used for the corresponding PIV slots. The base `yubikey-piv` role uses the following settings:

| Setting             | Value    | Purpose                                  |
|---------------------|----------|------------------------------------------|
| `allow_any_name`    | `true`   | Allows certificates with any common name |
| `enforce_hostnames` | `false`  | Disables hostname validation             |
| `server_flag`       | `true`   | Permits server-auth certificates         |
| `client_flag`       | `true`   | Permits client-auth certificates         |
| `key_type`          | `rsa`    | RSA key type (YubiKey standard)          |
| `key_bits`          | `2048`   | 2048-bit RSA keys                        |
| `ttl`               | `8760h`  | Default certificate lifetime (1 year)    |
| `max_ttl`           | `87600h` | Maximum certificate lifetime (10 years)  |

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
1. Frontend sends CSR to backend: `POST /api/yubikeys/{serial}/sign-csr`
2. Backend authenticates to Vault using AppRole
3. Backend submits CSR to Vault PKI: `POST /v1/pki/sign/yubikey-piv` (or a slot-specific role such as `yubikey-piv-auth`)
4. Vault signs CSR using root CA
5. Backend receives signed certificate

**Certificate Properties**:
- **Issuer**: Kleidia Root CA
- **Validity**: 1 year (8760h, configurable via PKI role)
- **Key Usage / Extended Key Usage**: set per slot by the slot's role:

| Slot | Role | Key Usage | Extended Key Usage |
|------|------|-----------|--------------------|
| 9a (authentication) | `yubikey-piv-auth` | Digital signature, key encipherment | Client authentication, Smart Card Logon (`1.3.6.1.4.1.311.20.2.2`) |
| 9c (digital signature) | `yubikey-piv-code-signing` | Digital signature | Code signing |
| 9d (S/MIME signing) | `yubikey-piv-email-signing` | Digital signature | Email protection |

Slot 9d is **signing only** since 2.5.0. Kleidia does not provide S/MIME encryption: the 9d key is generated on the YubiKey and cannot be archived, so mail encrypted to it would be unreadable for good after a PIV reset or a lost key. 9d certificates issued by 2.4.6 or earlier also carry key encipherment until they are reissued or expire; nothing is revoked on upgrade.

### Issuance policy OIDs for AD strong name-based mapping (slot 9a)

Active Directory domain controllers (Windows Server 2019 or later) can accept a name-based mapping (UPN) as a strong mapping when the certificate carries an issuance policy OID that your PKI attests to. The domain controller policy is **Allow name-based strong mappings for certificates** (Computer Configuration > Administrative Templates > System > KDC). Each rule in it is a tuple of the issuing CA thumbprint, the OID(s) and the mapping type, for example `<issuing CA thumbprint>;<OID>;UPNSuffix=<your UPN suffix>`. Microsoft recommends this only when your PKI meets its requirements for it; read Microsoft's guidance on strong name-based mapping and KB5014754 before enabling it.

To stamp the OIDs on slot 9a certificates (certificate policies extension), set them in the `kleidia-platform` values:

```yaml
openbao:
  pki:
    pivAuth:
      policyIdentifiers: ["1.3.6.1.4.1.<your-PEN>.1.1"]   # OIDs from your own organization's arc
```

- Empty by default: 9a certificates carry no issuance policy.
- Each value is validated as a dotted-decimal OID when the chart renders; an invalid value fails the install or upgrade.
- Only the `yubikey-piv-auth` (9a) role gets the OIDs. The value applies to 9a certificates issued after the next `helm upgrade`; existing 9a certificates must be reissued to carry an OID.
- With an [external Vault](../03-deployment/external-vault.md), set `policy_identifiers` on your own `yubikey-piv-auth` role instead.

### 3. Certificate Import

**Location**: User workstation (agent)  
**Process**:
1. Backend returns signed certificate to frontend
2. Frontend sends certificate to agent: `POST http://127.0.0.1:56123/piv/import-certificate`
3. Agent imports certificate to YubiKey PIV slot (9a, 9c, 9d, or 9e)
4. Certificate stored on YubiKey hardware
5. Agent (2.5.0+) reads the slot back and returns the SHA-256 fingerprint of the certificate now on the card
6. Frontend reports the install result per slot to the backend

**Security**: Certificate stored securely on YubiKey hardware

### Certificate Install Verification

Since 2.5.0 Kleidia tracks whether every issued PIV certificate actually reached the YubiKey. Each issued certificate starts as `pending`; the install report from the browser moves it to a final state:

| State | Meaning | Action |
|-------|---------|--------|
| `installed` | The agent read the certificate back and it matches the one issued | None |
| `unverified` | The browser reports the import, but the agent is older than 2.5.0 and cannot read it back | None |
| `failed` | The import failed after one retry | Issued certificate revoked automatically |
| `mismatch` | The YubiKey holds a different certificate than the one issued | Issued certificate revoked automatically |
| `unconfirmed` | No report arrived within 15 minutes (browser closed, agent unreachable) | Never revoked; check the slot with the user |

A report about a certificate that a newer issuance has already replaced is ignored and never revokes anything. Every result writes a `piv_certificate_install` audit row (slot, result, certificate serial, operation ID) and increments `kleidia_piv_certificate_install_total` (see [Monitoring and Logs](../04-operations/monitoring-and-logs.md)).

### Operation ID

Each issuance flow (provisioning, certificate generation, PIN/PUK/management key change, reset) gets one operation ID, generated in the browser. It travels to the backend in the `X-Kleidia-Operation-ID` header and to the agent in the request body, and appears as `op=<id>` in backend and agent logs and as `operation_id` in the audit rows of that flow. Use it to follow one issuance across browser, backend, agent and audit log.

### 4. Certificate Usage

Certificates can be used for:
- **Client Authentication**: TLS client certificates
- **Email Signing**: S/MIME email signing (slot 9d; signing only, no S/MIME encryption)
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
2. **Configure TTL**: `vault secrets tune -max-lease-ttl=87600h pki`
3. **Generate Root CA**: Create self-signed root certificate
4. **Configure URLs**: Set issuing certificate and CRL URLs
5. **Create PKI Roles**: Create the `yubikey-piv` role (and slot-specific roles) with appropriate settings

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
8. System verifies the certificate on the YubiKey and records the install result
9. Certificate ready for use

Self-service certificate generation is refused while the YubiKey still has the factory-default PUK, and when that check fails. YubiKeys with firmware before 5.3 cannot report their PUK state and are not checked.

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

