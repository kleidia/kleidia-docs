# Multi-Tenant Organizations

Kleidia supports multi-tenant organization isolation, allowing subsidiaries or departments to be isolated so that Org Managers can only see and manage YubiKeys belonging to users in their organization.

## Overview

Multi-tenancy enables enterprise deployments where:
- Different subsidiaries/departments need isolated management
- Delegated administration is required without full system access
- Users are automatically assigned to organizations via OIDC claims
- Privileged roles are managed through IdP groups

## Role Hierarchy

| Role | Scope | Capabilities |
|------|-------|--------------|
| **Global Admin** | Global | Full system access. Manage all organizations, users, and system settings. |
| **Org Manager** (`org_manager`) | Organization | View/manage YubiKeys and users within their organization only. Access compliance reports and audit logs scoped to their org. |
| **User** | Self | Manage their own YubiKey only. |

### Menu Access by Role

| Menu Item | Global Admin | Org Manager | User |
|-----------|-------------|-----------|------|
| Dashboard | ✓ | ✓ | ✓ |
| My YubiKeys | ✓ | ✓ | ✓ |
| Register YubiKey | ✓ | ✓ | ✓ |
| Admin Panel | ✓ | ✓ | - |
| Manage YubiKeys | ✓ | ✓ (org only) | - |
| Register YubiKey (Admin) | ✓ | ✓ (org only) | - |
| Manage Users | ✓ | - | - |
| Organizations | ✓ | - | - |
| Compliance Reports | ✓ | ✓ (org only) | - |
| System Settings | ✓ | - | - |
| Audit Logs | ✓ | ✓ (org only) | - |

## Enabling Multi-Tenancy

1. Navigate to **System Settings** → **Multi-Tenant**
2. Enable the **Multi-Tenant Mode** toggle
3. Configure OIDC claim mappings (see below)
4. Save the configuration

## OIDC Claim Configuration

### How users get assigned to organizations

Kleidia can assign users to organizations through multiple mechanisms:

- **OIDC login-time claims**: Users are assigned when they log in via OIDC, based on configured claim mappings (described below).
- **Entra ID Sync (Graph) mapping**: Synced users can be mapped into organizations during sync (useful for pre-provisioning users who have not logged in yet).
- **SCIM provisioning scope**: SCIM tokens can be scoped to a single organization so all provisioned users land in that org.

### Claim Mapping

Configure which OIDC claims Kleidia should use:

| Setting | Description | Default |
|---------|-------------|---------|
| **Organization Claim** | The claim containing the user's organization | `organization` |
| **Role Claim** | The claim containing the user's role | `kleidia_role` |
| **Groups Claim** | The claim containing user groups | `groups` |

### Role Assignment Priority

Roles are assigned in the following order of precedence:

1. **IdP Groups (Highest Priority)** – If the user is a member of a configured global admin or org manager group
2. **Role Claim Value** – If the role claim matches configured values
3. **Default** – User role

### Group-Based Role Assignment (Recommended)

For security-sensitive environments, use IdP groups to manage privileged access:

| Setting | Description | Example |
|---------|-------------|---------|
| **Global Admin Groups** | IdP groups that grant Global Admin access | `kleidia-global admins, global-admins` |
| **Org Manager Groups** | IdP groups that grant Org Manager access | `kleidia-org-managers, department-managers` |

**Benefits:**
- Centralized access management in your IdP
- Revoking access is as simple as removing group membership
- Audit trail in your IdP for privilege changes
- No manual role assignment required in Kleidia

### Role Claim Value Mapping (Fallback)

If not using group-based assignment:

| Setting | Description | Default |
|---------|-------------|---------|
| **Global Admin Value** | Role claim value for Global Admin | `global_admin` |
| **Org Manager Value** | Role claim value for Org Manager | `org_manager` |

## Managing Organizations

Global Admins can manage organizations from **Admin Panel** → **Organizations**.

### Creating an Organization

1. Click **Create Organization**
2. Enter the organization name
3. Optionally set the **OIDC Claim Value** to auto-assign users
4. Click **Create**

### OIDC Claim Value

When a user logs in via OIDC, their organization claim is matched against the **OIDC Claim Value** field:
- If a match is found, the user is assigned to that organization
- If no match is found and the organization doesn't exist, it can be auto-created (if configured)

### Deactivating an Organization

Deactivated organizations:
- Remain in the system for historical records
- Users cannot be assigned to them
- Existing users retain access but cannot perform org-specific operations

### Deleting an Organization

Organizations can only be deleted if they have no assigned users. To delete:
1. Remove or reassign all users from the organization
2. Click the delete button

## User Role Management

Global Admins can manually assign roles via **Admin Panel** → **Manage Users** → **Update Role**.

### Role Override

When manually setting a role, you can enable **Role Override** to prevent the role from being updated by OIDC claims on subsequent logins.

## Example: Azure Entra ID Configuration

To configure Azure Entra ID for multi-tenancy:

### 1. Configure Group Claims

In your App Registration:
1. Go to **Token configuration**
2. Click **Add groups claim**
3. Select **Security groups** or **Groups assigned to the application**
4. Under **Customize token properties by type**, ensure **ID** includes `Group ID`

### 2. Create Admin Groups

Create security groups in Entra ID:
- `kleidia-global admins` – For global administrators
- `kleidia-org-managers` – For organization managers

### 3. Configure Kleidia

In Kleidia's Multi-Tenant settings:
- **Groups Claim**: `groups`
- **Global Admin Groups**: Enter the Group IDs (GUIDs) for global admin groups
- **Org Manager Groups**: Enter the Group IDs (GUIDs) for org manager groups

### 4. Organization Claim (Optional)

If using organization-based isolation:
1. Add a custom claim or extension attribute for organization
2. Configure the **Organization Claim** in Kleidia

### Entra ID Sync mapping (optional)

If you use **Entra ID Sync** to import users before they log in, configure organization mapping in:

**Admin Panel → System Settings → Identity Providers → Entra ID Sync**

Supported mapping modes:

- **single_org**: assign all synced users to a selected default organization
- **by_group**: map users into organizations using Entra group membership
- **by_attribute**: map users into organizations using an Entra user attribute (for example, department or extension attribute)

### SCIM provisioning scope (optional)

If you provision users via **SCIM**, generate SCIM tokens per organization:

**Admin Panel → System Settings → Identity Providers → SCIM**

When a SCIM token is scoped to an organization, all users provisioned with that token are assigned to that organization automatically.

## Example: Okta Configuration

### 1. Configure Groups Claim

In your Okta Application:
1. Go to **Sign On** → **OpenID Connect ID Token**
2. Add a **Groups claim** with the filter for relevant groups

### 2. Create Groups

Create groups in Okta:
- `kleidia-global admins`
- `kleidia-org-managers`

### 3. Configure Kleidia

In Kleidia's Multi-Tenant settings:
- **Groups Claim**: `groups`
- **Global Admin Groups**: `kleidia-global admins`
- **Org Manager Groups**: `kleidia-org-managers`

## Audit Trail

All organization-related actions are logged:
- `organization.created` – Organization created
- `organization.updated` – Organization settings changed
- `organization.deleted` – Organization deleted
- `user.assigned_to_organization` – User assigned to organization
- `user.role_updated` – User role changed

Access audit logs from **Admin Panel** → **Audit Logs**.

## Troubleshooting

### User Not Assigned to Correct Organization

1. Check the user's OIDC claims (available in audit logs)
2. Verify the **Organization Claim** setting matches your IdP
3. Ensure the organization's **OIDC Claim Value** matches the claim value

### User Has Incorrect Role

1. Check if the user is in the correct IdP group
2. Verify the **Groups Claim** is configured correctly
3. Check if **Role Override** is enabled for manual role assignment
4. Review role claim value mappings

### Org Manager Cannot See Users

1. Verify the Org Manager is assigned to the correct organization
2. Ensure multi-tenant mode is enabled
3. Check that users have the same `organization_id`

