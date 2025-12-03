# POC Quickstart: Your First YubiKey Journey

**Audience**: Security Engineers, DevOps Engineers, IAM Engineers evaluating Kleidia  
**Prerequisites**: 
- Access to a Kubernetes cluster (minikube, kind, or managed K8s)
- Helm 3.x installed
- kubectl configured for your cluster
- One YubiKey 5 series device for testing
- Test workstation (Windows, macOS, or Linux)

**Outcome**: Deploy Kleidia in a test environment, enroll one YubiKey, issue a PIV certificate, register a FIDO2 credential, and verify operations in the audit log.

**Time Required**: ~30-45 minutes

---

## Overview

This quickstart walks you through a complete proof-of-concept deployment of Kleidia, from installation to enrolling your first YubiKey with certificates and FIDO2 credentials. By the end, you'll have hands-on experience with the core workflows.

> **Note**: This guide uses a self-signed root CA suitable for lab environments only. For production deployments, see [PKI Integration Patterns](../deployment/pki-integration/).

---

## Step 1: Prepare Your Test Cluster

Ensure you have a working Kubernetes cluster. For local testing:

```bash
# Using minikube
minikube start --cpus=4 --memory=8192

# Or using kind
kind create cluster --name kleidia-poc
```

Verify cluster access:

```bash
kubectl cluster-info
kubectl get nodes
```

---

## Step 2: Install Kleidia via Helm

Add the Kleidia Helm repository and install:

```bash
# Add Helm repo
helm repo add kleidia https://charts.kleidia.io
helm repo update

# Create namespace
kubectl create namespace kleidia

# Install with POC-friendly defaults
helm install kleidia kleidia/kleidia \
  --namespace kleidia \
  --set global.domain=kleidia.local \
  --set openbao.server.dev.enabled=true \
  --set postgresql.auth.postgresPassword=poc-password-change-me \
  --wait
```

Wait for all pods to be ready:

```bash
kubectl -n kleidia get pods -w
```

Expected output (all pods `Running` and `Ready`):

```
NAME                              READY   STATUS    RESTARTS   AGE
kleidia-backend-xxx-xxx           1/1     Running   0          2m
kleidia-frontend-xxx-xxx          1/1     Running   0          2m
kleidia-postgresql-0              1/1     Running   0          2m
kleidia-openbao-0                 1/1     Running   0          2m
```

---

## Step 3: Configure Access

For local testing, set up port forwarding:

```bash
# Frontend (web UI)
kubectl -n kleidia port-forward svc/kleidia-frontend 8080:80 &

# Backend API
kubectl -n kleidia port-forward svc/kleidia-backend 8081:8080 &
```

Access the web UI at: **http://localhost:8080**

---

## Step 4: Configure OpenBao PKI (PoC Mode)

The Helm chart automatically configures OpenBao with a self-signed root CA for PoC deployments. Verify the PKI is ready:

```bash
kubectl -n kleidia exec -it kleidia-openbao-0 -- vault secrets list
```

You should see `pki/` in the list of enabled secrets engines.

> **Production Note**: In production, you would configure OpenBao as an intermediate CA under your existing PKI. See [PKI Integration Patterns](../deployment/pki-integration/).

---

## Step 5: Configure Identity Provider (Optional)

For a complete test, configure Azure Entra ID or another OIDC provider:

1. Navigate to **Admin Settings** → **Identity Provider**
2. Enter your OIDC configuration:
   - **Issuer URL**: `https://login.microsoftonline.com/{tenant-id}/v2.0`
   - **Client ID**: Your app registration client ID
   - **Client Secret**: Your app registration secret

For detailed setup, see [Azure Entra Integration](../deployment/azure-entra/).

> **Tip**: For quick testing without OIDC, use the default admin account created during installation.

---

## Step 6: Install the Kleidia Agent

Download and install the Kleidia Agent on your test workstation:

### Windows

```powershell
# Download installer
Invoke-WebRequest -Uri "https://releases.kleidia.io/agent/latest/kleidia-agent-windows.msi" -OutFile kleidia-agent.msi

# Install
msiexec /i kleidia-agent.msi /quiet
```

### macOS

```bash
# Download and install
curl -LO https://releases.kleidia.io/agent/latest/kleidia-agent-macos.pkg
sudo installer -pkg kleidia-agent-macos.pkg -target /
```

### Linux

```bash
# Download and install (Debian/Ubuntu)
curl -LO https://releases.kleidia.io/agent/latest/kleidia-agent-linux.deb
sudo dpkg -i kleidia-agent-linux.deb
```

Verify the agent is running:

```bash
curl http://127.0.0.1:56123/.well-known/kleidia-agent
```

Expected response:

```json
{"status":"ok","version":"2.x.x"}
```

---

## Step 7: Enroll Your First YubiKey

1. **Insert YubiKey** into your test workstation

2. **Log into Kleidia** web UI at http://localhost:8080

3. **Navigate to YubiKeys** → **Register New Device**

4. **Follow the enrollment wizard**:
   - Kleidia detects your YubiKey automatically
   - Enter a friendly name for the device
   - The agent reads the YubiKey serial number

5. **Set PIV PIN**:
   - Choose a 6-8 digit PIN
   - Kleidia securely stores the PIN in OpenBao
   - The PIN is required for certificate operations

---

## Step 8: Issue a PIV Certificate

1. **Navigate to your enrolled YubiKey**

2. **Select "Generate Certificate"** for slot 9a (Authentication)

3. **Configure certificate details**:
   - Common Name: `testuser@example.com`
   - The system auto-generates a CSR on the YubiKey

4. **Sign and import**:
   - Kleidia signs the CSR using OpenBao PKI
   - The signed certificate is imported to the YubiKey

5. **Verify the certificate**:
   - View certificate details in the UI
   - Check issuer, validity, and key usage

> **What happened behind the scenes**:
> - The YubiKey generated a key pair internally (private key never leaves the device)
> - A CSR was created and sent to OpenBao for signing
> - The signed certificate was imported back to the YubiKey

---

## Step 9: Register a FIDO2 Credential

1. **Navigate to FIDO2 Management** for your YubiKey

2. **Select "Register New Credential"**

3. **Follow the WebAuthn flow**:
   - Your browser prompts for YubiKey interaction
   - Touch the YubiKey to confirm
   - Enter the FIDO2 PIN if prompted

4. **Verify registration**:
   - The credential appears in the FIDO2 credential list
   - Associated with your user account

---

## Step 10: View the Audit Log

1. **Navigate to Admin** → **Audit Logs**

2. **Review recent operations**:
   - YubiKey registration
   - PIN configuration
   - Certificate generation and signing
   - FIDO2 credential registration

3. **Verify audit completeness**:
   - Each operation includes timestamp, user, action, and outcome
   - Supports compliance reporting requirements

---

## What You've Accomplished

| Milestone | Status |
|-----------|--------|
| Deployed Kleidia in Kubernetes | ✅ |
| Configured OpenBao PKI (PoC mode) | ✅ |
| Installed Kleidia Agent | ✅ |
| Enrolled a YubiKey | ✅ |
| Issued a PIV certificate | ✅ |
| Registered a FIDO2 credential | ✅ |
| Reviewed audit logs | ✅ |

---

## Next Steps

Now that you've completed the POC, explore these areas:

### Deeper Documentation

- **[Deployment Guide](../03-deployment/helm-install.md)** - Production deployment with HA and custom configuration
- **[PKI Integration Patterns](../deployment/pki-integration/)** - Connect to your enterprise CA
- **[Azure Entra Integration](../deployment/azure-entra/)** - Full OIDC/SSO setup
- **[YubiKey Lifecycle](../user-guides/yubikey-lifecycle/)** - Complete device management workflows
- **[FIDO2 Management](../05-using-the-system/fido2-management.md)** - WebAuthn credential management

### Production Planning

- **[Prerequisites](../03-deployment/prerequisites.md)** - Infrastructure requirements
- **[Security Overview](../02-security/security-overview.md)** - Security model and compliance
- **[Operations Guide](../04-operations/daily-operations.md)** - Day-2 operations and runbooks

### Get Help

- Review the [Troubleshooting Guide](../03-deployment/troubleshooting.md)
- Contact [support@kleidia.io](mailto:support@kleidia.io) for assistance

---

## Cleanup

To remove the POC deployment:

```bash
# Delete Kleidia
helm uninstall kleidia --namespace kleidia

# Delete namespace
kubectl delete namespace kleidia

# Stop port forwarding
pkill -f "kubectl.*port-forward"
```

