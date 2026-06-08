# Changelog

All notable changes to Kleidia are documented here. This changelog covers the
documented release line (2.2.x and later).

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
