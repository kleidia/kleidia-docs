# Atlassian Bamboo Deployment Guide

## Overview

Atlassian Bamboo uses build plans configured through the web UI or YAML configuration files. Plans consist of stages, jobs, and tasks, enabling automated deployment of Kleidia.

This guide covers deploying Kleidia using Bamboo build plans, including environment-specific deployments, secrets management, rollback procedures, and best practices.

For general CI/CD concepts and prerequisites, see [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md).

## Prerequisites

- **Bamboo Server**: Bamboo server accessible and configured
- **Bamboo Agent**: Bamboo agent configured with kubectl and Helm installed
- **Kubernetes Access**: Bamboo agent must have network access to Kubernetes cluster
- **Variables Configured**: Required plan variables configured in Bamboo

## Required Variables

Configure the following variables in your Bamboo plan:

**Plan configuration → Variables**

**Core Configuration:**
- `kubeconfig`: Kubernetes kubeconfig file content (Base64-encoded)
- `domain`: Domain name for Kleidia deployment
- `registry.host`: Customer container registry host

**Deployment-Specific:**
- `namespace`: Kubernetes namespace (default: `kleidia`)
- `deployment.type`: `standalone` or `existing-cluster`

**Database Configuration (for existing cluster with external PostgreSQL):**
- `database.host`: PostgreSQL host
- `database.port`: PostgreSQL port (default: `5432`)
- `database.name`: Database name
- `database.username`: Database username
- `database.password`: Database password (marked as password type)

**Vault Configuration (for external Vault):**
- `vault.address`: External Vault address
- `vault.role.id`: Vault AppRole role ID
- `vault.secret.id`: Vault AppRole secret ID (marked as password type)
- `vault.path`: Vault KV v2 mount path (default: `yubikeys`)

**Storage Configuration (for existing cluster with internal components):**
- `storage.class.vault`: Storage class for Vault PVC
- `storage.class.postgres`: Storage class for PostgreSQL PVC

**Image Configuration:**
- `backend.image.tag`: Backend image tag
- `frontend.image.tag`: Frontend image tag

For complete list of required variables, see [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md#required-secrets-and-variables).

## Basic Plan Structure

**Standalone Server Deployment Plan:**

Create a new plan in Bamboo UI or use `bamboo.yml`:

```yaml
# bamboo.yml or configured via Bamboo UI
plan:
  name: Deploy Kleidia
  stages:
    - Deploy
  jobs:
    - Deploy Job
      tasks:
        - checkout
        - script:
            - |
              helm upgrade --install kleidia ./helm/kleidia \
                --namespace kleidia \
                --create-namespace \
                --set global.domain=${bamboo.domain} \
                --set global.namespace=kleidia \
                --set global.registry.host=${bamboo.registry.host} \
                --set global.deployment.type=standalone \
                --set vault.type=internal \
                --wait \
                --timeout 10m
```

## Script-Based Deployment

**Bash Script for Bamboo Script Task:**

Create `scripts/deploy-bamboo.sh`:

```bash
#!/bin/bash
set -e

NAMESPACE="${bamboo.namespace:-kleidia}"
DOMAIN="${bamboo.domain}"
REGISTRY_HOST="${bamboo.registry.host}"
DEPLOYMENT_TYPE="${bamboo.deployment.type:-existing-cluster}"
VAULT_TYPE="${bamboo.vault.type:-internal}"

# Setup kubectl context
if [ -n "${bamboo.kubeconfig}" ]; then
  echo "${bamboo.kubeconfig}" | base64 -d > kubeconfig
  export KUBECONFIG=$(pwd)/kubeconfig
fi

# Create namespace
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Build Helm command
HELM_CMD="helm upgrade --install kleidia ./helm/kleidia \
  --namespace ${NAMESPACE} \
  --set global.domain=${DOMAIN} \
  --set global.namespace=${NAMESPACE} \
  --set global.registry.host=${REGISTRY_HOST} \
  --set global.deployment.type=${DEPLOYMENT_TYPE} \
  --wait \
  --timeout 10m"

# Add Vault configuration
if [ "${VAULT_TYPE}" = "internal" ]; then
  HELM_CMD="${HELM_CMD} --set vault.type=internal"
  if [ -n "${bamboo.storage.class.vault}" ]; then
    HELM_CMD="${HELM_CMD} --set storage.vault.storageClassName=${bamboo.storage.class.vault} --set storage.vault.size=20Gi"
  fi
else
  HELM_CMD="${HELM_CMD} --set vault.type=external \
    --set vault.address=${bamboo.vault.address} \
    --set vault.appRole.roleId=${bamboo.vault.role.id} \
    --set vault.appRole.secretIdSecret=vault-approle-secret \
    --set vault.path=${bamboo.vault.path:-yubikeys}"
  
  # Create Vault AppRole secret
  kubectl create secret generic vault-approle-secret \
    --from-literal=secret-id="${bamboo.vault.secret.id}" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Add database configuration if external
if [ -n "${bamboo.database.host}" ]; then
  HELM_CMD="${HELM_CMD} --set database.type=external \
    --set database.host=${bamboo.database.host} \
    --set database.port=${bamboo.database.port:-5432} \
    --set database.name=${bamboo.database.name} \
    --set database.username=${bamboo.database.username} \
    --set database.passwordSecret=postgres-credentials"
  
  # Create database password secret
  kubectl create secret generic postgres-credentials \
    --from-literal=password="${bamboo.database.password}" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Execute Helm deployment
eval "${HELM_CMD}"

# Verify deployment
kubectl wait --for=condition=ready pod -l app=backend -n "${NAMESPACE}" --timeout=300s
kubectl wait --for=condition=ready pod -l app=frontend -n "${NAMESPACE}" --timeout=300s

echo "Deployment completed successfully"
```

**Bamboo Plan Configuration:**

1. Create a new plan in Bamboo
2. Add Source Code Checkout task
3. Add Script task pointing to `scripts/deploy-bamboo.sh`
4. Configure plan variables
5. Set build triggers (manual, scheduled, or on commit)

## Standalone Server Deployment

**Plan Configuration:**

- Plan Name: `Deploy Kleidia (Standalone)`
- Variables:
  - `domain`: Domain name
  - `registry.host`: Container registry host
- Script: Use deploy script with `deployment.type=standalone`

## Existing Cluster Deployment

### External PostgreSQL and Internal Vault

**Plan Variables:**
- `database.host`: PostgreSQL host
- `database.port`: PostgreSQL port
- `database.name`: Database name
- `database.username`: Database username
- `database.password`: Database password (password type)

**Script Configuration:**
The deploy script automatically detects external database configuration and creates necessary secrets.

### External Vault Configuration

**Plan Variables:**
- `vault.address`: External Vault address
- `vault.role.id`: Vault AppRole role ID
- `vault.secret.id`: Vault AppRole secret ID (password type)
- `vault.path`: Vault KV v2 mount path

**Script Configuration:**
The deploy script automatically handles external Vault configuration when `vault.type=external`.

## Multi-Environment Deployment

**Separate Plans per Environment:**

1. **Development Plan**: Auto-deploy on commit to `develop` branch
2. **Staging Plan**: Deploy on commit to `staging` branch or manual trigger
3. **Production Plan**: Deploy on tag or manual trigger with approval

**Plan Configuration Variables:**

- `domain`: Environment-specific domain
- `namespace`: Environment-specific namespace (e.g., `kleidia-dev`, `kleidia-staging`, `kleidia-prod`)
- `deployment.type`: Deployment type (`standalone` or `existing-cluster`)
- `vault.type`: Vault type (`internal` or `external`)

**Branch-Based Deployment:**

Configure plan triggers:
- **Development Plan**: Trigger on commit to `develop` branch
- **Staging Plan**: Trigger on commit to `staging` branch or manual
- **Production Plan**: Trigger on tag creation or manual (requires approval)

## Rollback Support

**Rollback Script for Bamboo:**

Create `scripts/rollback-bamboo.sh`:

```bash
#!/bin/bash
set -e

NAMESPACE="${bamboo.namespace:-kleidia}"
REVISION="${bamboo.rollback.revision}"

# Setup kubectl context
if [ -n "${bamboo.kubeconfig}" ]; then
  echo "${bamboo.kubeconfig}" | base64 -d > kubeconfig
  export KUBECONFIG=$(pwd)/kubeconfig
fi

# Rollback to specific revision or previous
if [ -z "${REVISION}" ]; then
  REVISION=$(helm history kleidia -n "${NAMESPACE}" --output json | jq -r '.[1].revision // "0"')
fi

helm rollback kleidia "${REVISION}" -n "${NAMESPACE}"

echo "Rolled back to revision ${REVISION}"
```

**Rollback Plan Configuration:**

1. Create separate rollback plan or add rollback job
2. Add Script task pointing to `scripts/rollback-bamboo.sh`
3. Configure variable `rollback.revision` (optional, defaults to previous revision)
4. Set as manual trigger

**Automated Rollback on Failure:**

Add to deploy script:

```bash
# Capture current revision before deployment
CURRENT_REVISION=$(helm history kleidia -n "${NAMESPACE}" --output json | jq -r '.[0].revision // "0"')

# Attempt deployment
if ! eval "${HELM_CMD}"; then
  # Rollback on failure
  helm rollback kleidia "${CURRENT_REVISION}" -n "${NAMESPACE}"
  exit 1
fi
```

## Image Tagging

**Dynamic Image Tagging:**

Add to deploy script:

```bash
# Determine image tag
if [ -n "${bamboo.backend.image.tag}" ]; then
  IMAGE_TAG="${bamboo.backend.image.tag}"
else
  IMAGE_TAG="${bamboo.buildResultKey}"
fi

# Add image tags to Helm command
HELM_CMD="${HELM_CMD} \
  --set components.backend.image.tag=${IMAGE_TAG} \
  --set components.frontend.image.tag=${IMAGE_TAG}"
```

**Git Commit SHA Tagging:**

```bash
IMAGE_TAG="$(git rev-parse --short HEAD)"

HELM_CMD="${HELM_CMD} \
  --set components.backend.image.tag=${IMAGE_TAG} \
  --set components.frontend.image.tag=${IMAGE_TAG}"
```

## Validation and Testing

**Pre-Deployment Validation:**

Add validation step to plan:

```bash
#!/bin/bash
set -e

# Lint Helm chart
helm lint ./helm/kleidia

# Dry-run deployment
helm upgrade --install kleidia ./helm/kleidia \
  --namespace "${NAMESPACE}" \
  --dry-run \
  --debug
```

**Post-Deployment Verification:**

Add to deploy script:

```bash
# Verify deployment
kubectl wait --for=condition=ready pod -l app=backend -n "${NAMESPACE}" --timeout=300s
kubectl wait --for=condition=ready pod -l app=frontend -n "${NAMESPACE}" --timeout=300s

# Test health endpoint
curl -f https://${DOMAIN}/api/health || exit 1
```

## Secrets Management

### Configuring Variables

1. Navigate to plan **Configuration → Variables**
2. Click **Add Variable**
3. Enter variable key and value
4. Mark sensitive variables as **Password** type
5. Click **Save**

### Using Variables

Access variables in scripts using `${bamboo.variable.name}`:

```bash
DOMAIN="${bamboo.domain}"
REGISTRY_HOST="${bamboo.registry.host}"
```

### Environment-Specific Variables

Use Bamboo deployment environments or separate plans:

1. Create deployment environments in Bamboo
2. Configure environment-specific variables
3. Use environment in plan configuration

### Best Practices

- **Never commit secrets**: Never store secrets in scripts or repository
- **Use Password type**: Mark sensitive variables as Password type
- **Rotate secrets regularly**: Implement secret rotation policies
- **Use minimal permissions**: Grant only necessary permissions to Bamboo agents
- **Audit access**: Monitor variable access in Bamboo audit logs
- **Separate environments**: Use separate plans or environments for different deployment targets

## Troubleshooting

### Common Issues

**Plan Not Triggering:**
- Check plan triggers are configured correctly
- Verify repository connection is working
- Check branch/tag conditions match

**Bamboo Agent Issues:**
- Verify agent is online and available
- Check agent capabilities match plan requirements
- Verify agent has kubectl and Helm installed

**Kubernetes Connection Issues:**
- Verify `kubeconfig` variable is correctly Base64-encoded
- Check network connectivity from Bamboo agent to Kubernetes cluster
- Verify cluster access permissions

**Script Execution Failures:**
- Check script file permissions (executable)
- Verify script path is correct
- Review Bamboo build logs for detailed error messages

**Variable Not Found:**
- Verify variable name matches exactly (case-sensitive)
- Check variable is configured in plan configuration
- Ensure variable scope (plan vs. global) is correct

### Debug Plan

Add debugging task:

```bash
#!/bin/bash
echo "Plan: ${bamboo.planName}"
echo "Build: ${bamboo.buildNumber}"
echo "Repository: ${bamboo.repositoryName}"
kubectl version --client
helm version
env | grep -E "(bamboo|NAMESPACE|DOMAIN)" || true
```

## Best Practices

1. **Reusable Scripts**: Create reusable deployment scripts in repository
2. **Plan Templates**: Use Bamboo plan templates for consistency
3. **Environment Separation**: Use separate plans or environments for dev/staging/production
4. **Notification Rules**: Configure notification rules for build status
5. **Artifact Management**: Save deployment artifacts for debugging
6. **Audit Logging**: Enable audit logging for all deployments
7. **Version Control**: Store deployment scripts in version control

## Related Documentation

- [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md) - General CI/CD concepts and prerequisites
- [Helm Deployment Guide](HELM_DEPLOYMENT.md) - Manual Helm chart deployment
- [Prerequisites](PREREQUISITES.md) - Prerequisites and requirements

## Support

For Bamboo deployment issues:

- Review troubleshooting section above
- Check Bamboo build logs
- Review Helm deployment status: `helm status kleidia -n <namespace>`
- Contact your account representative for support

