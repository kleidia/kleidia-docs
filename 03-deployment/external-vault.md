# Using an external (customer-managed) Vault / OpenBao

**Audience**: Platform / Security Administrators
**Prerequisites**: An existing HashiCorp Vault or OpenBao you administer; `kubectl` + Helm access to the Kleidia cluster
**Outcome**: Kleidia runs against your own Vault/OpenBao — it stores secrets and issues certificates there, while you retain ownership of provisioning, PKI, sealing, HA, and backup/DR

By default Kleidia bundles and operates its own OpenBao. In **external mode** Kleidia is
instead a *tenant* of **your** Vault/OpenBao: it consumes an API endpoint plus AppRole
credentials. Kleidia performs **no** Vault administration.

Supported: HashiCorp Vault (OSS/Community and Enterprise, including namespaces) and OpenBao.

> **You own it.** In external mode the availability, sealing, and backup/DR of the Vault are
> your responsibility. Kleidia's own DR covers its database (CloudNativePG) only.

---

## TL;DR
1. Provision your Vault per the contract below (mounts, PKI roles, AppRole, policy).
2. Create a Kubernetes Secret with the AppRole `role_id` + `secret_id`.
3. Install with `secretsBackend.mode=external`, `openbao.enabled=false`, and your `externalVault.*` values.

---

## What you must provision in your Vault (the contract)

### 1. KV v2 mount (read + write)
A KV v2 mount Kleidia uses for its own secrets (default name `yubikeys`, configurable via
`externalVault.kvMount`). Kleidia **self-seeds** its JWT and encryption keys here on first
start, so it needs **write**, not just read.

### 2. PKI mount + CA + roles (you own the CA)
A PKI mount (default `pki`, configurable via `externalVault.pkiMount`) with a configured CA
(root or intermediate — your choice) and these **roles** (exact names Kleidia signs against):

| Role | Used for |
|------|----------|
| `agent-session` | session-bound agent mTLS certs |
| `agent-localhost-cert` | agent localhost TLS |
| `backend-mtls` | backend inter-service mTLS |
| `kleidia-component` | cert-manager-issued infra/mTLS certs (incl. PostgreSQL) |
| `yubikey-piv` | YubiKey PIV certificates |
| `yubikey-piv-auth` | YubiKey PIV authentication |
| `yubikey-piv-code-signing` | YubiKey code-signing certs |
| `yubikey-piv-email-signing` | YubiKey S/MIME certs |

Kleidia will not create or modify the mount, CA, or roles. The in-app "OpenBao CA
configuration" screen is **read-only** in external mode.

### 3. AppRole auth + least-privilege policy
Enable the `approle` auth method and bind a Kleidia role to this policy (adjust the mount
names to match your `kvMount`/`pkiMount`):

```hcl
path "kleidia-kv/data/*"     { capabilities = ["create", "read", "update"] }
path "kleidia-kv/metadata/*" { capabilities = ["read", "list", "delete"] }
path "kleidia-pki/sign/*"    { capabilities = ["create", "update"] }
path "kleidia-pki/issue/*"   { capabilities = ["create", "update"] }
path "kleidia-pki/cert/ca"   { capabilities = ["read"] }
path "kleidia-pki/ca/pem"    { capabilities = ["read"] }
path "kleidia-pki/crl*"      { capabilities = ["read"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
path "auth/token/renew-self" { capabilities = ["update"] }
```

Download: [`external-vault-policy.hcl`](https://raw.githubusercontent.com/kleidia/kleidia-docs/main/03-deployment/external-vault-policy.hcl)

The same AppRole serves the backend, the license-service, and the cert-manager issuer.

### 4. (Enterprise only) namespace
If your Vault Enterprise uses namespaces, provision all of the above inside one namespace
and set `externalVault.namespace`. Kleidia sends `X-Vault-Namespace` on every call.

---

## Install

```bash
# AppRole credentials (Kleidia does NOT generate these)
kubectl -n kleidia create secret generic kleidia-vault-approle \
  --from-literal=role_id="<APPROLE_ROLE_ID>" \
  --from-literal=secret_id="<APPROLE_SECRET_ID>"

# Optional: CA bundle for TLS to your Vault (if it uses a private CA)
kubectl -n kleidia create secret generic vault-ca --from-file=ca.crt=/path/to/ca.crt
```

Values (use the same file across all three charts):

```yaml
global:
  secretsBackend:
    mode: external
  externalVault:
    address: "https://vault.corp.example:8200"
    namespace: ""                 # set for namespaced Vault Enterprise
    kvMount: "yubikeys"
    pkiMount: "pki"
    appRoleSecret: "kleidia-vault-approle"
    caSecret: "vault-ca"          # omit if your Vault uses a publicly-trusted CA
    tlsSkipVerify: false
    certManagerRoleId: "<APPROLE_ROLE_ID>"   # role_id for the cert-manager issuer (literal)

openbao:
  enabled: false                  # REQUIRED in external mode
```

```bash
helm install kleidia-platform ./helm/kleidia-platform -f values.yaml
helm install kleidia-data     ./helm/kleidia-data     -f values.yaml
helm install kleidia-services ./helm/kleidia-services -f values.yaml
```

The platform chart **fails fast** if `mode=external` while `openbao.enabled=true`, or if
`externalVault.address` is unset.

---

## What external mode changes
- No bundled OpenBao, bootstrap, seal/unseal-key Secret, TLS bootstrap, or raft-snapshot backup is installed.
- The cert-manager `kleidia-mtls-issuer` points at your Vault using AppRole auth.
- Backend and license-service authenticate via AppRole and honor the configurable KV/PKI
  mounts, the namespace, and the CA bundle.

## Troubleshooting
- **403 / permission denied** → your AppRole policy is missing a path or role (see the contract).
- **PostgreSQL certificates pending** → `kubectl get issuer kleidia-mtls-issuer -n kleidia`; if not
  Ready, the issuer can't reach/authenticate to your Vault or the `kleidia-component` role is
  missing. Kleidia's pre-install gate reports this before the database hangs.
- **TLS errors** → provide `externalVault.caSecret`, or (dev only) set `tlsSkipVerify: true`.
- **Enterprise namespace 404s** → set `externalVault.namespace`.
