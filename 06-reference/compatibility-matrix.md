# Compatibility Matrix

**Audience**: Operations Administrators  
**Prerequisites**: None  
**Outcome**: Understand system compatibility requirements

## Server Requirements

### Kubernetes Cluster

Kleidia requires a Kubernetes cluster (version 1.24+) with NodePort support. The specific Kubernetes distribution is not relevant - any compatible Kubernetes cluster will work.

### Helm Versions

| Version | Status           | Notes           |
|---------|------------------|-----------------|
| 3.8+    | ✅ Supported     | Recommended     |
| 3.7     | ✅ Supported     | Compatible      |
| 3.6     | ⚠️ Limited       | Not recommended |
| 3.5-    | ❌ Not Supported |                 |

## Application Components

### Backend

| Component  | Version | Status       | Notes          |
|------------|---------|--------------|----------------|
| Go         | 1.21+   | ✅ Supported | Required       |
| PostgreSQL | 13+     | ✅ Supported | Recommended 15 |
| OpenBao    | 2.4+    | ✅ Supported | Vault fork     |

### Frontend

| Component | Version | Status       | Notes                        |
|-----------|---------|--------------|------------------------------|
| Vue.js    | 3       | ✅ Supported | Required                      |
| Nuxt.js   | 4       | ✅ Supported | Required                      |
| Browser   | Modern  | ✅ Supported | Chrome, Firefox, Safari, Edge |

### Agent

| Component | Version              | Status      | Notes                         |
|-----------|----------------------|-------------|-------------------------------|
| Go        | 1.21+                | ✅ Supported | Required                     |
| ykman     | Latest               | ✅ Supported | Bundled with agent installer |
| OS        | Windows 10/11, macOS | ✅ Supported | Windows and macOS only       |

## Browser Compatibility

### Supported Browsers

| Browser | Version | Status           | Notes       |
|---------|---------|------------------|-------------|
| Chrome  | Latest  | ✅ Supported     | Recommended |
| Firefox | Latest  | ✅ Supported     | Recommended |
| Safari  | Latest  | ❌ Not Supported | N/A         |
| Edge    | Latest  | ✅ Supported     | Windows     |

### Required Features

- **HTTPS Support**: Required for secure communication
- **Localhost Access**: Required for agent communication
- **WebCrypto API**: Required for encryption operations
- **Fetch API**: Required for API calls

## YubiKey Compatibility

### Supported YubiKey Models

| Model            | Status       | Notes |
|------------------|--------------|-------|
| YubiKey 5 Series | ✅ Supported | All variants |
| YubiKey 4 Series | ✅ Supported | All variants |
| YubiKey NEO      | ⚠️ Limited   | Basic support |

### Required Features

- **PIV Application**: Required for certificate operations
- **USB Support**: Required for device connection
- **ykman Compatibility**: Required for operations

## Network Requirements

### Ports

| Port  | Protocol | Direction | Purpose             |
|-------|----------|-----------|---------------------|
| 443   | HTTPS    | Inbound   | Web interface       |
| 56123 | HTTP     | Localhost | Agent (workstation) |

### DNS

- **A Record**: Required for domain name

## Storage Requirements

### Minimum Storage

- **Main Disk**: 30GB available
- **Database**: 10GB persistent volume
- **Vault**: 10GB persistent volume
- **Audit Logs**: 10GB persistent volume

### Recommended Storage

- **Main Disk**: 50GB+ available
- **Database**: 50GB+ persistent volume
- **OpenBao**: 20GB+ persistent volume

## Resource Requirements

### Minimum Resources

- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 30GB

### Recommended Resources (Production)

- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Storage**: 50GB+

## Version Compatibility

### Kleidia Versions

| Version | Kubernetes | PostgreSQL | OpenBao | Status     |
|---------|------------|------------|---------|------------|
| 2.2.0   | 1.24+      | 13+        | 2.4+    | ✅ Current |

## Related Documentation

- [Prerequisites](../03-deployment/prerequisites.md)
- [Helm Installation](../03-deployment/helm-install.md)
- [Upgrades and Rollback](../03-deployment/upgrades-and-rollback.md)

