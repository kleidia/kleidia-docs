
# POC Quickstart: Your First YubiKey Journey

**Audience**: Security Engineers, DevOps Engineers, IAM Engineers evaluating Kleidia  
**Prerequisites**: 
- Access to a Kubernetes cluster (minikube, kind, or managed K8s)
- Helm 3.8+ installed
- kubectl configured for your cluster
- One YubiKey 5 series device for testing
- Test workstation (Windows, macOS, or Linux)

**Outcome**: Deploy Kleidia in a test environment, enroll one YubiKey, issue a PIV certificate, manage FIDO2 settings, and verify operations in the audit log.

**Time Required**: ~30-45 minutes

---

## Overview

This quickstart walks you through a complete proof-of-concept deployment of Kleidia, from installation to enrolling your first YubiKey with certificates and FIDO2 PIN management. By the end, you'll have hands-on experience with the core workflows.

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

Clone the repository and install using the local Helm charts:

```bash
# Clone the repository
git clone https://github.com/kleidia/kleidia-docs.git
cd kleidia-docs

# Create namespace
kubectl create namespace kleidia
```

Install the Helm charts in order:

```bash
# Step 1: Install Platform (OpenBao, Storage)
helm install kleidia-platform ./helm/kleidia-platform \
  --namespace kleidia \
  --set global.domain=kleidia.local \
  --set global.namespace=kleidia \
  --set storage.className=standard \
  --set storage.localPath.enabled=true

# Wait for OpenBao to be ready (5-10 minutes)
kubectl -n kleidia get pods -w

# Step 2: Install Data Layer (PostgreSQL)
helm install kleidia-data ./helm/kleidia-data \
  --namespace kleidia \
  --set global.domain=kleidia.local \
  --set global.namespace=kleidia

# Step 3: Install Services (Backend, Frontend)
helm install kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --set global.domain=kleidia.local \
  --set global.namespace=kleidia
```

Wait for all pods to be ready:

```bash
kubectl -n kleidia get pods -w
```

Expected output (all pods `Running` and `Ready`):

```
NAME                                    READY   STATUS    RESTARTS   AGE
kleidia-platform-openbao-0              1/1     Running   0          5m
kleidia-data-postgres-cluster-0         1/1     Running   0          3m
kleidia-services-backend-xxx            1/1     Running   0          2m
kleidia-services-frontend-xxx           1/1     Running   0          2m
```

For full installation options and production configuration, see [Helm Installation](../deployment/helm-install/).

---

## Step 3: Configure Access

For local testing, set up port forwarding:

```bash
# Frontend (web UI)
kubectl -n kleidia port-forward svc/frontend-service 8080:3000 &

# Backend API
kubectl -n kleidia port-forward svc/backend-service 8081:8080 &
```

Access the web UI at: **http://localhost:8080**

---

## Step 4: Configure OpenBao PKI (PoC Mode)

In this PoC configuration, OpenBao is initialised with a self-signed root CA via the provided Helm values. Verify the PKI is ready:

```bash
kubectl -n kleidia exec -it kleidia-platform-openbao-0 -- vault secrets list
```

You should see `pki/` in the list of enabled secrets engines.

> **Production Note**: For production, configure OpenBao as an intermediate CA under your existing PKI hierarchy. See [PKI Integration Patterns](../deployment/pki-integration/).

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

Download and install the Kleidia Agent on your test workstation.

> **Important**: Download the latest agent installer for your platform from the [GitHub Releases](https://github.com/kleidia/kleidia-docs/releases) page or your organization's approved software distribution source. See [Installers](../installers/) for detailed installation instructions.

### Windows

```powershell
# Download the MSI installer from GitHub Releases
# https://github.com/kleidia/kleidia-docs/releases

# Install (replace with actual filename)
msiexec /i kleidia-agent-<version>.msi /quiet BACKEND_URL=http://localhost:8081
```

### macOS

```bash
# Download the PKG installer from GitHub Releases
# https://github.com/kleidia/kleidia-docs/releases

# Install (replace with actual filename)
sudo installer -pkg kleidia-agent-<version>.pkg -target /
```

For enterprise deployment options (GPO, Intune, Jamf), see [Windows Enterprise Deployment](../installers/windows-enterprise/) or [macOS Enterprise Deployment](../installers/macos-enterprise/).

Verify the agent is running:

```bash
curl http://127.0.0.1:56123/health
```

Expected response:

```json
{"status":"ok"}
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

> **Security Note**: Kleidia stores secrets required for PIV operations in OpenBao/Vault. See [Vault & Secrets Management](../security/vault-and-secrets/) for details.

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

## Step 9: FIDO2 Management (Optional)

Kleidia allows you to manage FIDO2 settings on your YubiKey. This includes PIN management, viewing registered services, and resetting the FIDO2 applet when needed.

> **Important**: Kleidia does **not** register FIDO2 credentials with service providers. Registration of FIDO2 credentials with identity providers (like Microsoft Entra ID, Google, GitHub) is done via those systems' own UIs and policies.

### Set or Change FIDO2 PIN

1. **Navigate to FIDO2 Management** for your YubiKey
2. **Go to the PIN tab**
3. **Set a new PIN** (4-63 characters) or change an existing one
4. The FIDO2 PIN is separate from your PIV PIN

### View Registered Credentials

1. **Go to the Credentials tab**
2. **Enter your FIDO2 PIN**
3. **View the list of services** where your YubiKey is registered (e.g., `login.microsoftonline.com`, `github.com`)

This helps administrators and users see which relying parties have FIDO2 credentials stored on the device.

### Reset FIDO2 Applet (If Needed)

> ⚠️ **Warning**: Resetting permanently erases all FIDO2 credentials. You will need to re-register with all services.

Use this if the FIDO2 PIN is locked or you need to clear all credentials:

1. **Go to the Advanced tab**
2. **Click Reset FIDO2 Applet**
3. **Confirm the warning**

For detailed FIDO2 management procedures, see [FIDO2 Management Guide](../user-guides/fido2-management/).

---

## Step 10: View the Audit Log

1. **Navigate to Admin** → **Audit Logs**

2. **Review recent operations**:
   - YubiKey registration
   - PIN configuration
   - Certificate generation and signing
   - FIDO2 PIN changes or resets

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
| Managed FIDO2 settings (optional) | ✅ |
| Reviewed audit logs | ✅ |

---

## Required vs Optional Steps

| Step | Required for Basic PoC | Notes |
|------|------------------------|-------|
| Kubernetes cluster | ✅ Required | minikube or kind sufficient |
| Helm installation | ✅ Required | All three charts needed |
| OpenBao PKI (PoC mode) | ✅ Required | Auto-configured by Helm |
| Agent installation | ✅ Required | Needed for YubiKey communication |
| YubiKey enrollment | ✅ Required | Core functionality |
| PIV certificate issuance | ✅ Required | Core functionality |
| Audit log review | ✅ Required | Verify operations |
| IdP/Entra integration | ⚪ Optional | For SSO testing |
| FIDO2 management | ⚪ Optional | PIN and credential viewing |
| Production PKI integration | ⚪ Advanced | See PKI docs |

---

## Next Steps

Now that you've completed the POC, explore these areas:

### Deeper Documentation

- **[Helm Installation](../deployment/helm-install/)** - Production deployment with HA and custom configuration
- **[PKI Integration Patterns](../deployment/pki-integration/)** - Connect to your enterprise CA
- **[Azure Entra Integration](../deployment/azure-entra/)** - Full OIDC/SSO setup
- **[YubiKey Lifecycle](../user-guides/yubikey-lifecycle/)** - Complete device management workflows
- **[FIDO2 Management](../user-guides/fido2-management/)** - PIN management and credential viewing

### Production Planning

- **[Prerequisites](../deployment/prerequisites/)** - Infrastructure requirements
- **[Security Overview](../security/)** - Security model and compliance
- **[Operations Guide](../operations/)** - Day-2 operations and runbooks

### Get Help

- Review the [Troubleshooting Guide](../deployment/troubleshooting/)
- Check [GitHub Issues](https://github.com/kleidia/kleidia-docs/issues) for known issues

---

## Cleanup

To remove the POC deployment:

```bash
# Uninstall in reverse order
helm uninstall kleidia-services --namespace kleidia
helm uninstall kleidia-data --namespace kleidia
helm uninstall kleidia-platform --namespace kleidia

# Delete namespace
kubectl delete namespace kleidia

# Stop port forwarding
pkill -f "kubectl.*port-forward"
```

