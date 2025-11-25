# GitHub Actions Deployment Guide

## Overview

GitHub Actions provides integrated CI/CD workflows for GitHub-hosted repositories. Workflows are defined in `.github/workflows/` directory and executed automatically on specified events (push, pull request, manual trigger).

This guide covers deploying Kleidia using GitHub Actions workflows, including environment-specific deployments, secrets management, rollback procedures, and best practices.

For general CI/CD concepts and prerequisites, see [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md).

## Prerequisites

- **GitHub Repository**: Kleidia Helm chart accessible in GitHub repository
- **GitHub Actions**: Enabled for the repository
- **Kubernetes Access**: GitHub Actions runner must have network access to Kubernetes cluster
- **Secrets Configured**: Required secrets configured in GitHub repository settings

## Required Secrets

Configure the following secrets in your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

**Core Configuration:**
- `KUBECONFIG`: Base64-encoded Kubernetes kubeconfig file content
- `DOMAIN`: Domain name for Kleidia deployment
- `HELM_REGISTRY_HOST`: Customer container registry host

**Deployment-Specific:**
- `NAMESPACE`: Kubernetes namespace (default: `kleidia`)
- `DEPLOYMENT_TYPE`: `standalone` or `existing-cluster`

**Database Configuration (for existing cluster with external PostgreSQL):**
- `DB_HOST`: PostgreSQL host
- `DB_PORT`: PostgreSQL port (default: `5432`)
- `DB_NAME`: Database name
- `DB_USERNAME`: Database username
- `DB_PASSWORD`: Database password (marked as secret)

**Vault Configuration (for external Vault):**
- `VAULT_ADDRESS`: External Vault address
- `VAULT_ROLE_ID`: Vault AppRole role ID
- `VAULT_SECRET_ID`: Vault AppRole secret ID (marked as secret)
- `VAULT_PATH`: Vault KV v2 mount path (default: `yubikeys`)

**Storage Configuration (for existing cluster with internal components):**
- `STORAGE_CLASS_VAULT`: Storage class for Vault PVC
- `STORAGE_CLASS_POSTGRES`: Storage class for PostgreSQL PVC

**Image Configuration:**
- `BACKEND_IMAGE_TAG`: Backend image tag
- `FRONTEND_IMAGE_TAG`: Frontend image tag

For complete list of required secrets, see [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md#required-secrets-and-variables).

## Basic Workflow Structure

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Kleidia

on:
  push:
    branches:
      - main
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

env:
  HELM_CHART_PATH: ./helm/kleidia
  NAMESPACE: kleidia

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Setup Helm
        uses: azure/setup-helm@v3

      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=$(pwd)/kubeconfig

      - name: Create namespace
        run: kubectl create namespace ${{ env.NAMESPACE }} --dry-run=client -o yaml | kubectl apply -f -

      - name: Deploy Kleidia
        run: |
          helm upgrade --install kleidia ${{ env.HELM_CHART_PATH }} \
            --namespace ${{ env.NAMESPACE }} \
            --set global.domain=${{ secrets.DOMAIN }} \
            --set global.namespace=${{ env.NAMESPACE }} \
            --set global.registry.host=${{ secrets.HELM_REGISTRY_HOST }} \
            --set global.deployment.type=existing-cluster \
            --set vault.type=internal \
            --set storage.vault.storageClassName=${{ secrets.STORAGE_CLASS_VAULT }} \
            --set storage.vault.size=20Gi \
            --wait \
            --timeout 10m

      - name: Verify deployment
        run: |
          kubectl wait --for=condition=ready pod -l app=backend -n ${{ env.NAMESPACE }} --timeout=300s
          kubectl wait --for=condition=ready pod -l app=frontend -n ${{ env.NAMESPACE }} --timeout=300s
```

## Standalone Server Deployment

**Workflow for Standalone Server:**

```yaml
name: Deploy Kleidia (Standalone)

on:
  workflow_dispatch:
    inputs:
      domain:
        description: 'Domain name'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Setup Helm
        uses: azure/setup-helm@v3

      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=$(pwd)/kubeconfig

      - name: Deploy Kleidia (Standalone)
        run: |
          helm upgrade --install kleidia ./helm/kleidia \
            --namespace kleidia \
            --create-namespace \
            --set global.domain=${{ inputs.domain }} \
            --set global.namespace=kleidia \
            --set global.registry.host=${{ secrets.HELM_REGISTRY_HOST }} \
            --set global.deployment.type=standalone \
            --set vault.type=internal \
            --wait \
            --timeout 10m
```

## Existing Cluster Deployment

### External PostgreSQL and Internal Vault

```yaml
      - name: Create database password secret
        run: |
          kubectl create secret generic postgres-credentials \
            --from-literal=password="${{ secrets.DB_PASSWORD }}" \
            --namespace ${{ env.NAMESPACE }} \
            --dry-run=client -o yaml | kubectl apply -f -

      - name: Deploy Kleidia
        run: |
          helm upgrade --install kleidia ./helm/kleidia \
            --namespace ${{ env.NAMESPACE }} \
            --set global.domain=${{ secrets.DOMAIN }} \
            --set global.namespace=${{ env.NAMESPACE }} \
            --set global.registry.host=${{ secrets.HELM_REGISTRY_HOST }} \
            --set global.deployment.type=existing-cluster \
            --set database.type=external \
            --set database.host=${{ secrets.DB_HOST }} \
            --set database.port=${{ secrets.DB_PORT }} \
            --set database.name=${{ secrets.DB_NAME }} \
            --set database.username=${{ secrets.DB_USERNAME }} \
            --set database.passwordSecret=postgres-credentials \
            --set vault.type=internal \
            --set storage.vault.storageClassName=${{ secrets.STORAGE_CLASS_VAULT }} \
            --set storage.vault.size=20Gi \
            --wait \
            --timeout 10m
```

### External Vault Configuration

```yaml
      - name: Create Vault AppRole secret
        run: |
          kubectl create secret generic vault-approle-secret \
            --from-literal=secret-id="${{ secrets.VAULT_SECRET_ID }}" \
            --namespace ${{ env.NAMESPACE }} \
            --dry-run=client -o yaml | kubectl apply -f -

      - name: Deploy Kleidia with External Vault
        run: |
          helm upgrade --install kleidia ./helm/kleidia \
            --namespace ${{ env.NAMESPACE }} \
            --set global.domain=${{ secrets.DOMAIN }} \
            --set global.namespace=${{ env.NAMESPACE }} \
            --set global.registry.host=${{ secrets.HELM_REGISTRY_HOST }} \
            --set global.deployment.type=existing-cluster \
            --set vault.type=external \
            --set vault.address=${{ secrets.VAULT_ADDRESS }} \
            --set vault.appRole.roleId=${{ secrets.VAULT_ROLE_ID }} \
            --set vault.appRole.secretIdSecret=vault-approle-secret \
            --set vault.path=${{ secrets.VAULT_PATH }} \
            --wait \
            --timeout 10m
```

## Multi-Environment Deployment

**Multi-Environment Workflow:**

```yaml
name: Deploy Kleidia

on:
  push:
    branches:
      - develop  # Deploy to dev
      - staging  # Deploy to staging
      - main     # Deploy to production (requires approval)

jobs:
  determine-environment:
    runs-on: ubuntu-latest
    outputs:
      environment: ${{ steps.set-env.outputs.environment }}
    steps:
      - id: set-env
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "environment=dev" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/staging" ]]; then
            echo "environment=staging" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
          fi

  deploy:
    needs: determine-environment
    runs-on: ubuntu-latest
    environment: ${{ needs.determine-environment.outputs.environment }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup kubectl and Helm
        uses: azure/setup-helm@v3

      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=$(pwd)/kubeconfig

      - name: Deploy
        run: |
          helm upgrade --install kleidia ./helm/kleidia \
            --namespace kleidia-${{ needs.determine-environment.outputs.environment }} \
            --create-namespace \
            --set global.domain=kleidia-${{ needs.determine-environment.outputs.environment }}.example.com \
            --set global.registry.host=${{ secrets.HELM_REGISTRY_HOST }} \
            --wait \
            --timeout 10m
```

**Environment Protection Rules:**

Configure environment protection rules in repository Settings → Environments:

- **Development**: No protection (auto-deploy)
- **Staging**: Optional required reviewers
- **Production**: Required reviewers, wait timer

## Rollback Support

**Automated Rollback on Failure:**

```yaml
      - name: Get current Helm revision
        id: get-revision
        run: |
          REVISION=$(helm history kleidia -n ${{ env.NAMESPACE }} --output json | jq -r '.[0].revision // "0"')
          echo "revision=$REVISION" >> $GITHUB_OUTPUT

      - name: Rollback on failure
        if: failure()
        run: |
          helm rollback kleidia ${{ steps.get-revision.outputs.revision }} -n ${{ env.NAMESPACE }}
```

**Manual Rollback Workflow:**

Create `.github/workflows/rollback.yml`:

```yaml
name: Rollback Kleidia

on:
  workflow_dispatch:
    inputs:
      revision:
        description: 'Helm revision number (leave empty for previous)'
        required: false
        type: number

env:
  NAMESPACE: kleidia

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Setup Helm
        uses: azure/setup-helm@v3

      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=$(pwd)/kubeconfig

      - name: Determine revision
        id: revision
        run: |
          if [ -z "${{ inputs.revision }}" ]; then
            REVISION=$(helm history kleidia -n ${{ env.NAMESPACE }} --output json | jq -r '.[1].revision // "0"')
          else
            REVISION=${{ inputs.revision }}
          fi
          echo "revision=$REVISION" >> $GITHUB_OUTPUT

      - name: Rollback
        run: |
          helm rollback kleidia ${{ steps.revision.outputs.revision }} -n ${{ env.NAMESPACE }}

      - name: Verify rollback
        run: |
          kubectl wait --for=condition=ready pod -l app=backend -n ${{ env.NAMESPACE }} --timeout=300s
          kubectl wait --for=condition=ready pod -l app=frontend -n ${{ env.NAMESPACE }} --timeout=300s
```

## Image Tagging

**Dynamic Image Tagging:**

```yaml
      - name: Set image tag
        id: image-tag
        run: |
          if [[ "${{ github.ref }}" == refs/tags/* ]]; then
            TAG=${GITHUB_REF#refs/tags/}
          else
            TAG=${GITHUB_SHA::7}
          fi
          echo "tag=${TAG}" >> $GITHUB_OUTPUT

      - name: Deploy
        run: |
          helm upgrade --install kleidia ./helm/kleidia \
            --set components.backend.image.tag=${{ steps.image-tag.outputs.tag }} \
            --set components.frontend.image.tag=${{ steps.image-tag.outputs.tag }} \
            ...
```

## Validation and Testing

**Pre-Deployment Validation:**

```yaml
      - name: Validate deployment
        run: |
          helm lint ./helm/kleidia
          helm upgrade --install kleidia ./helm/kleidia \
            --namespace ${NAMESPACE} \
            --dry-run \
            --debug

      - name: Deploy
        run: |
          helm upgrade --install kleidia ./helm/kleidia ...

      - name: Verify deployment
        run: |
          kubectl wait --for=condition=ready pod -l app=backend -n ${NAMESPACE} --timeout=300s
          curl -f https://${DOMAIN}/api/health
```

## Secrets Management

### Configuring Secrets

1. Navigate to repository **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Enter secret name and value
4. Click **Add secret**

### Using Secrets

Access secrets in workflows using `${{ secrets.SECRET_NAME }}`:

```yaml
      - name: Deploy
        run: |
          helm upgrade --install kleidia ./helm/kleidia \
            --set global.domain=${{ secrets.DOMAIN }} \
            ...
```

### Environment-Specific Secrets

Use GitHub Environments to configure environment-specific secrets:

1. Navigate to **Settings → Environments**
2. Create environments (dev, staging, production)
3. Configure environment-specific secrets
4. Use `environment:` in workflow jobs:

```yaml
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      ...
```

### Best Practices

- **Never commit secrets**: Never store secrets in workflow files or code
- **Use environment protection**: Enable protection rules for production
- **Rotate secrets regularly**: Implement secret rotation policies
- **Use minimal permissions**: Grant only necessary permissions to GitHub Actions
- **Audit access**: Monitor secret access in GitHub audit logs

## Troubleshooting

### Common Issues

**Workflow Not Triggering:**
- Check workflow file location (`.github/workflows/`)
- Verify trigger conditions (branches, tags)
- Check repository Actions permissions

**Kubernetes Connection Issues:**
- Verify `KUBECONFIG` secret is correctly base64-encoded
- Check network connectivity from GitHub Actions runner
- Verify cluster access permissions

**Helm Deployment Failures:**
- Check Helm chart path is correct
- Verify all required secrets are configured
- Review workflow logs for detailed error messages

**Secret Not Found:**
- Verify secret name matches exactly (case-sensitive)
- Check secret is configured in correct repository/environment
- Ensure secret is not masked in workflow logs

### Debug Workflow

Add debugging steps:

```yaml
      - name: Debug information
        run: |
          echo "Repository: ${{ github.repository }}"
          echo "Ref: ${{ github.ref }}"
          echo "SHA: ${{ github.sha }}"
          kubectl version --client
          helm version
```

## Best Practices

1. **Use Matrix Builds**: Test multiple environments simultaneously
2. **Cache Dependencies**: Cache Helm chart dependencies for faster builds
3. **Parallel Jobs**: Run validation and deployment in parallel when possible
4. **Workflow Reusability**: Use workflow calls to reuse common steps
5. **Status Checks**: Configure required status checks for protected branches
6. **Notifications**: Add workflow status notifications (Slack, email, etc.)

## Related Documentation

- [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md) - General CI/CD concepts and prerequisites
- [Helm Deployment Guide](HELM_DEPLOYMENT.md) - Manual Helm chart deployment
- [Prerequisites](PREREQUISITES.md) - Prerequisites and requirements

## Support

For GitHub Actions deployment issues:

- Review troubleshooting section above
- Check GitHub Actions workflow logs
- Review Helm deployment status: `helm status kleidia -n <namespace>`
- Contact your account representative for support

