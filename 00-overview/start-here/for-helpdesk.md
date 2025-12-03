
# Start Here: Helpdesk & Support Staff

**Audience**: IT Helpdesk, Support Engineers, IT Administrators handling user requests  
**Prerequisites**: Basic understanding of YubiKeys and authentication concepts  
**Outcome**: Handle common user requests efficiently—PIN resets, lost keys, and enrollment support

## Your Role

As helpdesk or support staff, you're the first point of contact for users experiencing issues with their YubiKeys. You need to know how to guide users through common tasks, handle lost device reports, and escalate appropriately.

## Recommended Reading Path

### 1. Understand User Workflows

Learn what users do with Kleidia:

- **[End User Guide](../user-guides/end-user-guide/)** - What users see and do in the system
- **[YubiKey Lifecycle](../user-guides/yubikey-lifecycle/)** - Device states from enrollment to retirement

### 2. Common Support Tasks

Master the procedures you'll use most often:

- **[Administrator Guide](../user-guides/admin-guide/)** - Admin interface for managing users and devices
- **[FIDO2 Management](../05-using-the-system/fido2-management.md)** - WebAuthn credential management and troubleshooting

### 3. Incident Response

Know what to do when things go wrong:

- **[Runbooks](../04-operations/runbooks.md)** - Step-by-step procedures for common incidents:
  - Lost or stolen YubiKey
  - User leaves the organization
  - PIN lockout recovery

## Common Support Scenarios

### User Forgot Their PIN

1. User contacts helpdesk
2. Verify user identity (follow your organization's verification policy)
3. Navigate to user's YubiKey in Kleidia admin
4. Use "Reset PIN" function
5. Communicate new PIN securely to user
6. User must change PIN on first use

📖 See: [YubiKey Lifecycle](../user-guides/yubikey-lifecycle/) for detailed procedure

### User Lost Their YubiKey

**Immediate Actions**:
1. Verify user identity
2. Mark device as lost in Kleidia
3. Revoke all certificates on the device
4. Disable FIDO2 credentials

**Follow-up**:
1. Issue replacement YubiKey
2. Enroll new device for user
3. Generate new certificates
4. Document incident

📖 See: [Lost YubiKey Runbook](../operations/runbooks/#lost-or-stolen-yubikey)

### User Leaving the Organization

1. Receive notification from HR/manager
2. Revoke all certificates on user's YubiKey(s)
3. Disable FIDO2 credentials
4. Mark devices as available for re-assignment (or retire)
5. Document in audit log

📖 See: [User Departure Runbook](../operations/runbooks/#user-leaves-company)

### User Can't Enroll YubiKey

**Check**:
1. Is the Kleidia Agent running? (`http://127.0.0.1:56123/.well-known/kleidia-agent`)
2. Is the YubiKey inserted and recognized by the OS?
3. Is the user logged into Kleidia with correct permissions?
4. Is the YubiKey already registered to another user?

📖 See: [Agent Installation](../05-using-the-system/agent-installation.md) for troubleshooting

## Quick Reference Card

| User Request | Action | Documentation |
|--------------|--------|---------------|
| Forgot PIN | Reset via admin interface | [YubiKey Lifecycle](../user-guides/yubikey-lifecycle/) |
| Lost YubiKey | Revoke, disable, replace | [Lost Key Runbook](../04-operations/runbooks.md) |
| New YubiKey | Enroll via web UI | [End User Guide](../user-guides/end-user-guide/) |
| Can't authenticate | Check cert validity, PIN attempts | [Troubleshooting](../03-deployment/troubleshooting.md) |
| Leaving company | Revoke all, disable device | [Departure Runbook](../04-operations/runbooks.md) |
| Agent not working | Verify agent service running | [Agent Installation](../05-using-the-system/agent-installation.md) |

## Escalation Guide

**Escalate to Operations/DevOps when**:
- Kleidia web interface is unavailable
- Multiple users affected simultaneously
- Agent installation issues not resolved by reinstall
- Certificate signing failures (PKI issues)

**Escalate to Security when**:
- Suspected security incident
- Multiple lost device reports in short time
- Unauthorized access attempts detected in audit log

## Next Steps

1. **Practice in Test Environment**: Get access to a [POC deployment](poc-quickstart.md) to practice workflows
2. **Bookmark Key Pages**: Keep runbooks accessible for quick reference
3. **Know Your Escalation Path**: Understand who to contact for different issue types

