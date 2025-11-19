# Vault Setup

**Audience**: Operations Administrators  
**Prerequisites**: Kubernetes cluster, Helm installed  
**Outcome**: Understand Vault (OpenBao) setup and configuration

## Overview

Kleidia uses OpenBao for secrets management and PKI operations. OpenBao is automatically configured during Helm deployment, but manual configuration may be needed for troubleshooting.

## Automatic Setup

Vault is automatically configured by Helm hooks during deployment:

1. **OpenBao Deployment**: StatefulSet with persistent storage
2. **Auto-Unseal**: Static key unsealing (no manual unseal needed)
3. **PKI Configuration**: PKI engine and roles configured
4. **KV v2 Setup**: Secrets engine enabled at `yubikeys/` path
5. **AppRole Authentication**: Backend authentication configured
6. **Policies**: Backend and admin policies created

## Manual Setup (if needed)

### 1. Check Vault Status

```bash
# Get Vault pod name
VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=openbao -n kleidia -o jsonpath='{.items[0].metadata.name}')

# Check Vault status
kubectl exec -it $VAULT_POD -n kleidia -- vault status
```

### 2. Initialize Vault (if not initialized)

```bash
# Initialize Vault
kubectl exec -it $VAULT_POD -n kleidia -- vault operator init -key-shares=3 -key-threshold=2

# Save unseal keys and root token securely
```

### 3. Unseal Vault (if not auto-unsealed)

```bash
# Unseal Vault (if auto-unseal not working)
kubectl exec -it $VAULT_POD -n kleidia -- vault operator unseal <unseal-key-1>
kubectl exec -it $VAULT_POD -n kleidia -- vault operator unseal <unseal-key-2>
```

### 4. Enable KV v2 Secrets Engine

```bash
# Login with root token
kubectl exec -it $VAULT_POD -n kleidia -- vault login <root-token>

# Enable KV v2 at yubikeys path
kubectl exec -it $VAULT_POD -n kleidia -- vault secrets enable -path=yubikeys kv-v2
```

### 5. Enable PKI Secrets Engine

```bash
# Enable PKI
kubectl exec -it $VAULT_POD -n kleidia -- vault secrets enable pki

# Configure TTL (CA lifetime window)
kubectl exec -it $VAULT_POD -n kleidia -- vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA (10 years)
kubectl exec -it $VAULT_POD -n kleidia -- vault write pki/root/generate/internal \
    common_name="Kleidia Root CA" \
    ttl=87600h

# Configure URLs
kubectl exec -it $VAULT_POD -n kleidia -- vault write pki/config/urls \
    issuing_certificates="http://kleidia-platform-openbao:8200/v1/pki/ca" \
    crl_distribution_points="http://kleidia-platform-openbao:8200/v1/pki/crl"

# Create PKI role (1-year leaf certificates)
kubectl exec -it $VAULT_POD -n kleidia -- vault write pki/roles/kleidia \
    allow_any_name=true \
    enforce_hostnames=false \
    allow_subdomains=true \
    allow_localhost=true \
    allow_ip_sans=true \
    require_cn=true \
    key_type="rsa" \
    key_bits=2048 \
    max_ttl="8760h" \
    ttl="8760h"
```

### 6. Configure AppRole Authentication

```bash
# Enable AppRole
kubectl exec -it $VAULT_POD -n kleidia -- vault auth enable approle

# Create backend policy
kubectl exec -it $VAULT_POD -n kleidia -- vault policy write kleidia-backend - <<EOF
path "pki/sign/*" {
  capabilities = ["create", "read", "update"]
}

path "pki/issue/*" {
  capabilities = ["create", "read", "update"]
}

path "pki/cert/ca" {
  capabilities = ["read"]
}

path "pki/revoke" {
  capabilities = ["update"]
}

path "yubikeys/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "yubikeys/metadata/*" {
  capabilities = ["list", "read"]
}
EOF

# Create AppRole
kubectl exec -it $VAULT_POD -n kleidia -- vault write auth/approle/role/kleidia-backend \
    token_policies="kleidia-backend" \
    token_ttl=1h \
    token_max_ttl=4h

# Get Role ID
ROLE_ID=$(kubectl exec -it $VAULT_POD -n kleidia -- vault read -field=role_id auth/approle/role/kleidia-backend/role-id)

# Generate Secret ID
SECRET_ID=$(kubectl exec -it $VAULT_POD -n kleidia -- vault write -field=secret_id -f auth/approle/role/kleidia-backend/secret-id)

# Store in Kubernetes secret
kubectl create secret generic vault-approle -n kleidia \
    --from-literal=role-id=$ROLE_ID \
    --from-literal=secret-id=$SECRET_ID \
    --dry-run=client -o yaml | kubectl apply -f -
```

## Verification

### Check Vault Status

```bash
# Check Vault is unsealed
kubectl exec -it $VAULT_POD -n kleidia -- vault status

# Expected output:
# Key             Value
# ---             -----
# Seal Type      shamir
# Initialized    true
# Sealed         false
# ...
```

### Verify Secrets Engines

```bash
# List secrets engines
kubectl exec -it $VAULT_POD -n kleidia -- vault secrets list

# Should show:
# Path          Type         Accessor              Description
# ----          ----         --------              -----------
# pki/          pki          pki_xxx              PKI secrets engine
# yubikeys/     kv           kv_xxx               KV v2 secrets engine
```

### Verify PKI Configuration

```bash
# Check PKI role
kubectl exec -it $VAULT_POD -n kleidia -- vault read pki/roles/kleidia

# Check CA certificate
kubectl exec -it $VAULT_POD -n kleidia -- vault read pki/cert/ca
```

### Test Secret Storage

```bash
# Store test secret
kubectl exec -it $VAULT_POD -n kleidia -- vault kv put yubikeys/data/test \
    pin="123456" \
    puk="12345678"

# Read test secret
kubectl exec -it $VAULT_POD -n kleidia -- vault kv get yubikeys/data/test
```

## Auto-Unseal Configuration

Kleidia uses static key auto-unseal (OpenBao 2.4.0+):

- **Configuration**: Automatic via Helm chart
- **Key Storage**: Kubernetes secret (`openbao-unseal-key`)
- **No Manual Unseal**: Vault unseals automatically on restart

### Verify Auto-Unseal

```bash
# Check Vault logs for auto-unseal
kubectl logs kleidia-platform-openbao-0 -n kleidia | grep -i unseal

# Should show:
# [INFO]  core: vault is unsealed
```

## Troubleshooting

### Vault Sealed

```bash
# Check Vault status
kubectl exec -it $VAULT_POD -n kleidia -- vault status

# If sealed, check auto-unseal configuration
kubectl get secret openbao-unseal-key -n kleidia

# Manual unseal (if auto-unseal fails)
kubectl exec -it $VAULT_POD -n kleidia -- vault operator unseal <unseal-key>
```

### PKI Not Configured

```bash
# Check if PKI is enabled
kubectl exec -it $VAULT_POD -n kleidia -- vault secrets list | grep pki

# If not enabled, enable it (see manual setup above)
```

### AppRole Authentication Fails

```bash
# Check AppRole is enabled
kubectl exec -it $VAULT_POD -n kleidia -- vault auth list | grep approle

# Check backend secret exists
kubectl get secret vault-approle -n kleidia

# Test authentication
kubectl exec -it $VAULT_POD -n kleidia -- vault write auth/approle/login \
    role_id=<role-id> \
    secret_id=<secret-id>
```

## Backup and Restore

### Backup Vault Data

```bash
# Create snapshot
kubectl exec -it $VAULT_POD -n kleidia -- vault operator raft snapshot save /tmp/vault-backup.snap

# Copy snapshot locally
kubectl cp kleidia-platform-openbao-0:/tmp/vault-backup.snap ./vault-backup-$(date +%Y%m%d).snap -n kleidia
```

### Restore Vault Data

```bash
# Copy snapshot to pod
kubectl cp ./vault-backup.snap kleidia-platform-openbao-0:/tmp/vault-backup.snap -n kleidia

# Restore snapshot
kubectl exec -it $VAULT_POD -n kleidia -- vault operator raft snapshot restore /tmp/vault-backup.snap
```

## Related Documentation

- [Vault and Secrets](../02-security/vault-and-secrets.md)
- [Certificates and PKI](../02-security/certificates-and-pki.md)
- [Helm Installation](helm-install.md)
- [Troubleshooting](troubleshooting.md)

