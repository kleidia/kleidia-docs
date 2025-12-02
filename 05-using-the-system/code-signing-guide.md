# Code Signing with YubiKey

This guide covers how to sign Git commits using YubiKeys with various platforms: Bitbucket, GitLab, and GitHub.

## Overview

YubiKeys support multiple signing methods through different applets:

| Method | Applet | Platforms | Managed by Kleidia |
|--------|--------|-----------|-------------------|
| **X.509/S/MIME** | PIV (slot 9c) | Bitbucket Data Center | ✅ Yes |
| **GPG** | OpenPGP | GitLab, GitHub | ❌ User-managed |
| **SSH** | FIDO2 / PIV | GitHub | ❌ User-managed |

**Important:** The PIV and OpenPGP applets are completely separate on your YubiKey. You can use both simultaneously:
- Kleidia manages your PIV certificates (authentication, code signing, email)
- You can also set up GPG keys on the same YubiKey for GitLab/GitHub

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

### OpenPGP/GPG (GitLab/GitHub) - User-Managed

```
User → gpg --card-edit generate → Self-signed PGP key
                                        ↓
                              User manages key lifecycle:
                              • No central authority required
                              • Web of Trust model (optional)
                              • User controls key expiry
                              • User manages revocation
```

**GitLab/GitHub accept any valid GPG key** - they don't require enterprise CA signing. This is why GPG keys are typically user-managed rather than enterprise-managed.

### Technical Comparison

| Aspect | PIV Slot 9c (Kleidia) | OpenPGP (User) |
|--------|----------------------|----------------|
| **Key Type** | X.509 Certificate | PGP Key |
| **Trust Model** | Hierarchical CA | Web of Trust / Self-signed |
| **PIN** | PIV PIN (Kleidia sets) | OpenPGP PIN (user sets) |
| **Generation** | CSR → CA signs | Direct on device |
| **Revocation** | CRL from CA | PGP revocation cert |
| **Enterprise Control** | Full | None |
| **ykman commands** | `ykman piv` | `ykman openpgp` |

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
│  │ Slot 9a:Auth│  │ Signature   │  │ Passkeys    │     │
│  │ Slot 9c:Sign│  │ Encryption  │  │ WebAuthn    │     │
│  │ Slot 9d:Mail│  │ Auth        │  │ SSH Keys    │     │
│  │             │  │             │  │             │     │
│  │ (Kleidia)   │  │ (gpg)       │  │ (browser)   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

- **PIV**: Managed by Kleidia, uses X.509 certificates
- **OpenPGP**: User-managed via `gpg --card-edit`
- **FIDO2**: User-managed via browser or `ykman fido`

## Which Method Should I Use?

| Platform | Recommended Method | Why |
|----------|-------------------|-----|
| **Bitbucket DC** | X.509 (PIV) | Native support, enterprise CA integration |
| **GitLab** | GPG (OpenPGP) | Native support, well-documented |
| **GitHub** | SSH or GPG | SSH is simpler; GPG for cross-platform |

## Security Considerations

1. **PIV (Kleidia-managed)**
   - Enterprise CA issues certificates
   - Centralized revocation via CRL
   - Certificate lifecycle managed by organization

2. **OpenPGP (user-managed)**
   - User generates and manages keys
   - No central revocation (use key expiration)
   - Web of trust model

3. **FIDO2/SSH**
   - Hardware-bound keys
   - No central management
   - Per-service registration

## Next Steps

Choose your platform guide:
1. **Bitbucket users**: Follow [code-signing-bitbucket.md](./code-signing-bitbucket.md)
2. **GitLab users**: Follow [code-signing-gitlab.md](./code-signing-gitlab.md)
3. **GitHub users**: Follow [code-signing-github.md](./code-signing-github.md)

