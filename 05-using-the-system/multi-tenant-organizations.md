# Multi-Tenant Organizations

Kleidia supports multi-tenant organization isolation, allowing subsidiaries or departments to be isolated so that Org-Admins can only see and manage YubiKeys belonging to users in their organization.

## Overview

Multi-tenancy enables enterprise deployments where:
- Different subsidiaries/departments need isolated management
- Delegated administration is required without full system access
- Users are automatically assigned to organizations via OIDC claims
- Privileged roles are managed through IdP groups

## Role Hierarchy

| Role | Scope | Capabilities |
|------|-------|--------------|
| **Super-Admin** | Global | Full system access. Manage all organizations, users, and system settings. |
| **Org-Admin** | Organization | View/manage YubiKeys and users within their organization only. Access compliance reports and audit logs scoped to their org. |
| **User** | Self | Manage their own YubiKey only. |

### Menu Access by Role

| Menu Item | Super-Admin | Org-Admin | User |
|-----------|-------------|-----------|------|
| Dashboard | ✓ | ✓ | ✓ |
| My YubiKeys | ✓ | ✓ | ✓ |
| Register YubiKey | ✓ | ✓ | ✓ |
| Admin Panel | ✓ | ✓ | - |
| Manage YubiKeys | ✓ | ✓ (org only) | - |
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

### Claim Mapping

Configure which OIDC claims Kleidia should use:

| Setting | Description | Default |
|---------|-------------|---------|
| **Organization Claim** | The claim containing the user's organization | `organization` |
| **Role Claim** | The claim containing the user's role | `kleidia_role` |
| **Groups Claim** | The claim containing user groups | `groups` |

### Role Assignment Priority

Roles are assigned in the following order of precedence:

1. **IdP Groups (Highest Priority)** – If the user is a member of a configured super-admin or org-admin group
2. **Role Claim Value** – If the role claim matches configured values
3. **Default** – User role

### Group-Based Role Assignment (Recommended)

For security-sensitive environments, use IdP groups to manage privileged access:

| Setting | Description | Example |
|---------|-------------|---------|
| **Super-Admin Groups** | IdP groups that grant Super-Admin access | `kleidia-super-admins, global-admins` |
| **Org-Admin Groups** | IdP groups that grant Org-Admin access | `kleidia-org-admins, department-admins` |

**Benefits:**
- Centralized access management in your IdP
- Revoking access is as simple as removing group membership
- Audit trail in your IdP for privilege changes
- No manual role assignment required in Kleidia

### Role Claim Value Mapping (Fallback)

If not using group-based assignment:

| Setting | Description | Default |
|---------|-------------|---------|
| **Super-Admin Value** | Role claim value for Super-Admin | `super_admin` |
| **Org-Admin Value** | Role claim value for Org-Admin | `org_admin` |

## Managing Organizations

Super-Admins can manage organizations from **Admin Panel** → **Organizations**.

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

Super-Admins can manually assign roles via **Admin Panel** → **Manage Users** → **Update Role**.

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
- `kleidia-super-admins` – For global administrators
- `kleidia-org-admins` – For organization administrators

### 3. Configure Kleidia

In Kleidia's Multi-Tenant settings:
- **Groups Claim**: `groups`
- **Super-Admin Groups**: Enter the Group IDs (GUIDs) for super-admin groups
- **Org-Admin Groups**: Enter the Group IDs (GUIDs) for org-admin groups

### 4. Organization Claim (Optional)

If using organization-based isolation:
1. Add a custom claim or extension attribute for organization
2. Configure the **Organization Claim** in Kleidia

## Example: Okta Configuration

### 1. Configure Groups Claim

In your Okta Application:
1. Go to **Sign On** → **OpenID Connect ID Token**
2. Add a **Groups claim** with the filter for relevant groups

### 2. Create Groups

Create groups in Okta:
- `kleidia-super-admins`
- `kleidia-org-admins`

### 3. Configure Kleidia

In Kleidia's Multi-Tenant settings:
- **Groups Claim**: `groups`
- **Super-Admin Groups**: `kleidia-super-admins`
- **Org-Admin Groups**: `kleidia-org-admins`

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

### Org-Admin Cannot See Users

1. Verify the Org-Admin is assigned to the correct organization
2. Ensure multi-tenant mode is enabled
3. Check that users have the same `organization_id`

