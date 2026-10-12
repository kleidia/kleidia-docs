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
#
# UPGRADE NOTE (PIV auth-cert UPN SAN): the yubikey-piv-auth role must permit the
# Microsoft UPN otherName SAN for on-prem AD smart-card logon. Add to that role:
#     allowed_other_sans="1.3.6.1.4.1.311.20.2.3;UTF8:*"
# (scoped to the UPN OID only, NOT "*"; keep use_csr_sans=false). Existing
# external-Vault deployments on an older role will get a Vault "otherSANs not
# allowed by this role" error when UPN embedding is enabled until this is added;
# the backend surfaces that message with the exact parameter to set. This is a
# role-definition change, not a policy-path change, so no edit below is required.
# =============================================================================

# --- KV v2 (app secrets self-seeded by Kleidia + per-YubiKey secrets) ---
path "kleidia-kv/data/*" {
  capabilities = ["create", "read", "update"]
}
path "kleidia-kv/metadata/*" {
  capabilities = ["read", "list", "delete"]
}
# 2.5.0: Kleidia no longer stores PUKs. At startup it removes stored PUKs and
# destroys the older KV versions that still hold one, which needs "update" here.
path "kleidia-kv/destroy/backend/*" {
  capabilities = ["update"]
}

# --- PKI: sign/issue against Kleidia's roles, revoke what it issued (NO admin) ---
path "kleidia-pki/sign/*" {
  capabilities = ["create", "update"]
}
path "kleidia-pki/issue/*" {
  capabilities = ["create", "update"]
}
# Required since 2.4.2: lost/deleted/reset YubiKeys and replaced slot certificates
# are revoked, and the operation fails (the key is kept) when the revoke is denied.
path "kleidia-pki/revoke" {
  capabilities = ["update"]
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
