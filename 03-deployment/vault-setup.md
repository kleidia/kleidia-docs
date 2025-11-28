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
5. **AppRole Authentication**: Dedicated AppRoles for each component
6. **Policies**: Least-privilege policies for backend, license service, and Helm admin
7. **Audit Logging**: File-based audit device enabled

## AppRole Architecture

After installation, three AppRoles are created for different components:

| AppRole | Kubernetes Secret | Purpose |
|---------|------------------|---------|
| `helm-admin` | `openbao-helm-approle` | Helm chart upgrades and configuration |
| `backend-openbao` | `openbao-backend-approle` | Backend service operations |
| `license-openbao` | `openbao-license-approle` | License service operations |

```
┌─────────────────────────────────────────────────────────────────┐
│                    Fresh Installation                            │
│                                                                  │
│  1. OpenBao initialized with root token                         │
│  2. Root token used to configure everything                     │
│  3. AppRoles created with scoped permissions                    │
│  4. Root token displayed to admin, then deleted                 │
│  5. Future operations use AppRoles only                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Helm Upgrades                                 │
│                                                                  │
│  • Uses helm-admin AppRole (no root token needed)               │
│  • Can update policies and PKI roles                            │
│  • Cannot read secrets                                          │
│  • Cannot create new secrets engines                            │
└─────────────────────────────────────────────────────────────────┘
```

## Manual Setup (if needed)

### 1. Check Vault Status

```bash
# Get Vault pod name
VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=openbao -n kleidia -o jsonpath='{.items[0].metadata.name}')

# Check Vault status
kubectl exec -it $VAULT_POD -n kleidia -- bao status
```

### 2. Initialize Vault (if not initialized)

```bash
# Initialize Vault
kubectl exec -it $VAULT_POD -n kleidia -- bao operator init -key-shares=3 -key-threshold=2

# Save unseal keys and root token securely
```

### 3. Unseal Vault (if not auto-unsealed)

```bash
# Unseal Vault (if auto-unseal not working)
kubectl exec -it $VAULT_POD -n kleidia -- bao operator unseal <unseal-key-1>
kubectl exec -it $VAULT_POD -n kleidia -- bao operator unseal <unseal-key-2>
```

### 4. Enable KV v2 Secrets Engine

```bash
# Login with root token
kubectl exec -it $VAULT_POD -n kleidia -- bao login <root-token>

# Enable KV v2 at yubikeys path
kubectl exec -it $VAULT_POD -n kleidia -- bao secrets enable -path=yubikeys kv-v2
```

### 5. Enable PKI Secrets Engine

```bash
# Enable PKI
kubectl exec -it $VAULT_POD -n kleidia -- bao secrets enable pki

# Configure TTL (CA lifetime window)
kubectl exec -it $VAULT_POD -n kleidia -- bao secrets tune -max-lease-ttl=87600h pki

# Generate root CA (10 years)
kubectl exec -it $VAULT_POD -n kleidia -- bao write pki/root/generate/internal \
    common_name="Kleidia Root CA" \
    ttl=87600h

# Configure URLs
kubectl exec -it $VAULT_POD -n kleidia -- bao write pki/config/urls \
    issuing_certificates="http://kleidia-platform-openbao:8200/v1/pki/ca" \
    crl_distribution_points="http://kleidia-platform-openbao:8200/v1/pki/crl"

# Create PKI role (1-year leaf certificates)
kubectl exec -it $VAULT_POD -n kleidia -- bao write pki/roles/kleidia \
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
kubectl exec -it $VAULT_POD -n kleidia -- bao auth enable approle

# Create backend policy
kubectl exec -it $VAULT_POD -n kleidia -- bao policy write kleidia-backend - <<EOF
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
  capabilities = ["list", "read", "delete"]
}

path "secret/data/kleidia/jwt-secret" {
  capabilities = ["create", "read", "update"]
}

path "secret/data/kleidia/encryption-key" {
  capabilities = ["create", "read", "update"]
}

path "secret/data/kleidia/database" {
  capabilities = ["create", "read", "update"]
}

# Explicit deny for license secrets
path "secret/data/kleidia/licenses/*" {
  capabilities = ["deny"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Create backend AppRole
kubectl exec -it $VAULT_POD -n kleidia -- bao write auth/approle/role/backend-openbao \
    token_policies="kleidia-backend" \
    token_ttl=1h \
    token_max_ttl=4h

# Get Role ID
ROLE_ID=$(kubectl exec -it $VAULT_POD -n kleidia -- bao read -field=role_id auth/approle/role/backend-openbao/role-id)

# Generate Secret ID
SECRET_ID=$(kubectl exec -it $VAULT_POD -n kleidia -- bao write -field=secret_id -f auth/approle/role/backend-openbao/secret-id)

# Store in Kubernetes secret
kubectl create secret generic openbao-backend-approle -n kleidia \
    --from-literal=role_id=$ROLE_ID \
    --from-literal=secret_id=$SECRET_ID \
    --dry-run=client -o yaml | kubectl apply -f -
```

### 7. Enable Audit Logging

```bash
# Enable file audit device
kubectl exec -it $VAULT_POD -n kleidia -- bao audit enable file file_path=/openbao/audit/audit.log

# Verify audit is enabled
kubectl exec -it $VAULT_POD -n kleidia -- bao audit list
```

## Verification

### Check Vault Status

```bash
# Check Vault is unsealed
kubectl exec -it $VAULT_POD -n kleidia -- bao status

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
kubectl exec -it $VAULT_POD -n kleidia -- bao secrets list

# Should show:
# Path          Type         Accessor              Description
# ----          ----         --------              -----------
# pki/          pki          pki_xxx              PKI secrets engine
# yubikeys/     kv           kv_xxx               KV v2 secrets engine
```

### Verify AppRoles

```bash
# List auth methods
kubectl exec -it $VAULT_POD -n kleidia -- bao auth list

# Check AppRoles exist
kubectl exec -it $VAULT_POD -n kleidia -- bao list auth/approle/role

# Should show:
# Keys
# ----
# backend-openbao
# helm-admin
# license-openbao
```

### Verify Kubernetes Secrets

```bash
# Check all AppRole secrets exist
kubectl get secret openbao-backend-approle -n kleidia
kubectl get secret openbao-license-approle -n kleidia
kubectl get secret openbao-helm-approle -n kleidia

# View secret keys (not values)
kubectl get secret openbao-backend-approle -n kleidia -o jsonpath='{.data}' | jq 'keys'
# Should show: ["role_id", "secret_id"]
```

### Verify PKI Configuration

```bash
# Check PKI role
kubectl exec -it $VAULT_POD -n kleidia -- bao read pki/roles/kleidia

# Check CA certificate
kubectl exec -it $VAULT_POD -n kleidia -- bao read pki/cert/ca
```

### Verify Audit Logging

```bash
# Check audit device is enabled
kubectl exec -it $VAULT_POD -n kleidia -- bao audit list

# View recent audit logs
kubectl exec -it $VAULT_POD -n kleidia -- tail -10 /openbao/audit/audit.log
```

### Test Secret Storage

```bash
# Store test secret (requires root token or appropriate AppRole)
kubectl exec -it $VAULT_POD -n kleidia -- bao kv put yubikeys/data/test \
    pin="123456" \
    puk="12345678"

# Read test secret
kubectl exec -it $VAULT_POD -n kleidia -- bao kv get yubikeys/data/test

# Delete test secret
kubectl exec -it $VAULT_POD -n kleidia -- bao kv delete yubikeys/data/test
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
kubectl exec -it $VAULT_POD -n kleidia -- bao status

# If sealed, check auto-unseal configuration
kubectl get secret openbao-unseal-key -n kleidia

# Manual unseal (if auto-unseal fails)
kubectl exec -it $VAULT_POD -n kleidia -- bao operator unseal <unseal-key>
```

### PKI Not Configured

```bash
# Check if PKI is enabled
kubectl exec -it $VAULT_POD -n kleidia -- bao secrets list | grep pki

# If not enabled, enable it (see manual setup above)
```

### AppRole Authentication Fails

```bash
# Check AppRole is enabled
kubectl exec -it $VAULT_POD -n kleidia -- bao auth list | grep approle

# Check backend secret exists
kubectl get secret openbao-backend-approle -n kleidia

# Decode and check role_id
kubectl get secret openbao-backend-approle -n kleidia -o jsonpath='{.data.role_id}' | base64 -d

# Test authentication
ROLE_ID=$(kubectl get secret openbao-backend-approle -n kleidia -o jsonpath='{.data.role_id}' | base64 -d)
SECRET_ID=$(kubectl get secret openbao-backend-approle -n kleidia -o jsonpath='{.data.secret_id}' | base64 -d)

kubectl exec -it $VAULT_POD -n kleidia -- bao write auth/approle/login \
    role_id=$ROLE_ID \
    secret_id=$SECRET_ID
```

### Audit Log Issues

```bash
# Check audit device status
kubectl exec -it $VAULT_POD -n kleidia -- bao audit list

# Check audit log file exists and is writable
kubectl exec -it $VAULT_POD -n kleidia -- ls -la /openbao/audit/

# If audit device is missing, re-enable it
kubectl exec -it $VAULT_POD -n kleidia -- bao audit enable file file_path=/openbao/audit/audit.log
```

### Permission Denied Errors

```bash
# Check which policy is attached to the AppRole
kubectl exec -it $VAULT_POD -n kleidia -- bao read auth/approle/role/backend-openbao

# Read the policy to see what's allowed
kubectl exec -it $VAULT_POD -n kleidia -- bao policy read kleidia-backend

# Check audit log for denied operations
kubectl exec -it $VAULT_POD -n kleidia -- grep "permission denied" /openbao/audit/audit.log | tail -10
```

## Backup and Restore

### Backup Vault Data

```bash
# Create snapshot
kubectl exec -it $VAULT_POD -n kleidia -- bao operator raft snapshot save /tmp/vault-backup.snap

# Copy snapshot locally
kubectl cp kleidia-platform-openbao-0:/tmp/vault-backup.snap ./vault-backup-$(date +%Y%m%d).snap -n kleidia
```

### Restore Vault Data

```bash
# Copy snapshot to pod
kubectl cp ./vault-backup.snap kleidia-platform-openbao-0:/tmp/vault-backup.snap -n kleidia

# Restore snapshot
kubectl exec -it $VAULT_POD -n kleidia -- bao operator raft snapshot restore /tmp/vault-backup.snap
```

### Backup AppRole Credentials

```bash
# Export Kubernetes secrets (for disaster recovery)
kubectl get secret openbao-backend-approle -n kleidia -o yaml > backup-backend-approle.yaml
kubectl get secret openbao-license-approle -n kleidia -o yaml > backup-license-approle.yaml
kubectl get secret openbao-helm-approle -n kleidia -o yaml > backup-helm-approle.yaml

# Store these securely - they contain authentication credentials
```

## Security Best Practices

1. **Delete Root Token**: After initial setup, ensure root token is removed from cluster
2. **Rotate Secret IDs**: Periodically regenerate AppRole secret IDs
3. **Monitor Audit Logs**: Regularly review audit logs for suspicious activity
4. **Backup Regularly**: Schedule regular Vault backups
5. **Test Recovery**: Periodically test backup restoration procedures

## Related Documentation

- [Vault and Secrets](../02-security/vault-and-secrets.md)
- [Permissions and Policies](../06-reference/permissions-and-policies.md)
- [Certificates and PKI](../02-security/certificates-and-pki.md)
- [Helm Installation](helm-install.md)
- [Troubleshooting](troubleshooting.md)
