# Permissions and Policies

**Audience**: Administrators, Security Professionals  
**Prerequisites**: Understanding of RBAC  
**Outcome**: Understand permissions and policies in Kleidia

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

## OpenBao (Vault) AppRoles and Policies

Kleidia uses a least-privilege security model with dedicated AppRoles for each component. This ensures separation of concerns and limits the blast radius of any potential compromise.

### AppRole Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OpenBao (Vault)                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │   helm-admin    │  │ backend-openbao │  │ license-openbao │      │
│  │    AppRole      │  │    AppRole      │  │    AppRole      │      │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘      │
│           │                    │                    │                │
│           ▼                    ▼                    ▼                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │  helm-admin     │  │ kleidia-backend │  │ license-service │      │
│  │    Policy       │  │    Policy       │  │    Policy       │      │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1. Helm Admin AppRole (`helm-admin`)

**Purpose**: Manage OpenBao configuration during Helm upgrades without root token access.

**Kubernetes Secret**: `openbao-helm-approle`

**Capabilities**:
- ✅ Manage Kubernetes auth method configuration
- ✅ Manage AppRole configurations (limited to known roles)
- ✅ Update specific policies (backend, license, cert-manager, backup)
- ✅ Configure PKI roles
- ❌ **Cannot read secrets** from KV engines
- ❌ **Cannot create new auth methods or secrets engines**
- ❌ **Cannot mint arbitrary tokens**

**Policy (`helm-admin`)**:
```hcl
# Manage Kubernetes auth method
path "auth/kubernetes/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage AppRole auth method (only specific roles)
path "auth/approle/role/helm-admin" {
  capabilities = ["read", "update"]
}
path "auth/approle/role/helm-admin/secret-id" {
  capabilities = ["create", "update"]
}
path "auth/approle/role/backend-openbao" {
  capabilities = ["read", "update"]
}
path "auth/approle/role/backend-openbao/secret-id" {
  capabilities = ["create", "update"]
}
path "auth/approle/role/license-openbao" {
  capabilities = ["read", "update"]
}
path "auth/approle/role/license-openbao/secret-id" {
  capabilities = ["create", "update"]
}

# Manage specific policies only
path "sys/policy/kleidia-backend" {
  capabilities = ["create", "read", "update"]
}
path "sys/policy/license-service" {
  capabilities = ["create", "read", "update"]
}
path "sys/policy/cert-manager" {
  capabilities = ["create", "read", "update"]
}
path "sys/policy/kleidia-backup" {
  capabilities = ["create", "read", "update"]
}
path "sys/policy/helm-admin" {
  capabilities = ["read"]  # Read-only on self
}

# Read auth methods (no create/delete)
path "sys/auth" {
  capabilities = ["read", "list"]
}

# PKI management (needed for role updates)
path "pki/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "pki/config/*" {
  capabilities = ["read", "update"]
}

# Token renewal only
path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

**Security Analysis**:
- Cannot escalate privileges (no `sys/mounts`, no `auth/token/create`)
- Cannot access YubiKey secrets or license data
- Limited to managing existing configuration, not creating new attack surfaces

### 2. Backend AppRole (`backend-openbao`)

**Purpose**: Backend service authentication for YubiKey operations and PKI.

**Kubernetes Secret**: `openbao-backend-approle`

**Capabilities**:
- ✅ Read/write YubiKey secrets at specific paths
- ✅ Read application secrets (JWT, encryption keys, database config)
- ✅ PKI operations (sign, issue, revoke certificates)
- ❌ **Cannot access license secrets**
- ❌ **Cannot modify policies or auth configuration**

**Policy (`kleidia-backend`)**:
```hcl
# PKI operations
path "pki/sign/*" {
  capabilities = ["create", "read", "update"]
}
path "pki/issue/*" {
  capabilities = ["create", "read", "update"]
}
path "pki/cert/ca" {
  capabilities = ["read"]
}
path "pki/revoke" {
  capabilities = ["update"]
}
path "pki/certs" {
  capabilities = ["list"]
}

# YubiKey secrets (full access)
path "yubikeys/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "yubikeys/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

# Application secrets (specific paths only)
path "secret/data/kleidia/jwt-secret" {
  capabilities = ["create", "read", "update"]
}
path "secret/data/kleidia/encryption-key" {
  capabilities = ["create", "read", "update"]
}
path "secret/data/kleidia/database" {
  capabilities = ["create", "read", "update"]
}
path "secret/data/kleidia/backend/*" {
  capabilities = ["create", "read", "update"]
}
path "secret/data/kleidia/backend-encryption-key" {
  capabilities = ["create", "read", "update"]
}
path "secret/metadata/kleidia/*" {
  capabilities = ["list", "read"]
}

# Explicit deny for license secrets
path "secret/data/kleidia/licenses/*" {
  capabilities = ["deny"]
}

# Token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

**Security Analysis**:
- Scoped to specific KV paths, not wildcard access
- Explicit deny prevents access to license data
- Cannot modify its own policy or escalate privileges

### 3. License Service AppRole (`license-openbao`)

**Purpose**: License service authentication for license storage operations.

**Kubernetes Secret**: `openbao-license-approle`

**Capabilities**:
- ✅ Read/write license secrets
- ❌ **Cannot access YubiKey secrets**
- ❌ **Cannot access backend application secrets**
- ❌ **Cannot perform PKI operations**

**Policy (`license-service`)**:
```hcl
# License secrets only
path "secret/data/kleidia/licenses/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/kleidia/licenses/*" {
  capabilities = ["list", "read", "delete"]
}

# Explicit deny for backend secrets
path "yubikeys/*" {
  capabilities = ["deny"]
}
path "secret/data/kleidia/jwt-secret" {
  capabilities = ["deny"]
}
path "secret/data/kleidia/encryption-key" {
  capabilities = ["deny"]
}
path "secret/data/kleidia/database" {
  capabilities = ["deny"]
}
path "secret/data/kleidia/backend/*" {
  capabilities = ["deny"]
}

# Token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

**Security Analysis**:
- Strictly limited to license path
- Explicit deny blocks access to all other sensitive paths
- Cannot access YubiKey PINs, PUKs, or management keys

## Audit Logging

All OpenBao operations are logged via the file audit device:

**Audit Log Location**: `/openbao/audit/audit.log` (inside the OpenBao pod)

**Logged Events**:
- All authentication attempts (success and failure)
- All secret access (read, write, delete)
- All policy changes
- All configuration changes
- Token creation and renewal

**Viewing Audit Logs**:
```bash
# Get OpenBao pod
VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=openbao -n kleidia -o jsonpath='{.items[0].metadata.name}')

# View recent audit logs
kubectl exec -it $VAULT_POD -n kleidia -- tail -100 /openbao/audit/audit.log

# Search for specific operations
kubectl exec -it $VAULT_POD -n kleidia -- grep "yubikeys/data" /openbao/audit/audit.log
```

**Audit Log Format** (JSON):
```json
{
  "time": "2024-01-15T10:30:00Z",
  "type": "request",
  "auth": {
    "token_type": "service",
    "policies": ["kleidia-backend"]
  },
  "request": {
    "operation": "read",
    "path": "yubikeys/data/12345678/secrets"
  }
}
```

## Security Considerations

### Privilege Separation

| Component | Can Access YubiKey Secrets | Can Access Licenses | Can Modify Config |
|-----------|---------------------------|---------------------|-------------------|
| helm-admin | ❌ No | ❌ No | ✅ Yes (limited) |
| backend-openbao | ✅ Yes | ❌ No | ❌ No |
| license-openbao | ❌ No | ✅ Yes | ❌ No |

### Abuse Vector Analysis

**Compromised helm-admin AppRole**:
- ⚠️ Could modify policies to grant broader access
- ⚠️ Could reconfigure auth methods
- ✅ Cannot directly read secrets
- ✅ Cannot create new secrets engines
- **Mitigation**: Monitor policy changes in audit logs

**Compromised backend-openbao AppRole**:
- ⚠️ Could read all YubiKey secrets
- ⚠️ Could issue certificates
- ✅ Cannot access license data
- ✅ Cannot modify configuration
- **Mitigation**: Monitor unusual secret access patterns

**Compromised license-openbao AppRole**:
- ⚠️ Could read/modify license data
- ✅ Cannot access YubiKey secrets
- ✅ Cannot access backend secrets
- ✅ Cannot modify configuration
- **Mitigation**: Monitor license path access

### Best Practices

1. **Regular Audit Log Review**: Review OpenBao audit logs for suspicious activity
2. **Secret Rotation**: Rotate AppRole secret IDs periodically
3. **Least Privilege**: Each component only has access to what it needs
4. **Network Policies**: Restrict which pods can communicate with OpenBao
5. **Backup Keys**: Store root token and recovery keys securely offline

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
- [Vault and Secrets](../02-security/vault-and-secrets.md)
- [Compliance Considerations](../02-security/compliance-considerations.md)
