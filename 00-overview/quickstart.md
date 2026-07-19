# Quickstart

**Audience**: Operations Administrators  
**Prerequisites**: A Kubernetes cluster (1.32+ recommended), Helm 3.8+, `kubectl`, a StorageClass, and a domain with DNS + a load balancer for TLS  
**Outcome**: Kleidia deployed, your admin account created, and you're logged into the dashboard — in about 15 minutes

This is the fast path. It gets a working Kleidia in front of you with the fewest possible steps. For values customization, air-gapped images, storage options, and production hardening, follow the links at the end — but you don't need any of that to get started.

## 1. Deploy the three charts

Kleidia ships **three Helm charts installed in order — platform → data → services**, published publicly to Docker Hub (no authentication needed). Each step waits on a real readiness signal before the next.

```bash
DOMAIN=kleidia.example.com   # your public domain
SC=local-path                # your StorageClass (e.g. local-path, longhorn, gp2)

# 1/3 — Platform (OpenBao + cert-manager/CNPG bootstrap)
helm install kleidia-platform oci://registry-1.docker.io/therinn/kleidia-platform --version 2.3.0 \
  --namespace kleidia --create-namespace \
  --set global.domain=$DOMAIN --set global.namespace=kleidia \
  --set storage.className=$SC \
  --set openbao.server.dataStorage.storageClass=$SC \
  --set openbao.server.auditStorage.storageClass=$SC
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openbao -n kleidia --timeout=600s

# 2/3 — Data (PostgreSQL via CloudNativePG on K8s 1.32+)
helm install kleidia-data oci://registry-1.docker.io/therinn/kleidia-data --version 2.3.0 \
  --namespace kleidia \
  --set global.domain=$DOMAIN --set global.namespace=kleidia \
  --set storage.className=$SC
kubectl wait --for=condition=Ready cluster/kleidia-db -n kleidia --timeout=300s

# 3/3 — Services (backend, frontend, license)
helm install kleidia-services oci://registry-1.docker.io/therinn/kleidia-services --version 2.3.0 \
  --namespace kleidia \
  --set global.domain=$DOMAIN --set global.namespace=kleidia \
  --set global.siteUrl=https://$DOMAIN
```

> **Single-node clusters:** add `--set backend.replicas=1 --set frontend.replicas=1 --set licenseService.replicas=1` to the services install so the extra replicas don't sit `Pending` for lack of CPU.

> **`global.siteUrl`** must be your public-facing URL — it configures the CORS origins the admin bootstrap flow needs. If omitted it defaults to `https://<global.domain>`.

## 2. Confirm everything is up

```bash
kubectl get pods -n kleidia
```

All pods should be `Running`: `kleidia-platform-openbao-0`, `kleidia-db-1`, and the `backend` / `frontend` / `license` pods.

Point your external load balancer at the NodePorts (`/api/*` → `32570` backend, `/*` → `30805` frontend) so `https://$DOMAIN` resolves. See [Load Balancer Setup](../03-deployment/load-balancer-setup.md) if you haven't done this yet.

## 3. Create your admin account

1. Open **`https://<your-domain>`** in a browser. On a fresh install you'll land on the **bootstrap screen**.
2. Enter a username (default `admin`) and a password (8+ characters), then **Create Admin**. You're logged in automatically.
3. **A one-time modal shows your OpenBao initialization keys.** It is non-dismissible and the keys are shown **only once** — store them in a secure secrets manager before confirming. They are the master recovery credentials for your install; losing them can mean losing access to all stored secrets.

That's it — you're on the dashboard with a working Kleidia.

## Next steps

- **Enrol your first YubiKey** — install the agent on a workstation, then register a device: [Agent Installation](../05-using-the-system/agent-installation.md) → [Admin Guide: Device Management](../05-using-the-system/admin-guide.md)
- **Harden for production** — TLS, storage, and load balancer specifics: [Storage](../03-deployment/storage-configuration.md), [Load Balancer](../03-deployment/load-balancer-setup.md), [Security Overview](../02-security/security-overview.md)
- **Full deployment reference** — values files, air-gapped installs, source-checkout method, upgrades: [Helm Installation](../03-deployment/helm-install.md), [Configuration](../03-deployment/configuration.md)
