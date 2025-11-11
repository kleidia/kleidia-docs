# Permissions and Policies

**Audience**: Administrators, Security Professionals  
**Prerequisites**: Understanding of RBAC  
**Outcome**: Understand permissions and policies in YubiMgr

## Role-Based Access Control (RBAC)

### Roles

#### Admin Role

**Permissions**:
- Full system access
- User management (create, edit, delete, disable)
- Device management (view all, revoke, return)
- Policy management (create, edit, delete)
- System configuration
- Audit log access
- Report generation

**Access**:
- All API endpoints
- Admin panel
- System settings
- Audit logs

#### User Role

**Permissions**:
- Personal YubiKey management
- Own device operations
- PIN/PUK changes on own devices
- Certificate generation on own devices

**Access**:
- User dashboard
- Own YubiKey devices
- Own device operations

## Vault Policies

### Backend Policy (`yubimgr-backend`)

**PKI Operations**:
- `pki/sign/*` - Sign certificates
- `pki/issue/*` - Issue certificates
- `pki/cert/ca` - Read CA certificate
- `pki/revoke` - Revoke certificates

**Secrets Operations**:
- `yubikeys/data/*` - Read/write YubiKey secrets
- `yubikeys/metadata/*` - List secret metadata

**Authentication**:
- AppRole authentication
- Token TTL: 1 hour
- Token Max TTL: 4 hours

### Admin Policy (if needed)

**Full Access**:
- All Vault paths
- Policy management
- Secret rotation
- PKI management

## Database Permissions

### User Permissions

- **Users Table**: Read own record, update own profile
- **YubiKeys Table**: Read own devices, create own devices
- **Sessions Table**: Read own sessions

### Admin Permissions

- **All Tables**: Full access
- **User Management**: Create, update, delete users
- **Device Management**: View all, revoke, return devices
- **Audit Logs**: View all audit logs

## API Permissions

### Public Endpoints

- `/api/health` - Health check (no authentication)

### User Endpoints

- `/api/auth/login` - Login (no authentication)
- `/api/auth/logout` - Logout (user authentication)
- `/api/yubikey` - YubiKey operations (user authentication)
- `/api/session/*` - Session management (user authentication)

### Admin Endpoints

- `/api/admin/*` - Admin operations (admin authentication)
- `/api/admin/users` - User management (admin only)
- `/api/admin/audit` - Audit logs (admin only)
- `/api/admin/system/*` - System management (admin only)

## Policy Enforcement

### Security Policies

Security policies are configured via the Admin Panel → Security Policies page and enforced across all operations:

- **Password Policy**: 
  - Minimum length (default: 8 characters)
  - Optional requirements: uppercase letters, lowercase letters, numbers, special characters
  - Enforced on: User password resets (admin operations)

- **PIN Policy**: 
  - Minimum/maximum length (default: 6-8 characters)
  - Require digits only (default: true)
  - Enforced on: YubiKey PIN updates via `UpsertYubiKeyPIVSecrets`

- **PUK Policy**: 
  - Minimum/maximum length (default: 6-8 characters)
  - Require digits only (default: true)
  - Enforced on: YubiKey PUK updates via `UpsertYubiKeyPIVSecrets`

- **Certificate Policy**: 
  - Allowed algorithms (default: RSA2048, ECCP384)
  - Maximum TTL in hours (default: 8760 hours = 1 year)
  - Enforced on: Certificate signing requests via `SignPivCSRWithVault`

### Policy Application

- **Blocking Behavior**: Non-compliant operations are blocked with clear error messages
- **Admin Override**: Admins can override policies by including HTTP headers:
  - `X-Admin-Override: true` - Enables override (admin-only)
  - `X-Override-Reason: <reason>` - Optional reason for override
- **Audit Logging**: All policy violations and overrides are logged to audit logs:
  - Policy violations: Logged with action `policy.violation` and resource type
  - Policy overrides: Logged with action `policy.override`, resource type, and reason
- **Real-time Enforcement**: Policies are cached in memory (5-minute TTL) for performance
- **Default Policy**: A default policy is automatically created on system initialization with current constraints

## Related Documentation

- [Security Overview](../02-security/security-overview.md)
- [Authentication Model](../02-security/auth-model.md)
- [Compliance Considerations](../02-security/compliance-considerations.md)

