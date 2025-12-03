# PKI Integration Patterns

**Audience**: PKI Engineers, Security Architects, Infrastructure Engineers  
**Prerequisites**: Familiarity with your organization's PKI infrastructure, certificate hierarchies, and OpenBao/Vault  
**Outcome**: Understand how to integrate Kleidia's PKI with your existing certificate authority infrastructure

## Overview

Kleidia uses OpenBao as its PKI engine for issuing YubiKey PIV certificates. In production environments, OpenBao should be configured as an **intermediate CA** subordinate to your existing enterprise PKI. This ensures that certificates issued to YubiKeys chain to your organization's trusted root CA.

> **Production Requirement**: Always configure Kleidia's OpenBao PKI as an intermediate CA under your existing PKI hierarchy. Self-signed root CAs should only be used for lab and PoC environments.

## Integration Patterns

### Pattern 1: Microsoft AD CS Integration

The most common enterprise pattern—OpenBao operates as an intermediate CA under your Active Directory Certificate Services hierarchy.

```
┌─────────────────────────────────────────────────────┐
│            AD CS Root CA (Offline)                  │
│            CN=Contoso-Root-CA                       │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│            AD CS Issuing CA (Online)                │
│            CN=Contoso-Issuing-CA                    │
└───────────────────────┬─────────────────────────────┘
                        │ Signs OpenBao intermediate
                        ▼
┌─────────────────────────────────────────────────────┐
│       OpenBao Intermediate CA (Kleidia)             │
│       CN=Kleidia-YubiKey-CA                         │
│       Path constraints: pathlen=0                   │
└───────────────────────┬─────────────────────────────┘
                        │ Signs end-entity certs
                        ▼
┌─────────────────────────────────────────────────────┐
│         YubiKey PIV Certificates                    │
│         (Authentication, Signing, Encryption)       │
└─────────────────────────────────────────────────────┘
```

**Key Ownership**:
| Component | Key Location | Managed By |
|-----------|--------------|------------|
| AD CS Root CA | HSM or offline server | PKI Team |
| AD CS Issuing CA | HSM or server | PKI Team |
| OpenBao Intermediate | OpenBao seal/storage | Kleidia + PKI Team |
| YubiKey Private Keys | YubiKey hardware | End Users |

**CRL/OCSP Sources**:
- AD CS publishes CRL for root and issuing CA
- OpenBao publishes CRL for Kleidia intermediate
- Configure CRL distribution points in certificate templates

**Setup Steps**:

1. **Generate CSR in OpenBao**:
   ```bash
   vault write pki/intermediate/generate/internal \
     common_name="Kleidia-YubiKey-CA" \
     key_type="rsa" \
     key_bits="4096"
   ```

2. **Submit CSR to AD CS** (via MMC or certreq):
   ```powershell
   certreq -submit -attrib "CertificateTemplate:SubCA" kleidia-ca.csr kleidia-ca.cer
   ```

3. **Import signed certificate to OpenBao**:
   ```bash
   vault write pki/intermediate/set-signed certificate=@kleidia-ca.cer
   ```

4. **Configure PKI role for Kleidia**:
   ```bash
   vault write pki/roles/kleidia \
     allow_any_name=true \
     enforce_hostnames=false \
     max_ttl="8760h"
   ```

---

### Pattern 2: EJBCA / Generic CA Integration

For organizations using EJBCA, Dogtag, or other certificate authorities.

```
┌─────────────────────────────────────────────────────┐
│            Enterprise Root CA                       │
│            (EJBCA, Dogtag, other)                   │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│       OpenBao Intermediate CA (Kleidia)             │
│       Signed by enterprise CA                       │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│         YubiKey PIV Certificates                    │
└─────────────────────────────────────────────────────┘
```

**Key Ownership**:
| Component | Key Location | Managed By |
|-----------|--------------|------------|
| Enterprise Root CA | HSM | PKI Team |
| OpenBao Intermediate | OpenBao seal/storage | Kleidia + PKI Team |
| YubiKey Private Keys | YubiKey hardware | End Users |

**Setup Steps**:

1. **Generate CSR in OpenBao** (same as Pattern 1)

2. **Sign CSR using your CA's interface** (varies by CA product)

3. **Import signed certificate and chain to OpenBao**:
   ```bash
   vault write pki/intermediate/set-signed \
     certificate=@kleidia-ca.cer
   
   # If chain needed separately:
   vault write pki/config/ca pem_bundle=@full-chain.pem
   ```

---

### Pattern 3: Existing Vault/OpenBao PKI

If you already operate HashiCorp Vault or OpenBao with a PKI secrets engine, Kleidia can use a dedicated PKI backend or role within your existing infrastructure.

```
┌─────────────────────────────────────────────────────┐
│         Existing Vault/OpenBao Cluster              │
│                                                     │
│  ┌──────────────────┐    ┌──────────────────┐      │
│  │ pki/ (existing)  │    │ pki-kleidia/     │      │
│  │ General purpose  │    │ Dedicated for    │      │
│  │                  │    │ YubiKey certs    │      │
│  └──────────────────┘    └────────┬─────────┘      │
│                                   │                 │
└───────────────────────────────────│─────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────┐
│         YubiKey PIV Certificates                    │
└─────────────────────────────────────────────────────┘
```

**Options**:

| Approach | Description | Pros | Cons |
|----------|-------------|------|------|
| **Dedicated mount** (`pki-kleidia/`) | Separate PKI backend for Kleidia | Clear separation, independent policies | Additional configuration |
| **Dedicated role** (`pki/roles/kleidia`) | Role in existing PKI backend | Simpler setup | Shared backend policies |

**Key Ownership**:
| Component | Key Location | Managed By |
|-----------|--------------|------------|
| Root/Intermediate CA | Your existing Vault/OpenBao | Your PKI/Security Team |
| Kleidia PKI role | Your existing Vault/OpenBao | Kleidia + Security Team |
| YubiKey Private Keys | YubiKey hardware | End Users |

**Configuration**:

For dedicated mount approach:
```bash
# Enable dedicated PKI backend
vault secrets enable -path=pki-kleidia pki

# Generate or import intermediate CA
vault write pki-kleidia/intermediate/generate/internal \
  common_name="Kleidia YubiKey CA"

# Sign with your root (if OpenBao is also root)
vault write pki/root/sign-intermediate \
  csr=@kleidia-csr.pem \
  ttl="43800h"

# Import signed cert
vault write pki-kleidia/intermediate/set-signed certificate=@signed.pem

# Create Kleidia role
vault write pki-kleidia/roles/kleidia \
  allow_any_name=true \
  enforce_hostnames=false \
  max_ttl="8760h"
```

---

## What Kleidia Automates

Regardless of integration pattern, Kleidia automates these PKI operations:

| Operation | Automation |
|-----------|------------|
| **CSR Generation** | Agent generates CSR on YubiKey hardware |
| **Certificate Signing** | Backend submits CSR to OpenBao PKI role |
| **Certificate Import** | Agent imports signed cert to YubiKey slot |
| **Certificate Renewal** | Web UI workflow for regeneration |
| **Certificate Revocation** | Backend calls OpenBao revoke API, updates CRL |
| **Audit Logging** | All operations logged to database |

**Not automated by Kleidia** (requires PKI team):
- Root CA key ceremonies
- Intermediate CA CSR signing (initial setup)
- CRL/OCSP infrastructure for root and issuing CAs
- CA certificate rotation

---

## CRL and OCSP Configuration

### CRL Distribution Points

Configure OpenBao to publish CRL at an accessible URL:

```bash
vault write pki/config/urls \
  issuing_certificates="https://pki.example.com/v1/pki/ca" \
  crl_distribution_points="https://pki.example.com/v1/pki/crl" \
  ocsp_servers="https://pki.example.com/v1/pki/ocsp"
```

### OCSP Responder

OpenBao includes a built-in OCSP responder. Enable and configure based on your requirements for real-time revocation checking.

---

## Security Recommendations

1. **Use HSM for CA keys**: Protect intermediate CA private key with HSM or Vault auto-unseal
2. **Path constraints**: Set `pathlen=0` on Kleidia intermediate to prevent further sub-CA issuance
3. **Short-lived certificates**: Consider 1-year maximum TTL for end-entity certificates
4. **Network isolation**: Restrict OpenBao PKI access to Kleidia backend only
5. **Audit logging**: Enable Vault audit logging for all PKI operations

---

## Related Documentation

- [Certificates & PKI Overview](../security/certificates-and-pki/)
- [Vault Setup Guide](vault-setup/)
- [Security Overview for Auditors](../security/for-auditors/)

