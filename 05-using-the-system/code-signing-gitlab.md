# GitLab Code Signing with GPG

Sign Git commits with GPG keys stored on your YubiKey for GitLab verification.

> **Note:** This guide uses the **OpenPGP applet** on your YubiKey, which is separate from the PIV certificates managed by Kleidia. You can use both simultaneously.

## Prerequisites

- YubiKey 5 series or newer
- GnuPG installed
- YubiKey Manager (optional but helpful)

## Understanding the Difference

| Feature | PIV (Kleidia) | OpenPGP (This Guide) |
|---------|---------------|----------------------|
| Key Type | X.509 Certificate | GPG Key |
| Management | Enterprise-managed | User-managed |
| Platform | Bitbucket | GitLab, GitHub |
| Tool | smimesign | gpg |

**Both can coexist on your YubiKey** - they use different applets.

## Step 1: Install Required Software

### macOS
```bash
brew install gnupg pinentry-mac
brew install --cask yubico-yubikey-manager

# Configure pinentry for GPG
echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

### Linux (Ubuntu/Debian)
```bash
sudo apt install gnupg2 scdaemon pcscd yubikey-manager
```

### Windows
Download and install [Gpg4win](https://gpg4win.org/).

## Step 2: Check YubiKey GPG Status

```bash
gpg --card-status
```

You should see your YubiKey information. If not, ensure:
- YubiKey is connected
- `pcscd` service is running (Linux)
- No conflicting applications are using the YubiKey

## Step 3: Generate GPG Keys on YubiKey

> **Important:** Generating keys directly on the YubiKey is more secure as the private key never exists outside the hardware.

```bash
# Start GPG card edit mode
gpg --card-edit

# Enter admin mode
gpg/card> admin

# Generate keys on card
gpg/card> generate

# Follow the prompts:
# - Make off-card backup? No (more secure)
# - Key expires? Set expiration (recommended: 1-2 years)
# - Real name: Your Full Name
# - Email: your.email@example.com (must match GitLab account)
# - Comment: (optional)

# Default PINs:
# - User PIN: 123456
# - Admin PIN: 12345678

# When done
gpg/card> quit
```

### Change Default PINs (Recommended)

```bash
gpg --card-edit

gpg/card> admin
gpg/card> passwd

# Option 1: Change PIN
# Option 3: Change Admin PIN
```

## Step 4: Export Public Key

```bash
# List keys to get your key ID
gpg --list-secret-keys --keyid-format LONG

# Output shows something like:
# sec>  rsa4096/ABCD1234EFGH5678 2024-01-01 [SC]
#       Key fingerprint = ...
# ssb>  rsa4096/...

# Export public key (use your key ID)
gpg --armor --export ABCD1234EFGH5678
```

## Step 5: Add Public Key to GitLab

1. Copy the output from the export command (including `-----BEGIN PGP PUBLIC KEY BLOCK-----` and `-----END PGP PUBLIC KEY BLOCK-----`)

2. In GitLab:
   - Click your avatar → **Preferences**
   - Select **GPG Keys** in the sidebar
   - Click **Add new key**
   - Paste your public key
   - Click **Add key**

## Step 6: Configure Git

```bash
# Set your signing key
git config --global user.signingkey ABCD1234EFGH5678

# Enable automatic commit signing
git config --global commit.gpgsign true

# Ensure GPG uses the correct TTY
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc
```

## Step 7: Sign Commits

```bash
# Create a signed commit
git commit -S -m "My signed commit"

# You'll be prompted for your YubiKey PIN
# Touch the YubiKey when the light blinks
```

### Sign Tags

```bash
git tag -s v1.0.0 -m "Release version 1.0.0"
```

## Step 8: Verify Signatures

### Locally
```bash
git log --show-signature
git verify-commit HEAD
```

### In GitLab
- Navigate to your commit
- Look for the **Verified** badge
- Click for signature details

## Troubleshooting

### "No secret key" Error
```bash
# Restart GPG agent
gpgconf --kill gpg-agent

# Reconnect YubiKey and try again
```

### "Card error" on Linux
```bash
# Restart smart card daemon
sudo systemctl restart pcscd
```

### PIN Entry Not Appearing
```bash
# Ensure GPG_TTY is set
export GPG_TTY=$(tty)

# For GUI applications, use pinentry-mac (macOS) or pinentry-qt (Linux)
```

### Multiple YubiKeys
If you have multiple YubiKeys with GPG keys:
```bash
# List available cards
gpg --card-status

# If wrong card, remove and insert correct one
```

## Using Both PIV and OpenPGP

Your YubiKey can simultaneously hold:
- **PIV certificates** (Kleidia-managed) for Bitbucket
- **OpenPGP keys** (user-managed) for GitLab

To verify both are working:
```bash
# Check PIV (for Bitbucket)
smimesign --list-keys

# Check OpenPGP (for GitLab)
gpg --card-status
```

## Backup Recommendations

Since GPG keys generated on-card cannot be extracted:

1. **Keep a backup YubiKey** with the same GPG key (generate during initial setup)
2. **Set key expiration** to force periodic renewal
3. **Document your key ID** securely
4. **Register backup YubiKey** with GitLab

## References

- [GitLab + Yubico Blog Post](https://about.gitlab.com/blog/secure-and-safe-login-and-commits-with-gitlab-yubico/)
- [GitLab GPG Signing Documentation](https://docs.gitlab.com/ee/user/project/repository/signed_commits/gpg.html)
- [Yubico OpenPGP Guide](https://support.yubico.com/hc/en-us/articles/360013790259-Using-Your-YubiKey-with-OpenPGP)
- [GnuPG Documentation](https://www.gnupg.org/documentation/)

