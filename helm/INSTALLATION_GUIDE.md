# Kleidia Installation Guide

## Overview

This guide provides instructions for installing Kleidia using Helm charts on Kubernetes. Kleidia uses a 3-chart architecture deployed in sequence.

## Prerequisites

### System Requirements

| | Minimum | Recommended |
|---|---|---|
| **Kubernetes** | 1.24+ | 1.32+ (for CNPG with TLS) |
| **Nodes** | 1 | 2+ (for HA) |
| **CPU** | 2 cores | 4 cores |
| **RAM** | 2 GB | 4 GB |
| **Storage** | 15 GB | 30 GB |
| **Helm** | 3.8+ | 3.8+ |

### Required Tools
- `kubectl` - Kubernetes command-line tool
- `helm` - Helm package manager
- `curl` - For health checks and testing

### Cluster Requirements
- StorageClass available (e.g., `local-path`, `nfs-client`, or cloud provider)
- RBAC enabled
- Network policies: optional but recommended

> **Note**: The platform chart automatically installs **cert-manager v1.17.1** and **CloudNativePG operator v1.28.1** if they are not already present in your cluster.

## Installation

### Option 1: OCI registry (recommended)

Install the three charts directly from the **public OCI registry** — no clone, no scripts. See the **[Helm Installation Guide](../03-deployment/helm-install.md)** for the full copy-paste sequence (platform → data → services, with readiness gates and single-node notes).

| Chart | OCI reference | Version |
|---|---|---|
| `kleidia-platform` | `oci://registry-1.docker.io/therinn/kleidia-platform` | `2.2.2` |
| `kleidia-data` | `oci://registry-1.docker.io/therinn/kleidia-data` | `2.2.2` |
| `kleidia-services` | `oci://registry-1.docker.io/therinn/kleidia-services` | `2.2.2` |

### Option 2: From a local chart checkout

The charts are also bundled in the public docs repo. Clone it and install from local paths:

```bash
git clone https://github.com/kleidia/kleidia-docs.git
cd kleidia-docs/helm
```

#### Step 1: Install Platform (OpenBao, cert-manager, CNPG operator)

```bash
helm install kleidia-platform ./kleidia-platform \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set storage.className=local-path \
  --timeout 30m \
  --wait
```

Wait for OpenBao to be ready (5-10 minutes).

#### Step 2: Install Data Layer (PostgreSQL)

```bash
helm install kleidia-data ./kleidia-data \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set storage.className=local-path \
  --timeout 30m \
  --wait
```

Wait for PostgreSQL to be ready (2-3 minutes).

#### Step 3: Install Services (Backend, Frontend, License)

```bash
helm install kleidia-services ./kleidia-services \
  --namespace kleidia \
  --set global.domain=kleidia.example.com \
  --set global.namespace=kleidia \
  --set global.siteUrl=https://kleidia.example.com \
  --timeout 30m \
  --wait
```

> **Important**: Set `global.siteUrl` to your public-facing URL. This configures CORS origins for the bootstrap flow and OIDC redirect URIs.

Wait for all pods to be ready (2-3 minutes).

## Configuration

### CORS Configuration (Required)

CORS must be configured correctly for the admin bootstrap flow to work. The `global.siteUrl` value is used by default. To override:

```bash
--set backend.corsOrigins="https://kleidia.example.com"
```

See [CORS Configuration Guide](/docs/helm/cors-configuration/) for details.

### Storage Configuration

Use `--set storage.className=<your-class>` consistently across all three charts. The storage class must match.

See the main documentation for storage options (NFS, Longhorn, cloud providers).

## Verification

```bash
# Check all pods are running
kubectl get pods -n kleidia

# Check services and NodePorts
kubectl get svc -n kleidia

# Test backend health
BACKEND_POD=$(kubectl get pods -n kleidia -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kleidia $BACKEND_POD -- wget -q -O- http://localhost:8080/health
```

## NodePort Configuration

Configure your external load balancer to route:

| Route | NodePort | Target |
|-------|----------|--------|
| `/api/*` | 32570 | Backend |
| `/*` | 30805 | Frontend |

## Post-Installation

1. Open `https://kleidia.example.com` in your browser
2. Create the initial admin account (bootstrap screen)
3. Save the OpenBao keys when the modal appears (non-dismissible, one-time only)
4. Configure organization settings

## Upgrading

Upgrade charts in the same order (platform, data, services):

```bash
helm upgrade kleidia-platform ./kleidia-platform --namespace kleidia
helm upgrade kleidia-data ./kleidia-data --namespace kleidia
helm upgrade kleidia-services ./kleidia-services --namespace kleidia
```

## Uninstalling

Uninstall in **reverse** order:

```bash
helm uninstall kleidia-services -n kleidia
helm uninstall kleidia-data -n kleidia
helm uninstall kleidia-platform -n kleidia
kubectl delete namespace kleidia
```
