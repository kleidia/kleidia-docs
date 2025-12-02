# Code Signing with YubiKey

This guide covers how to sign Git commits using YubiKeys with various platforms: Bitbucket, GitLab, and GitHub.

## Overview

YubiKeys support multiple signing methods through different applets:

| Method | Applet | Platforms | Managed by Kleidia |
|--------|--------|-----------|-------------------|
| **X.509/S/MIME** | PIV (slot 9c) | Bitbucket Data Center | ✅ Yes |
| **GPG** | OpenPGP | GitLab, GitHub | ✅ Yes (Enterprise) |
| **SSH** | FIDO2 / PIV | GitHub | ❌ User-managed |

**Important:** The PIV and OpenPGP applets are completely separate on your YubiKey. You can use both simultaneously:
- Kleidia manages your PIV certificates (authentication, code signing, email)
- Kleidia can now manage OpenPGP keys for enterprise policy enforcement (optional)

## Platform-Specific Guides

- [Bitbucket Code Signing](./code-signing-bitbucket.md) - X.509 certificates (Kleidia-managed)
- [GitLab Code Signing](./code-signing-gitlab.md) - GPG keys (user-managed)
- [GitHub Code Signing](./code-signing-github.md) - GPG or SSH keys (user-managed)

## Why Different Methods?

### PIV/X.509 (Bitbucket) - Enterprise-Managed

```
User → Generate key on YubiKey → CSR → OpenBao CA signs → Certificate imported
                                              ↓
                                 Enterprise trust hierarchy:
                                 • Central CA controls issuance
                                 • CRL enables revocation
                                 • Certificate expiry enforced
                                 • Audit trail maintained
```

**Bitbucket requires** certificates signed by a trusted CA. The CA chain must be imported into Bitbucket for verification.

### OpenPGP/GPG (GitLab/GitHub) - Enterprise-Managed (Optional)

Kleidia now supports enterprise management of OpenPGP keys on YubiKeys:

```
Enterprise Mode (Kleidia):
User → Kleidia UI → Generate key on YubiKey → Self-signed PGP key
                              ↓
                   Enterprise manages lifecycle:
                   • Central PIN management (stored in Vault)
                   • Touch policy enforcement
                   • Algorithm compliance
                   • Attestation for compliance audits

Traditional Mode (User-managed):
User → gpg --card-edit generate → Self-signed PGP key
                              ↓
                   User manages key lifecycle:
                   • No central authority required
                   • Web of Trust model (optional)
                   • User controls key expiry
```

**GitLab/GitHub accept any valid GPG key** - they don't require enterprise CA signing. However, enterprises may choose to manage OpenPGP keys via Kleidia for consistent policy enforcement and PIN recovery capabilities.

### Technical Comparison

| Aspect | PIV Slot 9c (Kleidia) | OpenPGP (Kleidia) | OpenPGP (User) |
|--------|----------------------|-------------------|----------------|
| **Key Type** | X.509 Certificate | PGP Key | PGP Key |
| **Trust Model** | Hierarchical CA | Self-signed | Web of Trust / Self-signed |
| **PIN** | PIV PIN (Kleidia sets) | OpenPGP PIN (Kleidia sets) | OpenPGP PIN (user sets) |
| **Generation** | CSR → CA signs | Direct on device via UI | Direct on device |
| **Revocation** | CRL from CA | Key deletion | PGP revocation cert |
| **Enterprise Control** | Full | Full (PIN, touch, algorithms) | None |
| **Vault Storage** | PIN, PUK, Mgmt Key | User PIN, Admin PIN | None |
| **ykman commands** | `ykman piv` | `ykman openpgp` | `ykman openpgp` |

## Quick Comparison

### Bitbucket Data Center (X.509)
```bash
# Uses Kleidia-managed PIV certificate (slot 9c)
# Requires smimesign
git config --global gpg.x509.program smimesign
git config --global gpg.format x509
git commit -S -m "Signed commit"
```

### GitLab (GPG)
```bash
# Uses user-managed OpenPGP key on YubiKey
# Key generated with gpg --card-edit
git config --global gpg.program gpg
git config --global commit.gpgsign true
git commit -S -m "Signed commit"
```

### GitHub (GPG or SSH)
```bash
# Option 1: GPG (same as GitLab)
git config --global gpg.program gpg
git config --global commit.gpgsign true

# Option 2: SSH signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_sk.pub
```

## Understanding YubiKey Applets

Your YubiKey contains multiple independent applications:

```
┌─────────────────────────────────────────────────────────┐
│                      YubiKey                            │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │    PIV      │  │   OpenPGP   │  │   FIDO2     │     │
│  │             │  │             │  │             │     │
│  │ Slot 9a:Auth│  │ SIG: Sign   │  │ Passkeys    │     │
│  │ Slot 9c:Sign│  │ ENC: Encrypt│  │ WebAuthn    │     │
│  │ Slot 9d:Mail│  │ AUT: Auth   │  │ SSH Keys    │     │
│  │             │  │             │  │             │     │
│  │ (Kleidia)   │  │ (Kleidia/   │  │ (browser)   │     │
│  │             │  │  gpg)       │  │             │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

- **PIV**: Managed by Kleidia, uses X.509 certificates
- **OpenPGP**: Enterprise-managed via Kleidia UI or user-managed via `gpg --card-edit`
- **FIDO2**: User-managed via browser or `ykman fido`

## Which Method Should I Use?

| Platform | Recommended Method | Why |
|----------|-------------------|-----|
| **Bitbucket DC** | X.509 (PIV) | Native support, enterprise CA integration |
| **GitLab** | GPG (OpenPGP) | Native support, well-documented |
| **GitHub** | SSH or GPG | SSH is simpler; GPG for cross-platform |

## Enterprise OpenPGP Management (New)

Kleidia now provides enterprise management for OpenPGP keys on YubiKeys. This is optional - users can still use `gpg --card-edit` directly if preferred.

### Features

| Feature | Description |
|---------|-------------|
| **Key Generation** | Generate SIG, ENC, AUT keys via Kleidia UI |
| **Algorithm Policy** | Enforce RSA2048, RSA4096, ECCP256, Curve25519, etc. |
| **Touch Policy** | Require physical touch for all operations |
| **PIN Management** | User PIN (6-127 chars) and Admin PIN (8-127 chars) |
| **Vault Storage** | PINs stored in Vault for enterprise recovery |
| **Attestation** | Export hardware attestation certificates |

### Using Kleidia-Managed OpenPGP

1. **Navigate to your YubiKey** in the Kleidia dashboard
2. **Select the OpenPGP tab**
3. **Generate keys** for Signature, Encryption, and/or Authentication slots
4. **Set touch policies** if required by your security policy
5. **Change PINs** from defaults (123456 for User, 12345678 for Admin)

After key generation, export your public key for use with GitLab/GitHub:
```bash
# List keys on the YubiKey
gpg --card-status

# Export public key
gpg --armor --export your-email@company.com > my-key.asc

# Upload to GitLab/GitHub
```

### Policy Enforcement

Administrators can configure OpenPGP policies in **Admin → Security Policies → OpenPGP Policies**:
- Require touch for all operations
- Allowed algorithms
- Minimum PIN/Admin PIN lengths
- Require PIN change from default

## Security Considerations

1. **PIV (Kleidia-managed)**
   - Enterprise CA issues certificates
   - Centralized revocation via CRL
   - Certificate lifecycle managed by organization

2. **OpenPGP (Kleidia-managed)**
   - Self-signed keys (no CA required)
   - Enterprise policy enforcement
   - PIN recovery via Vault
   - Touch policy enforcement
   - Hardware attestation

3. **OpenPGP (user-managed)**
   - User generates and manages keys
   - No central revocation (use key expiration)
   - Web of trust model

4. **FIDO2/SSH**
   - Hardware-bound keys
   - No central management
   - Per-service registration

## Next Steps

Choose your platform guide:
1. **Bitbucket users**: Follow [code-signing-bitbucket.md](./code-signing-bitbucket.md)
2. **GitLab users**: Follow [code-signing-gitlab.md](./code-signing-gitlab.md)
3. **GitHub users**: Follow [code-signing-github.md](./code-signing-github.md)

