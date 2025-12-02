# GitHub Code Signing with YubiKey

Sign Git commits for GitHub using either GPG or SSH keys stored on your YubiKey.

> **Note:** GitHub does **not** support X.509/S/MIME signing. Use GPG or SSH instead.

## Signing Methods Comparison

| Method | Applet | Pros | Cons |
|--------|--------|------|------|
| **GPG** | OpenPGP | Cross-platform, works with GitLab too | More complex setup |
| **SSH** | FIDO2 | Simple setup, hardware-bound | GitHub/newer Git only |

## Option 1: SSH Signing (Recommended)

SSH signing is simpler and uses FIDO2 resident keys on your YubiKey.

### Prerequisites
- Git 2.34 or later
- OpenSSH 8.2 or later
- YubiKey with FIDO2 support

### Step 1: Generate SSH Key on YubiKey

```bash
# Generate FIDO2 resident key (stored on YubiKey)
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "your.email@example.com"

# You'll be prompted to:
# 1. Touch your YubiKey
# 2. Enter YubiKey FIDO2 PIN
# 3. Choose file location (default: ~/.ssh/id_ed25519_sk)
```

Options explained:
- `-t ed25519-sk`: ED25519 with security key
- `-O resident`: Store key on YubiKey (survives re-enrollment)
- `-O verify-required`: Require PIN + touch

### Step 2: Add SSH Key to GitHub

1. Copy your public key:
   ```bash
   cat ~/.ssh/id_ed25519_sk.pub
   ```

2. In GitHub:
   - Go to **Settings** → **SSH and GPG keys**
   - Click **New SSH key**
   - Title: "YubiKey Signing Key"
   - Key type: **Signing Key**
   - Paste your public key
   - Click **Add SSH key**

### Step 3: Configure Git for SSH Signing

```bash
# Set SSH as signing format
git config --global gpg.format ssh

# Set your signing key
git config --global user.signingkey ~/.ssh/id_ed25519_sk.pub

# Enable automatic signing
git config --global commit.gpgsign true

# Set allowed signers file (for local verification)
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers

# Add yourself to allowed signers
echo "your.email@example.com $(cat ~/.ssh/id_ed25519_sk.pub)" >> ~/.ssh/allowed_signers
```

### Step 4: Sign Commits

```bash
git commit -S -m "My signed commit"

# Touch YubiKey and enter FIDO2 PIN when prompted
```

---

## Option 2: GPG Signing

GPG signing uses the OpenPGP applet, same as GitLab.

### Step 1: Set Up GPG on YubiKey

Follow the same steps as [GitLab GPG setup](./code-signing-gitlab.md#step-1-install-required-software):

```bash
# Install GPG
# macOS: brew install gnupg
# Linux: sudo apt install gnupg2 scdaemon

# Generate key on YubiKey
gpg --card-edit
gpg/card> admin
gpg/card> generate
```

### Step 2: Export and Add to GitHub

```bash
# Get your key ID
gpg --list-secret-keys --keyid-format LONG

# Export public key
gpg --armor --export YOUR_KEY_ID
```

In GitHub:
1. **Settings** → **SSH and GPG keys**
2. Click **New GPG key**
3. Paste your public key
4. Click **Add GPG key**

### Step 3: Configure Git for GPG

```bash
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true
git config --global gpg.program gpg

# Ensure GPG uses correct TTY
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

---

## Verifying Signatures

### Locally

```bash
# SSH signatures
git log --show-signature

# GPG signatures  
git verify-commit HEAD
```

### On GitHub

1. Navigate to your commit
2. Look for **Verified** badge
3. Click for signature details

### Verification Statuses

| Status | Meaning |
|--------|---------|
| **Verified** | Signature valid, key belongs to committer |
| **Partially verified** | Signature valid, but email not verified |
| **Unverified** | Signature couldn't be verified |

---

## Using Both SSH and GPG

You can switch between methods per-repository:

```bash
# For SSH signing in a repo
cd ~/projects/ssh-signed-repo
git config --local gpg.format ssh
git config --local user.signingkey ~/.ssh/id_ed25519_sk.pub

# For GPG signing in another repo
cd ~/projects/gpg-signed-repo
git config --local gpg.format openpgp
git config --local user.signingkey YOUR_GPG_KEY_ID
```

---

## Vigilant Mode

GitHub's Vigilant Mode marks unsigned commits as "Unverified":

1. Go to **Settings** → **SSH and GPG keys**
2. Enable **Flag unsigned commits as unverified**

This helps identify commits that should have been signed.

---

## Troubleshooting

### SSH: "No authenticator found"

```bash
# Ensure YubiKey is connected
# On Linux, ensure udev rules are set:
echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", ATTRS{idVendor}=="1050"' | sudo tee /etc/udev/rules.d/70-yubikey.rules
sudo udevadm control --reload-rules
```

### SSH: Key not working after YubiKey reset

Resident keys are stored on YubiKey. After FIDO2 reset:
```bash
# Re-generate key
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "email@example.com"

# Re-add to GitHub
```

### GPG: "No secret key"

```bash
gpgconf --kill gpg-agent
# Reconnect YubiKey
```

### Wrong key being used

```bash
# Check current configuration
git config --list | grep -E "(gpg|signing)"

# Override for specific repo
git config --local user.signingkey YOUR_KEY
```

---

## Comparison: PIV vs OpenPGP vs FIDO2

| Feature | PIV (Bitbucket) | OpenPGP (GitLab/GitHub) | FIDO2 (GitHub) |
|---------|-----------------|------------------------|----------------|
| Tool | smimesign | gpg | ssh-keygen |
| Key Type | X.509 cert | GPG key | SSH key |
| Managed By | Kleidia | User | User |
| PIN | PIV PIN | OpenPGP PIN | FIDO2 PIN |
| Touch | Optional | Required | Required |

**All three can coexist on your YubiKey!**

---

## References

- [GitHub SSH Signing](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification)
- [GitHub GPG Signing](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#gpg-commit-signature-verification)
- [Yubico SSH Guide](https://developers.yubico.com/SSH/)

