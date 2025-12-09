# Bitbucket Code Signing with X.509 Certificates

This guide explains how to configure your development environment to sign Git commits and tags using X.509 certificates stored on your YubiKey, enabling verified signatures in Bitbucket Data Center.

## Prerequisites

Before you begin, ensure you have:

1. **YubiKey with enrolled certificates** - Your YubiKey must have the Code Signing certificate (slot 9c) enrolled through Kleidia
2. **smimesign** - Tool for signing commits with X.509 certificates
3. **Git** - Version 2.19 or later recommended
4. **Bitbucket Data Center** - Version 8.15 or later (with X.509 signing support)

## Step 1: Install smimesign

### macOS

```bash
# Using Homebrew
brew install smimesign
```

### Windows

Download the latest release from the [smimesign GitHub releases page](https://github.com/github/smimesign/releases) and add it to your PATH.

### Linux

```bash
# Download and install
curl -L https://github.com/github/smimesign/releases/latest/download/smimesign-linux-amd64 -o /usr/local/bin/smimesign
chmod +x /usr/local/bin/smimesign
```

## Step 2: Find Your Certificate ID

With your YubiKey plugged in, list available certificates:

```bash
smimesign --list-keys
```

You should see output similar to:

```
       ID: 4df4ce209319b0904fb3f2813115d5e4438e8c3c
      S/N: 468e1711b4ade3fc
Algorithm: SHA256-RSA
 Validity: 2024-01-01 00:00:00 +0000 UTC - 2025-01-01 00:00:00 +0000 UTC
   Issuer: CN=Kleidia Intermediate CA,O=Your Organization
  Subject: John Doe <john.doe@example.com>
   Emails: john.doe@example.com
```

**Important:** Note the `ID` value - you'll need this for Git configuration. The email address shown must match your Bitbucket user account email.

## Step 3: Configure Git for X.509 Signing

### Global Configuration (All Repositories)

```bash
# Set smimesign as the signing program
git config --global gpg.x509.program smimesign
git config --global gpg.format x509

# Set your signing key (use the ID from step 2)
git config --global user.signingkey 4df4ce209319b0904fb3f2813115d5e4438e8c3c

# Optional: Sign all commits automatically
git config --global commit.gpgsign true
```

### Per-Repository Configuration

If you only want to use X.509 signing for specific repositories:

```bash
cd /path/to/your/repo
git config --local gpg.x509.program smimesign
git config --local gpg.format x509
git config --local user.signingkey 4df4ce209319b0904fb3f2813115d5e4438e8c3c
git config --local commit.gpgsign true
```

## Step 4: Sign Your First Commit

### Signing Commits

```bash
# Sign a single commit
git commit -S -m "My signed commit message"

# If you enabled commit.gpgsign, all commits are signed automatically
git commit -m "This commit is automatically signed"
```

When you run the commit command, you'll be prompted for your YubiKey PIN.

### Signing Tags

```bash
git tag -s v1.0.0 -m "Release version 1.0.0"
```

### Verify Signatures Locally

```bash
# View commit signatures
git log --show-signature

# Verify a specific commit
git verify-commit HEAD

# Verify a tag
git verify-tag v1.0.0
```

## Step 5: Verify in Bitbucket

Once your commits are pushed to Bitbucket, you should see:

1. **Verified badge** - Commits signed with a trusted certificate show a "Verified" badge
2. **Certificate details** - Click on the badge to see certificate information

### Troubleshooting Unverified Signatures

If your signatures appear as "Unverified" in Bitbucket:

1. **Email mismatch** - Ensure the email in your certificate matches your Bitbucket account email
2. **CA not trusted** - Ask your Bitbucket administrator to import the CA chain (see Admin Guide below)
3. **Certificate revoked** - Check if your certificate has been revoked
4. **Certificate expired** - Generate a new certificate through Kleidia

## Administrator Guide: Importing CA Chain

Bitbucket administrators must import the Kleidia CA chain before user signatures can be verified.

### Export CA Chain from Kleidia

1. Log into Kleidia as an administrator
2. Navigate to **Settings** → **OpenBao CA**
3. Click **Load CA Chain** in the "Export CA Chain for Bitbucket" section
4. Copy or download the CA chain PEM file

### Import into Bitbucket

**Via Web Interface:**

1. Log into Bitbucket as an administrator
2. Navigate to **Administration** → **Security** → **Signing certificates**
3. Click **Add certificate chain**
4. Paste the CA chain from Kleidia
5. Click **Save**

**Via REST API:**

```bash
curl -u admin:password -X POST \
  "https://your-bitbucket.example.com/rest/api/latest/signing/certificate-chains" \
  -H "Content-Type: application/json" \
  -d '{"certificateChain": "<paste CA chain PEM here>"}'
```

### Configure External CRL Access

For Bitbucket to check certificate revocation status, it must be able to access the CRL distribution point. This requires:

1. **Network access** - Bitbucket server must be able to reach the Kleidia PKI endpoint
2. **PKI URL configuration** - Set `openbao.pki.urls.externalBaseUrl` in Kleidia Helm values to an externally accessible URL
   - Ensure your load balancer exposes OpenBao on TCP 8200 at that DNS name

Example Helm values:

```yaml
openbao:
  pki:
    urls:
      externalBaseUrl: "https://pki.example.com:8200" # replace with your public PKI endpoint
      crlExpiry: "24h"
```

## Security Best Practices

1. **Protect your YubiKey PIN** - Use a strong PIN and never share it
2. **Keep YubiKey secure** - Store your YubiKey safely when not in use
3. **Use dedicated signing key** - The Code Signing certificate (slot 9c) is separate from authentication
4. **Regular certificate renewal** - Certificates have expiration dates; renew before they expire
5. **Report lost YubiKeys** - If your YubiKey is lost or stolen, report it immediately so certificates can be revoked

## Troubleshooting

### "No signing keys available"

```bash
# Ensure YubiKey is plugged in
smimesign --list-keys

# If empty, verify certificate is on YubiKey
ykman piv info
```

### "PIN required" errors

You'll be prompted for your YubiKey PIN when signing. If you see repeated prompts:

- Verify your PIN is correct
- Check if PIN is blocked (too many wrong attempts)
- Use Kleidia to check PIN retry count

### "Certificate not trusted"

Contact your Bitbucket administrator to import the CA chain.

### Git commit hangs

This may occur if:

- YubiKey is not plugged in
- Smart card service is not running
- Conflicting smart card applications

Try:

```bash
# Restart smart card service (macOS)
sudo pkill -9 pcscd

# Windows
# Restart "Smart Card" service in Services.msc
```

## References

- [Bitbucket X.509 Documentation](https://confluence.atlassian.com/bitbucketserver/sign-commits-and-tags-with-x-509-certificates-1305971206.html)
- [smimesign GitHub](https://github.com/github/smimesign)
- [Git Signing Documentation](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work)

