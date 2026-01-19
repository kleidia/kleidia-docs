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
4. **Store Secrets**: PIN/PUK/management key stored in Vault
5. **Complete Registration**: Device appears in system

### Admin “On-Behalf-Of” Registration (Pre‑Provisioning)

Use this flow when you want IT to pre-provision YubiKeys for users (for example, users synced from Entra ID who have not logged in yet).

1. **Connect admin agent + YubiKey**: On an admin workstation, ensure the Kleidia Agent is paired and the YubiKey is inserted.
2. **Open admin registration**: Navigate to **Admin Panel → Register YubiKey**.
3. **Select target user**: Choose the user who will own the device.
4. **Select the connected device**: Click the detected YubiKey in the device list.
   - If the YubiKey has a **non-default PIV management key**, Kleidia will require a **PIV reset** before provisioning can continue (this wipes existing PIV keys/certificates on the device).
5. **Register**: Click **Register YubiKey**.
6. **Record credentials (one-time)**: The admin is shown an **Initial PIN** and **Initial PUK** once. Print or copy these into a **sealed envelope** for the user.
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
- **PUK Setup**: Set initial PUK (if not already set)
- **Management Key**: Generate and store management key
- **Certificate Generation**: Generate certificates automatically (subject: `yubikey-<serial-number>`)

## Active Use Phase

### Normal Operations

During active use, users can:

- **Change PIN**: Update PIN as needed
- **Change PUK**: Update PUK as needed
- **Generate Certificates**: Create new certificates
- **View Device Status**: Check device information
- **Manage Certificates**: View and manage certificates

### Certificate Lifecycle

1. **CSR Generation**: System automatically generates Certificate Signing Request on YubiKey with subject `yubikey-<serial-number>` (or custom subject via advanced CSR management)
2. **Certificate Signing**: Backend signs CSR via OpenBao PKI
3. **Certificate Import**: Import signed certificate to YubiKey automatically
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

