# =============================================================================
# Kleidia external-Vault AppRole policy (reference)
# =============================================================================
# Least-privilege policy for the AppRole Kleidia uses against a customer-managed
# Vault/OpenBao (external mode). Adjust the mount names (kleidia-kv / kleidia-pki)
# to match your global.externalVault.kvMount / .pkiMount.
#
# Kleidia performs NO Vault administration: it self-seeds its app secrets in KV,
# signs/issues certs against the roles below, and reads CA/CRL. The PKI mount, CA,
# and roles must be provisioned by you. See docs/EXTERNAL_VAULT.md.
# =============================================================================

# --- KV v2 (app secrets self-seeded by Kleidia + per-YubiKey secrets) ---
path "kleidia-kv/data/*" {
  capabilities = ["create", "read", "update"]
}
path "kleidia-kv/metadata/*" {
  capabilities = ["read", "list", "delete"]
}

# --- PKI: sign/issue only against Kleidia's roles (NO admin) ---
path "kleidia-pki/sign/*" {
  capabilities = ["create", "update"]
}
path "kleidia-pki/issue/*" {
  capabilities = ["create", "update"]
}
path "kleidia-pki/cert/ca" {
  capabilities = ["read"]
}
path "kleidia-pki/ca/pem" {
  capabilities = ["read"]
}
path "kleidia-pki/ca_chain" {
  capabilities = ["read"]
}
path "kleidia-pki/crl*" {
  capabilities = ["read"]
}

# --- Token self-inspection (backend startup auth self-test) + renewal ---
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
