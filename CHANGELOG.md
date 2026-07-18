# Changelog

All notable changes to Kleidia are documented here. This changelog covers the
documented release line (2.2.x and later).

## 2.2.5 — July 2026

Correctness and security release. Supersedes 2.2.4. Upgrade is a chart/image
bump with no manual data steps; the missing tables are created automatically at
backend startup.

### Fixed
- **Feature tables created on install/upgrade.** `scim_configs`,
  `scim_provisioning_logs`, `idp_connectors`, `idp_credential_registrations`,
  `fido2_provisioning_sessions`, `openpgp_keys`, `openpgp_policies`,
  `device_config_history` (and `operations`) were never created on Helm-installed
  clusters, so SCIM, IdP connectors, FIDO2 provisioning and OpenPGP features
  failed on first use. They are now created idempotently at startup and in the
  chart's db-init.
- **SCIM resource id.** The SCIM `id` returned in list/get/create responses was
  mangled (digits reversed and truncated), so SCIM update and deprovision always
  404'd — a deprovisioned user could never be deactivated. Ids now round-trip.
- **Admin API tenant isolation.** System-level admin routes now require a global
  admin (org managers no longer reach them), and per-YubiKey admin operations
  enforce the caller's organization, closing a cross-tenant access path to keys
  and their PIN/PUK secrets.

### Changed
- Frontend admin surfaces use a two-tier model so org managers can reach their
  own org pages while system pages remain global-admin only.

### Notes
- Application images retagged from validated digests: `backend-2.2.5`,
  `frontend-2.2.5`, `license-2.2.5`. Bundled OpenBao unchanged (2.5.4).

## 2.2.3 — June 2026

Patch release. Bundled OpenBao upgraded to the current 2.5.4.

### Changed
- **Bundled OpenBao image bumped 2.4.4 → 2.5.4** (managed mode). Verified both the
  fresh-install path (raft + static-seal init and auto-unseal, including auto-unseal
  across pod restart) and the in-place 2.4.4 → 2.5.4 upgrade (2.5.4 reads existing
  raft data and the static-sealed root key without error). The GCP-KMS auto-unseal
  regression in OpenBao 2.5.0 does not affect Kleidia's static-key seal.

### Notes
- No schema/data changes; safe in-place upgrade from 2.2.2.
- Application images are unchanged from 2.2.2 (identical digests, retagged):
  `backend-2.2.3`, `frontend-2.2.3`, `license-2.2.3`.
- Charts republished at 2.2.3 — install with `--version 2.2.3`.

## 2.2.2 — June 2026

### Added
- **Kleidia platform version is shown in the admin overview.** The admin panel now
  displays a "Kleidia v<version>" badge, sourced from the deployed chart `appVersion`
  (`/admin/stats` returns `version`). Addresses pilot feedback about not being able to
  tell which version is running.

### Fixed
- Hardening from the SonarQube review: license-service container runs as non-root,
  TLS 1.2 floor on the OIDC and backup-S3 clients, and minor correctness cleanups.

### Notes
- No schema/data changes; safe in-place upgrade from 2.2.1.
- Images: `backend-2.2.2`, `frontend-2.2.2`, `license-2.2.2`.

## 2.2.1 — June 2026

Patch release. External (customer-managed) Vault mode hardening — surfaced by a
full from-scratch external-mode deployment.

### Fixed
- **License service KV mount is now configurable** via `VAULT_KV_MOUNT`
  (`global.externalVault.kvMount`). Previously hardcoded to `yubikeys`, which
  forced external deployments to use that mount name.
- **Backend Vault auth self-test uses least privilege.** It now probes
  `auth/token/lookup-self` (granted by Vault's built-in `default` policy) instead
  of `sys/auth`. The external-Vault AppRole policy no longer needs to grant
  `sys/auth` — the reference policy has been updated accordingly.
- **mTLS CA-bundle setup works in external mode.** The `fetch-mtls-ca`
  post-install hook is now aware of the secrets backend: it reaches the external
  Vault address, honors the configurable PKI mount, and supports a CA bundle or
  TLS skip-verify. Previously it probed the bundled OpenBao and failed the
  install in external mode.

### Notes
- No application schema or data changes; safe in-place upgrade from 2.2.0.
- Image tags: `backend-2.2.1`, `frontend-2.2.1`, `license-2.2.1`.

## 2.2.0

Added **external (customer-managed) Vault/OpenBao mode**
(`secretsBackend.mode=external`): Kleidia can run as a tenant of your own
Vault/OpenBao, consuming an API endpoint plus AppRole credentials while you retain
ownership of provisioning, PKI, sealing, HA, and backup/DR. Chart versions and
image tags were unified to a single `x.y.z` release scheme across all components.

See [03-deployment/external-vault.md](03-deployment/external-vault.md) for the
provisioning contract.
