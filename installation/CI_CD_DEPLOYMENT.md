# Kleidia CI/CD Pipeline Deployment Guide

## Overview

This guide covers automated deployment of Kleidia using CI/CD pipelines. CI/CD deployment enables automated, repeatable deployments with version control, automated testing, and environment promotion capabilities.

Kleidia supports CI/CD deployment through push-based pipelines that execute Helm commands, integrating with existing Helm chart deployment patterns. This guide covers three popular CI/CD platforms:

- **[GitHub Actions](GITHUB_ACTIONS_DEPLOYMENT.md)**: Automated workflows for GitHub-hosted repositories
- **[GitLab CI](GITLAB_CI_DEPLOYMENT.md)**: Integrated CI/CD pipelines for GitLab repositories
- **[Atlassian Bamboo](BAMBOO_DEPLOYMENT.md)**: Build and deployment automation for enterprise environments

## CI/CD Deployment vs Manual Deployment

### Benefits of CI/CD Deployment

- **Automated Deployments**: No manual intervention required for standard deployments
- **Version Control**: All deployment configurations tracked in version control
- **Environment Promotion**: Automated promotion from dev → staging → production
- **Rollback Capabilities**: Quick rollback to previous versions
- **Audit Trail**: Complete history of deployments with commit tracking
- **Consistency**: Same deployment process across all environments
- **Security**: Centralized secrets management through CI/CD platform

### When to Use CI/CD Deployment

- **Multiple Environments**: Managing dev, staging, and production deployments
- **Frequent Deployments**: Regular application updates and deployments
- **Team Collaboration**: Multiple team members deploying to shared environments
- **Compliance Requirements**: Need for automated audit trails and deployment approvals
- **GitOps Workflows**: Integration with GitOps tools and processes

## Prerequisites

### CI/CD Platform Prerequisites

Before setting up CI/CD deployment, ensure:

- **CI/CD Platform Access**: Admin access to GitHub Actions, GitLab CI, or Bamboo
- **Kubernetes Cluster Access**: CI/CD runner must have network access to Kubernetes cluster
- **kubectl and Helm**: Installed on CI/CD runners or available as containers
- **Container Registry Access**: CI/CD runner can access customer container registry/Artifactory
- **Secrets Management**: CI/CD platform secrets/variables configured for sensitive data

### Required Secrets and Variables

Configure the following secrets/variables in your CI/CD platform. See platform-specific guides for detailed setup instructions:

**Core Configuration:**
- `KUBECONFIG` or Kubernetes cluster credentials (kubeconfig file content)
- `HELM_REGISTRY_HOST`: Customer container registry host
- `HELM_REGISTRY_USERNAME`: Registry username (if authentication required)
- `HELM_REGISTRY_PASSWORD`: Registry password (if authentication required)
- `DOMAIN`: Domain name for Kleidia deployment

**Deployment-Specific:**
- `NAMESPACE`: Kubernetes namespace (default: `kleidia`)
- `DEPLOYMENT_TYPE`: `standalone` or `existing-cluster`

**Database Configuration (for existing cluster with external PostgreSQL):**
- `DB_HOST`: PostgreSQL host
- `DB_PORT`: PostgreSQL port (default: `5432`)
- `DB_NAME`: Database name
- `DB_USERNAME`: Database username
- `DB_PASSWORD`: Database password (store as secret)
- `DB_PASSWORD_SECRET`: Kubernetes secret name for database password

**Vault Configuration (for external Vault):**
- `VAULT_ADDRESS`: External Vault address (e.g., `https://vault.example.com:8200`)
- `VAULT_ROLE_ID`: Vault AppRole role ID
- `VAULT_SECRET_ID`: Vault AppRole secret ID (store as secret)
- `VAULT_PATH`: Vault KV v2 mount path (default: `yubikeys`)
- `VAULT_TLS_SKIP_VERIFY`: Skip TLS verification (default: `false`)

**Storage Configuration (for existing cluster with internal components):**
- `STORAGE_CLASS_POSTGRES`: Storage class for PostgreSQL PVC
- `STORAGE_CLASS_VAULT`: Storage class for Vault PVC
- `PVC_SIZE_POSTGRES`: PostgreSQL PVC size (default: `50Gi`)
- `PVC_SIZE_VAULT`: Vault PVC size (default: `20Gi`)

**Image Configuration:**
- `BACKEND_IMAGE_TAG`: Backend image tag (e.g., `latest`, `v1.0.0`)
- `FRONTEND_IMAGE_TAG`: Frontend image tag (e.g., `latest`, `v1.0.0`)

**Certificate Configuration:**
- `CERTIFICATE_TYPE`: `provided`, `letsencrypt`, or `cert-manager`
- `CERTIFICATE_SECRET_NAME`: Kubernetes secret name for certificates (if using `provided`)

### Helm Chart Location

Ensure the Helm chart is available in your repository or CI/CD accessible location:

- **Option 1**: Helm chart in same repository (recommended)
- **Option 2**: Helm chart in separate repository (clone in CI/CD pipeline)
- **Option 3**: Helm chart in artifact repository (download in CI/CD pipeline)

## Deployment Patterns

### Pattern 1: Push-Based Deployment

CI/CD pipeline directly executes Helm install/upgrade commands. This is the most common pattern for Kleidia deployments.

**Workflow:**
1. CI/CD pipeline triggered (on commit, tag, or manual trigger)
2. Pipeline validates configuration
3. Pipeline executes `helm install` or `helm upgrade`
4. Pipeline verifies deployment
5. Pipeline reports deployment status

**Use Cases:**
- Standard application deployments
- Environment promotion (dev → staging → production)
- Hotfix deployments
- Rollback deployments

### Pattern 2: Environment-Specific Pipelines

Separate CI/CD pipelines or stages for different environments.

**Structure:**
- **Development**: Auto-deploy on merge to `develop` branch
- **Staging**: Deploy on merge to `staging` branch or manual trigger
- **Production**: Deploy on tag creation or manual approval

**Benefits:**
- Clear separation of environments
- Different approval workflows per environment
- Environment-specific configurations

## Secrets Management

### Best Practices

1. **Never Commit Secrets**: Never store secrets in version control
2. **Use CI/CD Secrets**: Use platform-specific secrets management (GitHub Secrets, GitLab Variables, Bamboo Variables)
3. **Rotate Secrets Regularly**: Implement secret rotation policies
4. **Least Privilege**: Grant only necessary permissions to CI/CD runners
5. **Audit Access**: Monitor and audit access to secrets

### Platform-Specific Secrets

Each CI/CD platform has its own secrets management system:

- **GitHub Actions**: See [GitHub Actions Deployment](GITHUB_ACTIONS_DEPLOYMENT.md#secrets-management) for configuration details
- **GitLab CI**: See [GitLab CI Deployment](GITLAB_CI_DEPLOYMENT.md#secrets-management) for configuration details
- **Bamboo**: See [Bamboo Deployment](BAMBOO_DEPLOYMENT.md#secrets-management) for configuration details

### Kubernetes Secrets

Create Kubernetes secrets before deployment:

```bash
# Database password secret
kubectl create secret generic postgres-credentials \
  --from-literal=password="${DB_PASSWORD}" \
  --namespace "${NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Vault AppRole secret
kubectl create secret generic vault-approle-secret \
  --from-literal=secret-id="${VAULT_SECRET_ID}" \
  --namespace "${NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Environment Promotion

### Promotion Strategy

**Three-Environment Model:**

1. **Development**: Auto-deploy from `develop` branch
2. **Staging**: Deploy from `staging` branch (manual or auto)
3. **Production**: Deploy from `main` branch or tags (requires approval)

**Configuration Per Environment:**

- **Namespaces**: Separate namespace per environment (`kleidia-dev`, `kleidia-staging`, `kleidia-prod`)
- **Domains**: Environment-specific domains (`kleidia-dev.example.com`, `kleidia-staging.example.com`, `kleidia.example.com`)
- **Resource Limits**: Different resource requests/limits per environment
- **Database**: Separate databases per environment (external PostgreSQL) or separate PVCs (internal PostgreSQL)

**Example Promotion Workflow:**

1. Developer merges feature to `develop` → Auto-deploy to dev environment
2. Test and validate in dev environment
3. Merge `develop` to `staging` → Deploy to staging environment
4. Perform integration tests in staging
5. Merge `staging` to `main` → Manual approval → Deploy to production

See platform-specific guides for implementation details:
- [GitHub Actions Multi-Environment](GITHUB_ACTIONS_DEPLOYMENT.md#multi-environment-deployment)
- [GitLab CI Multi-Environment](GITLAB_CI_DEPLOYMENT.md#multi-environment-deployment)
- [Bamboo Multi-Environment](BAMBOO_DEPLOYMENT.md#multi-environment-deployment)

## Rollback Strategies

### Automated Rollback

**Rollback on Deployment Failure:**

```bash
# Capture current revision before deployment
CURRENT_REVISION=$(helm history kleidia -n "${NAMESPACE}" --output json | jq -r '.[0].revision // "0"')

# Attempt deployment
if ! helm upgrade --install kleidia ./helm/kleidia ...; then
  # Rollback on failure
  helm rollback kleidia "${CURRENT_REVISION}" -n "${NAMESPACE}"
  exit 1
fi
```

### Manual Rollback

**Rollback to Previous Revision:**

```bash
# Rollback to previous revision
helm rollback kleidia -n "${NAMESPACE}"

# Rollback to specific revision
helm rollback kleidia 5 -n "${NAMESPACE}"
```

**Rollback via CI/CD:**

- **GitHub Actions**: See [GitHub Actions Rollback](GITHUB_ACTIONS_DEPLOYMENT.md#rollback-support)
- **GitLab CI**: See [GitLab CI Rollback](GITLAB_CI_DEPLOYMENT.md#rollback-support)
- **Bamboo**: See [Bamboo Rollback](BAMBOO_DEPLOYMENT.md#rollback-support)

### Rollback Verification

```bash
# Verify rollback success
kubectl wait --for=condition=ready pod -l app=backend -n "${NAMESPACE}" --timeout=300s
kubectl wait --for=condition=ready pod -l app=frontend -n "${NAMESPACE}" --timeout=300s

# Check Helm history
helm history kleidia -n "${NAMESPACE}"
```

## Image Tagging Strategy

### Tagging Patterns

1. **Semantic Versioning**: Use semantic versions (`v1.0.0`, `v1.0.1`)
2. **Git Commit SHA**: Tag images with short commit SHA (`abc1234`)
3. **Branch Names**: Tag with branch name for development (`develop-abc1234`)
4. **Environment Tags**: Tag with environment (`staging-abc1234`, `prod-v1.0.0`)

See platform-specific guides for implementation examples:
- [GitHub Actions Image Tagging](GITHUB_ACTIONS_DEPLOYMENT.md#image-tagging)
- [GitLab CI Image Tagging](GITLAB_CI_DEPLOYMENT.md#image-tagging)
- [Bamboo Image Tagging](BAMBOO_DEPLOYMENT.md#image-tagging)

## Validation and Testing

### Pre-Deployment Validation

**Validate Helm Chart:**

```bash
# Lint Helm chart
helm lint ./helm/kleidia

# Dry-run deployment
helm upgrade --install kleidia ./helm/kleidia \
  --namespace "${NAMESPACE}" \
  --dry-run \
  --debug
```

**Validate Kubernetes Resources:**

```bash
# Validate Kubernetes manifests
helm template kleidia ./helm/kleidia | kubectl apply --dry-run=client -f -

# Check for resource conflicts
kubectl get all -n "${NAMESPACE}"
```

### Post-Deployment Verification

```bash
# Check pod status
kubectl get pods -n "${NAMESPACE}"

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=backend -n "${NAMESPACE}" --timeout=300s
kubectl wait --for=condition=ready pod -l app=frontend -n "${NAMESPACE}" --timeout=300s

# Check services
kubectl get services -n "${NAMESPACE}"

# Test health endpoint
curl -f https://${DOMAIN}/api/health || exit 1
```

### Integration with CI/CD

Each platform-specific guide includes validation examples:
- [GitHub Actions Validation](GITHUB_ACTIONS_DEPLOYMENT.md#validation-and-testing)
- [GitLab CI Validation](GITLAB_CI_DEPLOYMENT.md#validation-and-testing)
- [Bamboo Validation](BAMBOO_DEPLOYMENT.md#validation-and-testing)

## Best Practices

### General Best Practices

1. **Version Control**: Keep all deployment configurations in version control
2. **Immutable Deployments**: Use immutable image tags, not `latest`
3. **Idempotency**: Ensure deployments are idempotent (can be run multiple times safely)
4. **Timeouts**: Set appropriate timeouts for Helm deployments
5. **Error Handling**: Implement proper error handling and rollback mechanisms
6. **Notifications**: Send deployment notifications (success/failure) to teams
7. **Audit Logging**: Enable audit logging for all deployments

### Security Best Practices

1. **Least Privilege**: Grant minimal required permissions to CI/CD runners
2. **Secrets Rotation**: Implement regular secrets rotation
3. **Network Security**: Use secure channels for cluster access (VPN, private networks)
4. **Image Scanning**: Scan container images for vulnerabilities before deployment
5. **RBAC**: Use Role-Based Access Control for Kubernetes resources
6. **Encryption**: Encrypt secrets at rest and in transit

### Performance Best Practices

1. **Parallel Deployments**: Deploy to multiple environments in parallel when possible
2. **Caching**: Cache Helm chart and dependencies
3. **Resource Limits**: Set appropriate resource requests and limits
4. **Health Checks**: Implement proper readiness and liveness probes
5. **Rolling Updates**: Use rolling update strategy for zero-downtime deployments

## Troubleshooting

### Common Issues

**Deployment Timeout:**

```bash
# Increase timeout
helm upgrade --install kleidia ./helm/kleidia \
  --timeout 15m \
  ...

# Check pod status
kubectl get pods -n "${NAMESPACE}"

# Check pod events
kubectl describe pod -n "${NAMESPACE}" <pod-name>
```

**Secret Creation Failures:**

```bash
# Verify secret doesn't already exist with different type
kubectl get secret -n "${NAMESPACE}"

# Delete and recreate if needed
kubectl delete secret <secret-name> -n "${NAMESPACE}"
kubectl create secret ...
```

**Image Pull Errors:**

```bash
# Verify registry credentials
kubectl get secret -n "${NAMESPACE}" <registry-secret>

# Check image pull policy
kubectl describe pod -n "${NAMESPACE}" <pod-name> | grep -i image

# Verify network connectivity to registry
curl -I https://${REGISTRY_HOST}
```

**Kubernetes Context Issues:**

```bash
# Verify kubectl context
kubectl config current-context

# List available contexts
kubectl config get-contexts

# Set context
kubectl config use-context <context-name>
```

### Debug Commands

```bash
# Get deployment status
helm status kleidia -n "${NAMESPACE}"

# View deployment history
helm history kleidia -n "${NAMESPACE}"

# Get Helm values
helm get values kleidia -n "${NAMESPACE}"

# View rendered manifests
helm template kleidia ./helm/kleidia > rendered-manifests.yaml

# Check pod logs
kubectl logs -n "${NAMESPACE}" -l app=backend
kubectl logs -n "${NAMESPACE}" -l app=frontend
```

For platform-specific troubleshooting, see:
- [GitHub Actions Troubleshooting](GITHUB_ACTIONS_DEPLOYMENT.md#troubleshooting)
- [GitLab CI Troubleshooting](GITLAB_CI_DEPLOYMENT.md#troubleshooting)
- [Bamboo Troubleshooting](BAMBOO_DEPLOYMENT.md#troubleshooting)

## Air-Gapped Deployment

For air-gapped (offline) environments:

1. **Internal Registry**: Use internal container registry accessible from CI/CD runners
2. **Helm Chart**: Package Helm chart and dependencies for offline use
3. **Dependencies**: Download all dependencies (images, charts) before deployment
4. **Network Access**: Ensure CI/CD runners can access internal Kubernetes cluster

**Example for Air-Gapped:**

```bash
# Package Helm chart with dependencies
helm package ./helm/kleidia --destination ./packages

# Download dependencies
helm dependency update ./helm/kleidia

# Deploy from packaged chart
helm upgrade --install kleidia ./packages/kleidia-*.tgz \
  --namespace "${NAMESPACE}" \
  ...
```

## Next Steps

After setting up CI/CD deployment:

1. **Configure Environments**: Set up dev, staging, and production environments
2. **Implement Approval Workflows**: Add approval gates for production deployments
3. **Set Up Monitoring**: Integrate deployment monitoring and alerting
4. **Document Procedures**: Document environment-specific procedures and runbooks
5. **Test Rollback Procedures**: Test and validate rollback procedures regularly
6. **Review Security**: Regular security reviews of CI/CD configurations and secrets

## Platform-Specific Guides

- **[GitHub Actions Deployment](GITHUB_ACTIONS_DEPLOYMENT.md)** - Complete guide for GitHub Actions workflows
- **[GitLab CI Deployment](GITLAB_CI_DEPLOYMENT.md)** - Complete guide for GitLab CI pipelines
- **[Bamboo Deployment](BAMBOO_DEPLOYMENT.md)** - Complete guide for Atlassian Bamboo plans

## Related Documentation

- [Helm Deployment Guide](HELM_DEPLOYMENT.md) - Manual Helm chart deployment
- [Prerequisites](PREREQUISITES.md) - Prerequisites and requirements
- [Installation Overview](README.md) - Installation process overview
- [Agent Setup](AGENT_SETUP.md) - Workstation agent installation

## Support

For CI/CD deployment issues or questions:

- Review troubleshooting sections above and in platform-specific guides
- Check CI/CD platform logs and deployment logs
- Review Helm deployment status: `helm status kleidia -n <namespace>`
- Check pod logs: `kubectl logs -n <namespace> -l app=backend`
- Contact your account representative for support
