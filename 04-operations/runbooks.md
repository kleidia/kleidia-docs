# Operational Runbooks

**Audience**: IT Operations, Helpdesk, Security Operations  
**Prerequisites**: Access to Kleidia admin interface and/or Kubernetes cluster  
**Outcome**: Resolve incidents efficiently with documented procedures

## Runbook Overview

This document provides step-by-step procedures for common incidents and operational scenarios. Each runbook follows a consistent structure:

- **Trigger**: What initiates this procedure
- **Roles Involved**: Who participates
- **Actions**: Step-by-step procedure
- **Expected Outcome**: What success looks like
- **Related Docs**: Links to additional information

---

## Lost or Stolen YubiKey

### Trigger

User reports their YubiKey as lost, stolen, or potentially compromised.

### Roles Involved

| Role | Responsibility |
|------|----------------|
| **End User** | Reports incident to helpdesk |
| **Helpdesk** | Verifies identity, initiates revocation |
| **Security Team** | Reviews for signs of compromise, approves replacement |

### Actions

#### 1. Verify User Identity

Before taking any action, verify the reporter's identity using your organization's verification policy (e.g., callback, manager confirmation, security questions).

#### 2. Locate Device in Kleidia

1. Log into Kleidia admin interface
2. Navigate to **Admin** → **YubiKeys**
3. Search for the user's device by:
   - User name/email
   - Device serial number (if known)

#### 3. Revoke All Certificates

1. Select the lost YubiKey
2. Click **Revoke All Certificates**
3. Confirm the revocation
4. Certificates are added to CRL immediately

#### 4. Disable Device

1. Select **Mark as Lost/Stolen**
2. Device status changes to disabled
3. Document the incident in the notes field

#### 5. Disable FIDO2 Credentials

1. Navigate to **FIDO2 Credentials** for the user
2. Remove/disable all credentials associated with the lost device
3. Verify removal in the credential list

#### 6. Document in Audit Log

1. Navigate to **Audit Logs**
2. Verify revocation and disable events are logged
3. Add incident reference number if applicable

#### 7. Issue Replacement (Optional)

If user needs a replacement:

1. Obtain new YubiKey from inventory
2. Navigate to **YubiKeys** → **Register New Device**
3. Follow enrollment wizard for the user
4. Generate new certificates
5. Register new FIDO2 credentials

### Expected Outcome

- ✅ All certificates on lost device are revoked
- ✅ Device is marked as lost/disabled in system
- ✅ FIDO2 credentials are removed
- ✅ Audit log documents all actions
- ✅ User has replacement device (if applicable)

### Time to Resolution

| Priority | Target |
|----------|--------|
| Lost (no suspected theft) | 4 hours |
| Stolen/Compromised | 1 hour |

### Related Docs

- [YubiKey Lifecycle](../user-guides/yubikey-lifecycle/)
- [FIDO2 Management](../05-using-the-system/fido2-management.md)
- [Security for Auditors](../security/for-auditors/)

---

## User Leaves Company

### Trigger

HR notifies IT that a user is leaving the organization (voluntary or involuntary).

### Roles Involved

| Role | Responsibility |
|------|----------------|
| **HR** | Initiates departure notification |
| **Helpdesk/IT Admin** | Executes credential revocation |
| **User's Manager** | Confirms departure, coordinates handoff |
| **Security Team** | Verifies complete revocation (high-risk departures) |

### Actions

#### 1. Receive Departure Notification

Document receipt of notification including:
- User name/email
- Last working day
- Priority (standard vs. immediate termination)

#### 2. Identify User's YubiKey(s)

1. Log into Kleidia admin interface
2. Navigate to **Admin** → **Users**
3. Search for departing user
4. List all assigned YubiKeys

#### 3. Revoke All Certificates

For each YubiKey:

1. Select the device
2. Click **Revoke All Certificates**
3. Confirm revocation
4. Verify certificates added to CRL

#### 4. Disable FIDO2 Credentials

1. Navigate to **FIDO2 Credentials** for the user
2. Remove all registered credentials
3. Verify removal complete

#### 5. Disable or Retire Devices

Based on your organization's policy:

**Option A: Retire Device**
- Mark device as retired
- Physical device collected and securely disposed

**Option B: Reassign Device**
- Mark device as available
- Wipe PIV certificates and keys
- Reset PIN/PUK to defaults
- Re-enroll to new user

#### 6. Disable User Account

1. Navigate to **Admin** → **Users**
2. Select the departing user
3. Click **Disable Account**
4. User can no longer log in

#### 7. Generate Departure Report

1. Navigate to **Audit Logs**
2. Filter by user
3. Export log for compliance records
4. Attach to HR departure file

### Expected Outcome

- ✅ All user certificates revoked
- ✅ All FIDO2 credentials removed
- ✅ User account disabled
- ✅ Devices collected or reassigned
- ✅ Audit trail documented
- ✅ Report generated for HR/compliance

### Time to Resolution

| Departure Type | Target |
|----------------|--------|
| Standard (2+ weeks notice) | Before last day |
| Immediate termination | Within 1 hour of notification |

### Related Docs

- [Administrator Guide](../user-guides/admin-guide/)
- [YubiKey Lifecycle](../user-guides/yubikey-lifecycle/)
- [Compliance Considerations](../security/compliance/)

---

## OpenBao/Vault Failure

### Trigger

OpenBao (Vault) is unavailable, sealed, or returning errors.

### Roles Involved

| Role | Responsibility |
|------|----------------|
| **Operations/DevOps** | Diagnose and restore service |
| **Security Team** | Provide unseal keys if needed |
| **Management** | Authorize data restoration if needed |

### Actions

#### 1. Identify the Issue

Check Vault status:

```bash
kubectl exec -it kleidia-openbao-0 -n kleidia -- vault status
```

Common states:
- **Sealed**: Vault needs to be unsealed
- **Standby**: HA replica, not primary
- **Active**: Should be working
- **Pod not running**: Container issue

#### 2. If Vault is Sealed

Unseal using your organization's procedure:

```bash
# Unseal with key shares (repeat for each key holder)
kubectl exec -it kleidia-openbao-0 -n kleidia -- \
  vault operator unseal <key-share>
```

> **Note**: Your organization should have a documented key ceremony procedure. Never store unseal keys in the same location.

#### 3. If Pod is Crashing

Check pod logs:

```bash
kubectl logs kleidia-openbao-0 -n kleidia --previous
kubectl describe pod kleidia-openbao-0 -n kleidia
```

Common issues:
- **Storage full**: Expand PVC or clean up
- **Memory limits**: Increase resource limits
- **Network issues**: Check service connectivity

#### 4. If Data Corruption Suspected

Stop dependent services first:

```bash
# Scale down backend
kubectl scale deployment/kleidia-backend --replicas=0 -n kleidia
```

Restore from backup:

```bash
# Copy backup to pod
kubectl cp backups/vault-snapshot.snap \
  kleidia-openbao-0:/tmp/vault-snapshot.snap -n kleidia

# Restore snapshot
kubectl exec -it kleidia-openbao-0 -n kleidia -- \
  vault operator raft snapshot restore /tmp/vault-snapshot.snap

# Unseal after restore
kubectl exec -it kleidia-openbao-0 -n kleidia -- \
  vault operator unseal <key-share>
```

Restart dependent services:

```bash
kubectl scale deployment/kleidia-backend --replicas=2 -n kleidia
```

#### 5. Verify Recovery

```bash
# Check Vault is active
kubectl exec -it kleidia-openbao-0 -n kleidia -- vault status

# Check secrets are accessible
kubectl exec -it kleidia-openbao-0 -n kleidia -- \
  vault kv list yubikeys/metadata/

# Check PKI is functional
kubectl exec -it kleidia-openbao-0 -n kleidia -- \
  vault read pki/cert/ca
```

#### 6. Test Kleidia Operations

1. Log into Kleidia web UI
2. Verify YubiKey operations work
3. Test certificate generation on a test device
4. Review audit logs for errors

### Expected Outcome

- ✅ Vault is unsealed and active
- ✅ All secrets are accessible
- ✅ PKI engine is functional
- ✅ Kleidia operations work normally
- ✅ Incident documented

### Escalation

If unable to restore:
1. Contact Kleidia support
2. Engage security team for key ceremony
3. Consider point-in-time recovery from backups

### Related Docs

- [Vault Setup](../deployment/vault-setup/)
- [Backups & Restore](backups/)
- [Troubleshooting](../03-deployment/troubleshooting.md)

---

## Database Failure

### Trigger

PostgreSQL database is unavailable or returning errors.

### Roles Involved

| Role | Responsibility |
|------|----------------|
| **Operations/DevOps** | Diagnose and restore service |
| **DBA (if available)** | Assist with complex recovery |

### Actions

#### 1. Identify the Issue

Check pod status:

```bash
kubectl get pods -n kleidia | grep postgres
kubectl describe pod kleidia-postgresql-0 -n kleidia
```

Check logs:

```bash
kubectl logs kleidia-postgresql-0 -n kleidia
```

#### 2. If Pod is Not Running

Restart the pod:

```bash
kubectl delete pod kleidia-postgresql-0 -n kleidia
# StatefulSet will recreate it
```

If persistent volume issue:

```bash
kubectl describe pvc data-kleidia-postgresql-0 -n kleidia
```

#### 3. If Database Corruption

Stop dependent services:

```bash
kubectl scale deployment/kleidia-backend --replicas=0 -n kleidia
```

Restore from backup:

```bash
# Restore database
gunzip -c backups/kleidia-db.sql.gz | \
  kubectl exec -i kleidia-postgresql-0 -n kleidia -- \
  psql -U kleidia -d kleidia
```

Restart services:

```bash
kubectl scale deployment/kleidia-backend --replicas=2 -n kleidia
```

#### 4. Verify Recovery

```bash
# Check database connectivity
kubectl exec -it kleidia-postgresql-0 -n kleidia -- \
  psql -U kleidia -d kleidia -c "SELECT 1;"

# Check tables exist
kubectl exec -it kleidia-postgresql-0 -n kleidia -- \
  psql -U kleidia -d kleidia -c "\dt"
```

### Expected Outcome

- ✅ Database pod running
- ✅ Data accessible
- ✅ Kleidia backend connects successfully
- ✅ Audit logs intact

### Related Docs

- [Backups & Restore](backups/)
- [Troubleshooting](../03-deployment/troubleshooting.md)

---

## Additional Runbooks

### Agent Pairing Issues

See [Troubleshooting Guide](../03-deployment/troubleshooting.md) for agent connectivity problems.

### Certificate Expiry

See [Certificates & PKI](../security/certificates-and-pki/) for certificate renewal procedures.

### TLS Certificate Expiry

See [Load Balancer Setup](../deployment/load-balancer/) for TLS certificate management.

---

## Related Documentation

- [Daily Operations](daily-operations/)
- [Monitoring & Logs](monitoring/)
- [Backups & Restore](backups/)
- [Troubleshooting](../03-deployment/troubleshooting.md)
