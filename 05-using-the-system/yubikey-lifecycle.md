# YubiKey Lifecycle Management

**Audience**: End Users, Administrators  
**Prerequisites**: Kleidia account  
**Outcome**: Understand YubiKey lifecycle from registration to retirement

## Lifecycle Overview

YubiKey devices go through several stages:

1. **Registration**: Device registered in system
2. **Configuration**: PIN/PUK/management key setup
3. **Active Use**: Device used for operations
4. **Maintenance**: PIN/PUK changes, certificate updates
5. **Revocation**: Device revoked by administrator
6. **Retirement**: Device removed from system

## Registration Phase

### New Device Registration (End User)

1. **Connect Device**: Insert YubiKey into computer
2. **Detect Device**: System automatically detects YubiKey
3. **Enter Information**: Provide device details and credentials
4. **Store Secrets**: PIN and management key stored in Vault. Kleidia does not store the PUK (since 2.5.0): change it off the factory default to a value you remember; the new PUK goes to the YubiKey only
5. **Complete Registration**: Device appears in system

### Admin “On-Behalf-Of” Registration (Pre‑Provisioning)

Use this flow when you want IT to pre-provision YubiKeys for users (for example, users synced from Entra ID who have not logged in yet).

1. **Connect admin agent + YubiKey**: On an admin workstation, ensure the Kleidia Agent is paired and the YubiKey is inserted.
2. **Open admin registration**: Navigate to **Admin Panel → Register YubiKey**.
3. **Select target user**: Choose the user who will own the device.
4. **Select the connected device**: Click the detected YubiKey in the device list.
   - If the YubiKey has a **non-default PIV management key**, Kleidia will require a **PIV reset** before provisioning can continue (this wipes existing PIV keys/certificates on the device).
5. **Register**: Click **Register YubiKey**.
6. **Record credentials (one-time)**: The admin is shown an **Initial PIN** once. Print or copy it into a **sealed envelope** for the user. The PUK is set to a random value that Kleidia does not store or show; a blocked PIN on this YubiKey is recovered with a PIV reset.
7. **Provisioning steps** (typical):
   - Prepare the YubiKey (PIV setup) from the YubiKey details view.
   - Sign and import certificates.
   - Mark the device as shipped and deliver the YubiKey + sealed envelope to the user.

#### Admin Provisioning States

Admin-provisioned devices track a provisioning lifecycle in addition to their active/revoked status:

1. **pending**: Registered for a user, not yet prepared
2. **prepared**: PIV prepared and ready for certificate operations
3. **certified**: Certificates signed/imported
4. **shipped**: Device delivered to user
5. **activated**: User has successfully activated/used the device

### Initial Configuration

- **PIN Setup**: Set initial PIN (if not already set)
- **PUK Setup**: Change the PUK off the factory default (`12345678`). Kleidia refuses self-service certificate generation while the YubiKey still has the default PUK (firmware 5.3 and later; older firmware cannot report it). The PUK is written to the YubiKey only, never stored by Kleidia
- **Management Key**: Generate and store management key
- **Certificate Generation**: Generate certificates automatically (subject: `yubikey-<serial-number>`)

## Active Use Phase

### Normal Operations

During active use, users can:

- **Change PIN**: Update PIN as needed
- **Change PUK**: Update PUK as needed (the new PUK goes to the YubiKey only; keep it somewhere safe)
- **Generate Certificates**: Create new certificates
- **View Device Status**: Check device information
- **Manage Certificates**: View and manage certificates

### Certificate Lifecycle

1. **CSR Generation**: System automatically generates Certificate Signing Request on YubiKey with subject `yubikey-<serial-number>` (or custom subject via advanced CSR management)
2. **Certificate Signing**: Backend signs CSR via OpenBao PKI
3. **Certificate Import**: Import signed certificate to YubiKey automatically. The agent (2.5.0+) reads the slot back and Kleidia records the install result; a certificate that failed to import, or that does not match what is on the card, is revoked automatically (see [Certificates and PKI](../02-security/certificates-and-pki.md#certificate-install-verification))
4. **Certificate Usage**: Use certificate for authentication/signing
5. **Certificate Renewal**: Renew before expiration
6. **Certificate Revocation**: Administrators can revoke certificates if compromised (users cannot revoke certificates)

## Maintenance Phase

### Regular Maintenance

- **PIN Changes**: Change PIN periodically for security
- **Certificate Renewal**: Renew certificates before expiration
- **Firmware Updates**: Keep YubiKey firmware updated
- **Status Checks**: Regularly check device status

### Security Maintenance

- **Default Credential Checks**: Verify PIN/PUK not using defaults
- **Certificate Expiration**: Monitor certificate expiration dates
- **Revocation Checks**: Check for revoked certificates
- **Policy Compliance**: Ensure device meets security policies

## Revocation Phase

### Device Revocation

When a device needs to be revoked (lost, stolen, compromised, or user departure):

1. **Admin Action**: Administrator navigates to Admin Panel → YubiKeys and clicks "Revoke Device"
2. **Confirmation**: Admin confirms revocation action
3. **System Actions**:
   - Device marked as revoked in database
   - All associated certificates revoked
   - Device secrets removed from Vault
   - **Automatic Wipe**: If device is connected to an admin workstation, system attempts to wipe PIV data (reset PIV application)
   - Revocation logged in audit trail
4. **Device Status**: Device marked as revoked and removed from active devices list
5. **Re-registration**:
   - If the device remains in **revoked** state, revocation is not reversible.
   - If the device was later **removed/returned** (soft-deleted) and needs to be reused, an administrator can **re-provision** it for a new user via **Admin Panel → Register YubiKey**. Kleidia will revoke any old certificates associated with that serial before re-provisioning.

**Important Notes**:
- **Automatic Wipe**: When a revoked device is connected to an admin workstation (where an agent is running), the system automatically attempts to wipe the PIV application. This ensures the device cannot be used even if physically recovered.
- **Permanent Action**: Revocation cannot be undone. The device must be re-registered if needed again.
- **Returned Status**: The system tracks "returned" devices in statistics, but there is no separate UI action for marking devices as returned. Use "Revoke Device" for all device retirement scenarios.

### Understanding PIV vs FIDO2 Reset

> ⚠️ **Critical**: PIV and FIDO2 are separate applets with different reset procedures. Automatic wipe only resets PIV—FIDO2 credentials remain intact unless manually reset.

| Applet | Automatic Reset | Manual Reset Required | Timing Requirement |
|--------|-----------------|----------------------|-------------------|
| **PIV** | ✅ Yes (on revocation) | Optional | None |
| **FIDO2** | ❌ No | Yes | Must be within 5 seconds of insertion |

**FIDO2 Reset Procedure**:

FIDO2 has a security feature that prevents remote/malware-initiated resets. The reset can only be performed **within 5 seconds of inserting the YubiKey**:

1. Unplug the YubiKey
2. Reinsert the YubiKey
3. Immediately (within 5 seconds) initiate the reset via:
   - Kleidia UI: Dashboard → YubiKey → FIDO2 Management → Advanced → Reset FIDO2 Applet
   - Command line: `ykman fido reset`
4. Touch the YubiKey when prompted

If the 5-second window expires, the reset will fail with a timing error. Simply unplug, reinsert, and try again immediately.

**Why This Matters for Revocation**:

When revoking a YubiKey:
- PIV credentials (certificates, keys) are automatically wiped
- FIDO2 passkeys (Microsoft 365, Google, GitHub, etc.) **remain on the device**
- For complete device wipe, FIDO2 must be reset separately using the procedure above

See [FIDO2 Management Guide](fido2-management.md) for detailed FIDO2 operations.

## Retirement Phase

### Device Removal

When device is permanently retired:

1. **Remove from System**: Device removed from database
2. **Revoke Certificates**: All certificates revoked
3. **Clean Up Secrets**: Secrets removed from Vault
4. **Audit Trail**: Removal logged in audit trail

## Lifecycle Best Practices

### For Users

- ✅ Register devices immediately upon receipt
- ✅ Change default PIN/PUK immediately
- ✅ Keep certificates current
- ✅ Report lost/stolen devices immediately
- ✅ Contact administrator to revoke devices when no longer needed

### For Administrators

- ✅ Track device lifecycle stages
- ✅ Monitor device status regularly
- ✅ Enforce security policies
- ✅ Maintain audit trail
- ✅ Revoke devices promptly when users depart or devices are lost/stolen
- ✅ Ensure revoked devices are wiped when connected to admin workstations
- ✅ Securely dispose of retired devices

## Related Documentation

- [End User Guide](end-user-guide.md)
- [Administrator Guide](admin-guide.md)
- [Operations Guide](../04-operations/)

