# Changelog

All notable changes to Kleidia are documented here. This changelog covers the
documented release line (2.2.x and later).

## 2.4.1 — September 2026

Patch release: the PIV authentication-certificate UPN SAN (Active Directory
smart-card logon, introduced in 2.3.0) can now be enabled through the Helm
chart, with hardening around it; the 2.4.x OCI charts are published; images are
rebuilt on patched bases. Dependencies unchanged (Kubernetes 1.32+, PostgreSQL
18.1 default, OpenBao 2.5.4).

### Fixed
- **UPN SAN not configurable via Helm.** The backend has honoured
  `PIV_AUTH_CERT_EMBED_UPN` / `PIV_AUTH_CERT_UPN_DOMAINS` since 2.3.0, but the
  `kleidia-services` chart exposed neither, so Helm-installed deployments issued
  authentication certificates without the UPN otherName SAN even when the user's
  UPN was known. New values `backend.pivAuthCert.embedUpn` (default `false`) and
  `backend.pivAuthCert.upnDomains` (default `[]`) set them. Existing values files
  render unchanged; re-issue the authentication certificate after enabling.
- **Bundled-mode install/upgrade to 2.4.0 failed on `backup-runner-token`.**
  2.4.0 made `kleidia-services` template that Secret in bundled mode, but the
  bundled OpenBao setup hook (kleidia-platform) had already created it without
  Helm ownership metadata, and Helm validates ownership before any pre-install /
  pre-upgrade hook runs. Result: `helm install`/`helm upgrade kleidia-services`
  aborted with `Secret "backup-runner-token" ... exists and cannot be imported
  into the current release: invalid ownership metadata` on every bundled
  deployment, fresh or upgraded from 2.3.0. The chart now leaves an existing
  out-of-band Secret in place (the backend and backup CronJob keep using it) and
  adopts it on the following upgrade; the platform hook no longer re-creates
  (and silently rotates) the token on every platform upgrade.
- **2.4.0 OCI charts.** The 2.4.0 release published images and a GitHub release
  but the Helm charts were never pushed to
  `oci://registry-1.docker.io/therinn/kleidia-*`. 2.4.1 charts are published and
  the installation guide points at them.

### Security
- **Self-registration could grant global admin.** The public registration
  endpoint (`POST /api/auth/register`, enabled unless `ALLOW_SELF_REGISTER` is
  `false`) honoured a client-supplied `is_admin` field, stored it on the new
  account and issued a JWT carrying it. An anonymous caller could therefore
  self-register as a global administrator on any deployment with
  self-registration open, which is the default. The field is now ignored on that
  endpoint; admin accounts come only from the bootstrap flow or an authenticated
  admin via the admin users API. Affects all releases up to 2.4.0. **Upgrade,
  then audit `users` for unexpected `is_admin = true` rows** if self-registration
  has ever been reachable.
- **Unauthenticated password takeover of IdP-managed accounts.**
  `POST /api/auth/reset-admin-password` (the first-time admin password setup
  used by the admin setup page) accepted any `user_id` whose password hash was
  empty, and `POST /api/auth/login` disclosed that `user_id` for such users
  before checking a password. OIDC- and SCIM-provisioned users have empty
  hashes, so anyone who knew an OIDC user's username (their email) could set a
  local password on that account and log in as them, admins included. The flow
  is now limited to the seeded local `admin` account awaiting first-time setup;
  every other user gets the generic 401/403. Affects all releases up to 2.4.0.
  **Audit `users` for IdP-provisioned accounts that unexpectedly have a local
  password set**, and rotate if found.
- **Backend-side UPN enablement invariant.** The backend now refuses to start
  when `PIV_AUTH_CERT_EMBED_UPN=true` without a non-empty
  `PIV_AUTH_CERT_UPN_DOMAINS` or with `ALLOW_SELF_REGISTER` not `false`, so the
  Helm guard below cannot be bypassed by direct environment configuration.
- **UPN value hardening.** The UPN is passed to the CA inside a comma-separated
  `other_sans` list; a UPN containing `,` or `;` could smuggle a second UPN SAN
  for another principal into the certificate. UPNs containing separator,
  quoting, bracket or non-printable characters are now rejected on every
  signing path.
- **Guarded enablement.** The chart refuses `embedUpn: true` unless
  `upnDomains` is non-empty and `backend.allowSelfRegister` is `false`, because
  with open self-registration an anonymous user could choose the principal
  embedded in a Smart Card Logon certificate.
- **`backend.allowSelfRegister`** (new, default `true` to preserve behaviour)
  exposes the existing `ALLOW_SELF_REGISTER` switch, which the chart previously
  did not set.
- **Rebuilt images.** `backend-2.4.1` is rebuilt on Go 1.26.8 with
  `golang.org/x/crypto` 0.55.0 (clears 1 CRITICAL + 8 HIGH from the 2.4.0
  scan); `frontend-2.4.1` is rebuilt on a current `node:24-alpine`
  (OpenSSL 3.5.8, clears 2 HIGH). `license-2.4.1` is the unchanged, clean 2.4.0
  build retagged.

## 2.4.0 — July 2026

Feature release: reworked backup and restore, external-Vault operability
improvements, multi-tenant security hardening, and a PKI email-SAN fix.
Dependencies unchanged (Kubernetes 1.32+, PostgreSQL 18.1 default, OpenBao 2.5.4).

### Added
- **Reworked backup & restore.** One-button, auto-unseal-aware OpenBao snapshot
  restore and a simplified CNPG database restore flow; the legacy export bundle
  is retired. The CNPG backup list is sorted newest-first with readable,
  date-based names and a count.
- **External-Vault operability.** When running against a customer-managed
  OpenBao/Vault (`secretsBackend.mode=external`), the manual-unseal, auto-unseal,
  and CA-configuration tabs are hidden — those are the customer's responsibility.

### Fixed
- **PIV / code-signing email SAN.** Authentication and code-signing certificates
  now carry the rfc822 email SAN. It had been requested via parameters that
  neither Vault nor OpenBao recognize (`email_sans`/`email_addresses`) and was
  silently dropped; it is now requested via `alt_names`. The UPN otherName SAN
  (AD smart-card logon) was unaffected.
- **Multi-tenant scoping.** Closed cross-tenant read paths (provisioned-YubiKey
  listing and related endpoints) and corrected pagination and tenant scoping in
  the admin views.

### Notes
- Application images retagged from validated digests: `backend-2.4.0`,
  `frontend-2.4.0`, `license-2.4.0`. Bundled OpenBao unchanged (2.5.4).
- Provisioning scripts drop the no-op `allowed_email_sans`/`allowed_uri_sans`
  role parameters (never honored by Vault or OpenBao; OpenBao 2.6.0 warns on
  them). Email SANs remain permitted via `allow_any_name`.

## 2.3.0 — July 2026

Feature release: Active Directory smart-card logon support, plus an upgrade-path
hardening. Dependencies unchanged (Kubernetes 1.32+, PostgreSQL 18.1 default,
OpenBao 2.5.4).

### Added
- **PIV authentication certificate UPN SAN.** The slot-9a authentication
  certificate can embed the Microsoft userPrincipalName otherName SAN (OID
  1.3.6.1.4.1.311.20.2.3), enabling AD smart-card logon. Opt-in via
  `PIV_AUTH_CERT_EMBED_UPN` + `PIV_AUTH_CERT_UPN_DOMAINS`. The UPN derives from
  the OIDC upn/preferred_username claim (or email); an explicit override is
  global-admin only; the value is validated and audited. Covers the
  register-on-behalf, self-service, and sign-all issuance paths, and the
  register-on-behalf form shows the UPN that will be embedded. The
  `yubikey-piv-auth` role gains `allowed_other_sans` (managed and external-Vault
  modes).

### Fixed
- **agents.paired self-heals on startup.** Backend image-only upgrades
  (`kubectl set image`, no `helm upgrade`) now add the `agents.paired` column the
  cleanup cron requires, instead of erroring until a full chart upgrade runs.

### Notes
- Application images retagged from validated digests: `backend-2.3.0`,
  `frontend-2.3.0`, `license-2.3.0`. Bundled OpenBao unchanged (2.5.4).
- AD smart-card logon requires the issuing CA in the domain's NTAuth store; that
  trust anchoring is per-deployment and out of scope for Kleidia.

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
