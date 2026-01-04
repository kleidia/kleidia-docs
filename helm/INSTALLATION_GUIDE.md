# Kleidia Installation Guide

## Overview

This guide provides comprehensive instructions for installing Kleidia, an Enterprise YubiKey Management Platform, using Helm charts on Kubernetes.

## Prerequisites

### System Requirements
- **Kubernetes cluster**: Version 1.20+ with 4+ nodes
- **Memory**: 8GB+ RAM available across cluster
- **Storage**: 20GB+ available storage
- **CPU**: 4+ cores available across cluster
- **Helm**: Version 3.8+ installed

### Required Tools
- `kubectl` - Kubernetes command-line tool
- `helm` - Helm package manager
- `curl` - For health checks and testing

### Cluster Requirements
- Storage class: `local-path` (or configure custom storage class)
- Network policies: Not required (can be enabled optionally)
- RBAC: Enabled (required for Vault and security features)

## Installation Options

> **Note**: For air-gapped or disconnected environments, see the [Air-Gapped Deployment Guide](AIRGAP_DEPLOYMENT.md) before proceeding.

### Option 1: Standard Installation (Recommended)

**Best for**: Most deployments, single-node clusters, development environments

```bash
# Navigate to helm directory
cd helm

# Run enhanced installation script
./install-enhanced.sh
```

**What it does**:
- Uses 30-minute timeout for complex multi-component deployment
- Installs all components in single operation
- Includes comprehensive error handling and recovery
- Provides detailed progress logging

**Expected time**: 10-15 minutes
**Success rate**: ~95%

### Option 2: Staged Installation (For Large Clusters)

**Best for**: Large clusters, production environments, resource-constrained environments

```bash
# Navigate to helm directory
cd helm

# Run staged installation script
./install-staged.sh
```

**What it does**:
- **Stage 1**: Installs dependencies (Vault, PostgreSQL, RabbitMQ) - 20 minutes
- **Stage 2**: Installs application components (Backend, Frontend) - 15 minutes
- Provides better resource management
- Allows troubleshooting between stages

**Expected time**: 20-35 minutes total
**Success rate**: ~98%

### Option 3: Manual Installation

**Best for**: Custom configurations, debugging, advanced users

```bash
# Navigate to helm directory
cd helm

# Clean up any existing installation
helm uninstall kleidia -n kleidia 2>/dev/null || true
kubectl delete namespace kleidia 2>/dev/null || true

# Install with custom configuration
helm install kleidia ./kleidia \
  --namespace kleidia \
  --create-namespace \
  --timeout 30m \
  --wait \
  --atomic \
  --debug
```

## Configuration Options

### Basic Configuration

```yaml
# values.yaml
global:
  domain: "kleidia.mooo.com"
  namespace: "kleidia"
  storage:
    class: "local-path"
    size: "2Gi"

components:
  backend:
    enabled: true
    replicas: 2
  frontend:
    enabled: true
    replicas: 2
  postgresql:
    enabled: true
  rabbitmq:
    enabled: true
  vault:
    enabled: true
```

### Advanced Configuration

```yaml
# Custom storage configuration
global:
  storage:
    class: "fast-ssd"
    size: "10Gi"
    createVolumes: true

# Resource limits
components:
  backend:
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

# Security configuration
global:
  security:
    podSecurityStandards: "restricted"
    networkPolicies:
      enabled: true
      defaultDenyAll: true
```

### CORS Configuration (Required for Production)

When deploying with an external load balancer, you **must** configure CORS origins so the frontend can communicate with the backend. See [CORS Configuration Guide](CORS-CONFIGURATION.md) for detailed instructions.

**Quick configuration:**

```bash
# During installation
helm install kleidia-services ./kleidia-services \
  -n kleidia \
  --set backend.corsOrigins="https://kleidia.example.com"

# Or in values.yaml
backend:
  corsOrigins: "https://kleidia.example.com,https://kleidia-prod.mycorp.com"
```

**Important**: Replace `kleidia.example.com` with your actual DNS name(s).

## Installation Process

### Phase 1: Pre-Installation Validation
- ✅ Cluster resource check
- ✅ Storage class verification
- ✅ Namespace creation/validation
- ✅ Conflict detection

### Phase 2: Dependencies Installation
- ✅ Vault deployment and initialization
- ✅ PostgreSQL cluster setup
- ✅ RabbitMQ deployment
- ✅ Storage provisioning

### Phase 3: Application Deployment
- ✅ Backend service deployment
- ✅ Frontend service deployment
- ✅ Service mesh configuration
- ✅ Ingress setup (if enabled)

### Phase 4: Configuration and Initialization
- ✅ Database initialization and seeding
- ✅ Vault PKI configuration
- ✅ Secret generation and management
- ✅ Service connectivity verification

### Phase 5: Post-Installation Verification
- ✅ Pod health checks
- ✅ Service connectivity tests
- ✅ Component integration verification
- ✅ Final status validation

## Monitoring Installation Progress

### Real-Time Status Monitoring

```bash
# Watch pod status
kubectl get pods -n kleidia -w

# Check service status
kubectl get services -n kleidia

# Monitor installation logs
kubectl logs -f job/kleidia-vault-configure -n kleidia
```

### Installation Status Dashboard

Access the installation status dashboard:
```bash
# Port forward to status service
kubectl port-forward svc/kleidia-install-monitor 8080:8080 -n kleidia

# Open browser to http://localhost:8080
```

## Troubleshooting

### Common Issues

#### 1. Installation Timeout
**Symptoms**: Installation fails with timeout error
**Solutions**:
- Use staged installation: `./install-staged.sh`
- Increase timeout: `--timeout 45m`
- Check cluster resources: `kubectl top nodes`

#### 2. Storage Issues
**Symptoms**: Pods stuck in Pending state
**Solutions**:
- Check storage class: `kubectl get storageclass`
- Verify storage capacity: `kubectl get pv`
- Update storage class in values.yaml

#### 3. Vault Configuration Failure
**Symptoms**: Vault hook fails, secrets not generated
**Solutions**:
- Check Vault logs: `kubectl logs job/kleidia-vault-configure -n kleidia`
- Verify Vault pod: `kubectl get pods -l app.kubernetes.io/name=vault -n kleidia`
- Check fallback secrets: `kubectl get configmap kleidia-backend-config -n kleidia -o yaml`

#### 4. Database Connection Issues
**Symptoms**: Backend pods crash with database errors
**Solutions**:
- Check PostgreSQL status: `kubectl get pods -l app.kubernetes.io/name=postgres -n kleidia`
- Verify secrets: `kubectl get secret kleidia-postgres-secret -n kleidia`
- Check database logs: `kubectl logs -l app.kubernetes.io/name=postgres -n kleidia`

### Debugging Commands

```bash
# Check all resources
kubectl get all -n kleidia

# Check events
kubectl get events -n kleidia --sort-by='.metadata.creationTimestamp'

# Check pod logs
kubectl logs -l app.kubernetes.io/name=kleidia -n kleidia

# Check hook job status
kubectl get jobs -n kleidia

# Check persistent volumes
kubectl get pv,pvc -n kleidia
```

## Post-Installation

### Verification Checklist

- [ ] All pods are running: `kubectl get pods -n kleidia`
- [ ] Services are accessible: `kubectl get services -n kleidia`
- [ ] Backend health check: `curl http://kleidia-backend-service:8000/health`
- [ ] Frontend accessible: `curl http://kleidia-frontend-service:3000/`
- [ ] Vault accessible: `curl http://kleidia-vault:8200/v1/sys/health`
- [ ] Database connectivity: Check backend logs for connection success

### Accessing the Application

#### Internal Access
- **Backend API**: `http://kleidia-backend-service:8000`
- **Frontend**: `http://kleidia-frontend-service:3000`
- **Vault UI**: `http://kleidia-vault:8200`

#### External Access (with HAProxy)
- **Application**: `https://kleidia.mooo.com`
- **Vault**: `https://kleidia.mooo.com:30820`
- **RabbitMQ AMQPS** (for external agents): Port `5671` (requires HAProxy configuration)

> **Note**: For external agent connections to RabbitMQ, you must configure HAProxy to forward port 5671 to the Kubernetes NodePort. See [HAPROXY_RABBITMQ_SETUP.md](HAPROXY_RABBITMQ_SETUP.md) for detailed instructions.

### Default Credentials
- **Admin User**: `admin`
- **Admin Password**: `admin1234`
- **Vault Root Token**: Check `kleidia-vault-keys` secret

## Upgrading

### Standard Upgrade
```bash
helm upgrade kleidia ./kleidia \
  --namespace kleidia \
  --timeout 30m \
  --wait
```

### Rolling Upgrade
```bash
helm upgrade kleidia ./kleidia \
  --namespace kleidia \
  --timeout 30m \
  --wait \
  --atomic
```

## Uninstalling

### Complete Removal
```bash
# Uninstall Helm release
helm uninstall kleidia -n kleidia

# Remove namespace (includes all resources)
kubectl delete namespace kleidia

# Clean up persistent volumes (optional)
kubectl delete pv $(kubectl get pv -o jsonpath='{.items[?(@.spec.claimRef.namespace=="kleidia")].metadata.name}')
```

### Partial Cleanup
```bash
# Keep data, remove application
helm uninstall kleidia -n kleidia

# Remove specific components
kubectl delete deployment kleidia-backend -n kleidia
kubectl delete deployment kleidia-frontend -n kleidia
```

## Support

### Getting Help
- Check installation logs: `kubectl logs -l app.kubernetes.io/name=kleidia -n kleidia`
- Review hook job logs: `kubectl logs job/kleidia-vault-configure -n kleidia`
- Check cluster events: `kubectl get events -n kleidia`

### Performance Optimization
- **Resource tuning**: Adjust CPU/memory limits in values.yaml
- **Storage optimization**: Use faster storage classes for production
- **Network optimization**: Enable network policies for security
- **Monitoring**: Enable Prometheus/Grafana for production monitoring

## Security Considerations

### Production Deployment
- Change default passwords
- Enable network policies
- Use TLS certificates
- Configure proper RBAC
- Enable audit logging
- Regular security updates

### Backup Strategy
- Database backups: Regular PostgreSQL dumps
- Vault backups: Regular Vault snapshots
- Configuration backups: Helm values and secrets
- Certificate backups: Store certificates securely

---

**Installation completed successfully!** 🎉

For additional support or advanced configuration options, refer to the project documentation or contact the YubiMgr team.
