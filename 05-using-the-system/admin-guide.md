# Administrator Guide

**Audience**: System Administrators  
**Prerequisites**: Admin account, Kleidia deployed  
**Outcome**: Administer Kleidia system and users

## First-Time Setup

### Creating the Initial Administrator Account

On a fresh Kleidia installation, the first visitor will see a bootstrap screen to create the initial administrator account:

1. **Navigate** to the Kleidia web interface
2. **Enter administrator credentials**:
   - Username (default: `admin`)
   - Password (minimum 8 characters)
   - Confirm password
3. **Click "Create Admin"**
4. **Automatic login** to the dashboard

**Bootstrap Security**:
- Only available when no admin users exist
- Race-condition protection prevents multiple simultaneous creations
- 10-minute timeout on abandoned bootstrap attempts
- Full audit logging of bootstrap actions

### OpenBao Bootstrap Keys - Critical First Step

**⚠️ IMMEDIATE ACTION REQUIRED**

After creating the admin account and logging in for the first time, you will see a **critical security modal** displaying OpenBao initialization keys.

#### What Are These Keys?

The OpenBao initialization keys are master credentials for your Kleidia installation's secrets management system:

- **Root Token**: Master administrative access to OpenBao (Vault)
- **Recovery Keys (3)**: Emergency recovery keys for OpenBao operations

#### Why Are They Important?

These keys are needed for:
- **Emergency recovery** of OpenBao if it becomes sealed
- **Root-level operations** that require elevated Vault access
- **Disaster recovery** scenarios
- **System migration** or reinstallation

**Without these keys, you may lose access to all encrypted secrets if OpenBao fails.**

#### Securing the Keys

**The modal will display**:
- Root Token
- Recovery Key 1, 2, and 3
- Unseal Key (if applicable)

**Required Actions**:

1. **Copy each key** using the provided copy buttons
2. **Store keys securely** in one or more of:
   - Enterprise password manager (1Password, LastPass, BitWarden)
   - Encrypted vault storage
   - Physical safe (printed and sealed)
   - Air-gapped encrypted USB drive
3. **Never store keys in**:
   - Plain text files
   - Email
   - Cloud storage (Dropbox, Google Drive)
   - Unencrypted locations
4. **Check the acknowledgment checkbox**
5. **Click "Confirm & Delete Keys from Cluster"**

#### Modal Characteristics

- **Non-dismissible**: Cannot close with ESC or clicking outside
- **Copy functionality**: Each key has a copy-to-clipboard button
- **Visual feedback**: Buttons show "Copied!" confirmation
- **One-time display**: Keys shown only once, then permanently deleted
- **Mandatory acknowledgment**: Checkbox must be checked before deletion

#### What Happens After Confirmation

1. Keys are **permanently deleted** from Kubernetes cluster
2. Action is logged in audit trail
3. Modal closes and dashboard loads
4. Keys are **no longer accessible** from the system
5. **You cannot retrieve them again** - they must be recovered from your secure storage

#### If Keys Are Lost

Without the OpenBao keys:
- Normal operations continue (daily YubiKey management works)
- Emergency recovery of OpenBao may be impossible
- System reinstallation may be required in disaster scenarios
- You will need to contact Kleidia support for recovery options

**Best Practice**: Store keys in multiple secure locations with different access controls.

## Admin Dashboard

### Accessing Admin Panel

1. Log in with admin account
2. Navigate to **Dashboard** → **Admin Panel**
3. Access administrative functions

## User Management

### Create User

1. Navigate to **Admin Panel** → **Users**
2. Click "Create User"
3. Enter user information:
   - Username
   - Email
   - Full Name
   - Password
   - Role (User or Admin)
4. Click "Create User"
5. User receives account credentials

### Edit User

1. Navigate to **Admin Panel** → **Users**
2. Select user to edit
3. Click "Edit User"
4. Update user information
5. Click "Save Changes"

### Disable User

1. Navigate to **Admin Panel** → **Users**
2. Select user to disable
3. Click "Disable User"
4. Confirm disable action
5. User account disabled (cannot log in)

**Note**: Users are disabled, not deleted. Disabled users cannot log in but their data is retained.

## Device Management

### View All Devices

1. Navigate to **Admin Panel** → **YubiKeys**
2. View all registered YubiKeys across organization
3. Filter by status, user, or search by serial number

### Device Details

1. Navigate to **Admin Panel** → **YubiKeys**
2. Click on device
3. View detailed information:
   - Owner information
   - Device status
   - Certificate information
   - Registration date
   - Last seen date

### Revoke Device

When a device needs to be revoked (lost, stolen, compromised, or user departure):

1. Navigate to **Admin Panel** → **YubiKeys**
2. Select device to revoke
3. Click "Revoke Device"
4. Review revocation confirmation dialog:
   - Device serial number
   - Owner information
   - Warning about permanent action
5. Confirm revocation
6. System performs the following actions:
   - Device marked as revoked in database
   - All associated certificates revoked
   - Device secrets removed from Vault
   - **If device is connected to an admin workstation**: System attempts to wipe PIV data (reset PIV application)
   - Revocation logged in audit trail
7. Device removed from active devices list

**Important Notes**:
- **Automatic Wipe**: When a revoked device is connected to an admin workstation (where an agent is running), the system automatically attempts to wipe the PIV application. This ensures the device cannot be used even if physically recovered.
- **Permanent Action**: Revocation cannot be undone. The device must be re-registered if needed again.
- **Audit Trail**: All revocation actions are logged with timestamp, admin user, and device details.
- **Returned Status**: The system tracks "returned" devices in statistics, but there is no separate UI action for marking devices as returned. Use "Revoke Device" for all device retirement scenarios.

## Policy Management

### Security Policies

Configure security policies:

1. Navigate to **Admin Panel** → **Security Policies**
2. Configure policies:
   - **Password Policy**: Minimum length, require uppercase/lowercase/numbers/special characters
   - **PIN Policy**: Minimum/maximum length (6-8), require digits only
   - **PUK Policy**: Minimum/maximum length (6-8), require digits only
   - **Certificate Policy**: Allowed algorithms (RSA2048, ECCP384, etc.), maximum TTL in hours
3. Click "Save Policy"

### Policy Enforcement

- Policies are automatically enforced on all operations:
  - **Password operations**: User password resets must comply with password policy
  - **PIN/PUK operations**: YubiKey PIN/PUK updates must comply with PIN/PUK policies
  - **Certificate operations**: Certificate signing requests must use allowed algorithms and TTL
- Users receive clear error messages when operations violate policies
- **Admin Override**: Admins can override policies by including the `X-Admin-Override: true` header in API requests
  - Override reason can be provided via `X-Override-Reason` header
  - All policy overrides are logged to audit logs for compliance

## Audit and Compliance

### View Audit Logs

1. Navigate to **Admin Panel** → **Audit Logs**
2. Filter logs by:
   - Date range
   - User
   - Action type
   - Resource
3. Export logs for compliance

### Generate Reports

1. Navigate to **Admin Panel** → **Reports**
2. Select report type:
   - Device Inventory
   - Certificate Status
   - User Activity
   - Security Events
3. Select date range
4. Click "Generate Report"
5. Download PDF report

**Note**: Reports are available in PDF format only and can be downloaded from the admin interface. Reports are not schedulable.

## System Configuration

### System Settings

Configure system-wide settings:

1. Navigate to **Admin Panel** → **System Settings**
2. Configure settings by category:
   - **Organization**: Organization name and branding
   - **Email**: SMTP host, port, from address, username, TLS settings
   - **Security**: Feature toggles (device binding, token rotation)
   - **Backup**: Database and Vault backup schedules (cron expressions), retention days
   - **OIDC Provider**: OpenID Connect authentication configuration
   - **OpenBao CA**: Certificate Authority configuration
3. Click "Save" for each settings category

**Note**: Settings are persisted in the database and take effect immediately. All setting changes are logged to audit logs.

## License Management

Kleidia uses a cryptographically-signed license system to control usage rights and system capabilities. The system starts with a 30-day trial and requires an activation license for continued use.

### Understanding License Status

The system displays one of the following license statuses:

- **TRIAL**: 30-day free trial (automatic on first installation)
- **VALID**: Active paid license with more than 7 days remaining
- **EXPIRING**: Paid license with 7 days or less remaining (warning state)
- **EXPIRED**: License has passed its expiry date (system may restrict functionality)
- **INVALID**: License signature verification failed or installation ID mismatch

### Viewing License Status

1. Navigate to **Admin Panel** → **Settings** → **License**
2. View current license information:
   - **License Status**: Current state (TRIAL, VALID, EXPIRING, EXPIRED)
   - **License Type**: Trial or Standard
   - **Customer Name**: Organization name on the license
   - **Customer Email**: Contact email on the license
   - **Expiry Date**: When the license expires
   - **Days Remaining**: Time until expiration
   - **Installation ID**: Unique identifier for this deployment

### Installation ID

The **Installation ID** is a unique cryptographic hash that identifies your specific Kleidia installation. It is:

- **Automatically generated** on first startup
- **Permanently tied** to your deployment
- **Required for license generation** (provide this to your vendor when purchasing)
- **Immutable**: Cannot be changed or transferred to another installation

**To obtain your Installation ID**:
1. Navigate to **Admin Panel** → **Settings** → **License**
2. Copy the Installation ID displayed at the top of the page
3. Send this ID to your vendor when purchasing or renewing a license

### Activating a License

When you receive a license file from your vendor:

1. Navigate to **Admin Panel** → **Settings** → **License**
2. Click "Upload License" button
3. Paste the entire license content into the text field
   - License is a JSON-formatted signed document
   - Includes license data and cryptographic signature
4. Click "Activate License"
5. System validates the license:
   - **Signature verification**: Ensures license is authentic and unmodified
   - **Installation ID match**: Verifies license is for this specific installation
   - **Expiry check**: Confirms license is not expired
6. If validation succeeds:
   - License status updates immediately
   - System displays license details
   - License is stored securely in Vault
7. If validation fails, check:
   - Installation ID matches what was provided to vendor
   - License file is complete and unmodified
   - License has not expired

### License Validation

The system validates licenses:

- **On startup**: Backend verifies license with license service
- **During operations**: Middleware checks license validity for protected endpoints
- **Periodically**: License status is refreshed from the license service

**Note**: If the license service is unavailable, the system falls back to TRIAL mode to prevent service disruption.

### License Expiry Notifications

The system provides expiry warnings:

- **30 days before expiry**: Admin dashboard shows warning banner
- **7 days before expiry**: License status changes to "EXPIRING"
- **At expiry**: License status changes to "EXPIRED"
  - Some features may be restricted
  - Contact vendor for renewal license

### Trial License Limitations

The 30-day trial license:
- ✅ Full feature access during trial period
- ✅ No technical limitations
- ⚠️ Automatically expires after 30 days
- ⚠️ Requires activation license for continued use

**Note**: Trial licenses are system-generated and do not require manual upload.

### License Troubleshooting

#### "Invalid license signature"
- **Cause**: License file is corrupted or modified
- **Solution**: Request a new license file from your vendor

#### "Installation ID mismatch"
- **Cause**: License was generated for a different installation
- **Solution**: Provide your current Installation ID to vendor for a new license

#### "License expired"
- **Cause**: License expiry date has passed
- **Solution**: Contact vendor to purchase renewal license

#### License status shows "INVALID"
- **Cause**: License validation failed
- **Solution**: Check logs for specific error, contact support if needed

### License Renewal

Before your license expires:

1. Navigate to **Admin Panel** → **Settings** → **License**
2. Copy your Installation ID (remains the same)
3. Contact your vendor with:
   - Installation ID
   - Desired renewal period
   - Current customer information
4. Receive renewal license file
5. Upload renewal license (follows same activation process)
6. Old license is replaced; new expiry date takes effect immediately

**Note**: You can upload a renewal license at any time, even before the current license expires. The new expiry date replaces the old one.

## Monitoring

### System Health

1. Navigate to **Admin Panel** → **System Health**
2. View component status:
   - Database connectivity
   - Vault connectivity
   - Service status
   - Resource usage

## Troubleshooting

### User Issues

- **User Cannot Log In**: Check user account status, verify credentials
- **User Cannot Pair Agent**: Check agent installation, verify network connectivity
- **User Cannot Access Devices**: Check user permissions, verify device ownership

### System Issues

- **High Resource Usage**: Check resource monitoring, scale services if needed
- **Slow Performance**: Check database performance, review slow queries
- **Certificate Errors**: Check certificate expiration, renew if needed

## Best Practices

- ✅ Review audit logs regularly
- ✅ Monitor system health daily
- ✅ Keep user accounts current
- ✅ Enforce security policies
- ✅ Rotate secrets regularly
- ✅ Generate compliance reports monthly
- ✅ Keep documentation updated

## Related Documentation

- [End User Guide](end-user-guide.md)
- [YubiKey Lifecycle](yubikey-lifecycle.md)
- [Operations Guide](../04-operations/)

