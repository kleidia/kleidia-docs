# GitLab CI Deployment Guide

## Overview

GitLab CI uses `.gitlab-ci.yml` files in the repository root to define CI/CD pipelines. GitLab runners execute jobs defined in the pipeline, enabling automated deployment of Kleidia.

This guide covers deploying Kleidia using GitLab CI pipelines, including environment-specific deployments, secrets management, rollback procedures, and best practices.

For general CI/CD concepts and prerequisites, see [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md).

## Prerequisites

- **GitLab Repository**: Kleidia Helm chart accessible in GitLab repository
- **GitLab Runners**: GitLab runners configured and available
- **Kubernetes Access**: GitLab runner must have network access to Kubernetes cluster
- **Variables Configured**: Required CI/CD variables configured in GitLab project settings

## Required Variables

Configure the following variables in your GitLab project:

**Settings → CI/CD → Variables → Add variable**

**Core Configuration:**
- `KUBECONFIG`: Kubernetes kubeconfig file content (marked as File, Masked, Protected)
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
- `DB_PASSWORD`: Database password (marked as Masked, Protected)

**Vault Configuration (for external Vault):**
- `VAULT_ADDRESS`: External Vault address
- `VAULT_ROLE_ID`: Vault AppRole role ID
- `VAULT_SECRET_ID`: Vault AppRole secret ID (marked as Masked, Protected)
- `VAULT_PATH`: Vault KV v2 mount path (default: `yubikeys`)

**Storage Configuration (for existing cluster with internal components):**
- `STORAGE_CLASS_VAULT`: Storage class for Vault PVC
- `STORAGE_CLASS_POSTGRES`: Storage class for PostgreSQL PVC

**Image Configuration:**
- `BACKEND_IMAGE_TAG`: Backend image tag
- `FRONTEND_IMAGE_TAG`: Frontend image tag

For complete list of required variables, see [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md#required-secrets-and-variables).

## Basic Pipeline Structure

Create `.gitlab-ci.yml`:

```yaml
stages:
  - deploy

variables:
  HELM_CHART_PATH: ./helm/kleidia
  NAMESPACE: kleidia

.deploy_template: &deploy_template
  stage: deploy
  image: alpine/helm:latest
  before_script:
    - apk add --no-cache curl kubectl
    - kubectl version --client
    - helm version
  script:
    - kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    - |
      helm upgrade --install kleidia ${HELM_CHART_PATH} \
        --namespace ${NAMESPACE} \
        --set global.domain=${DOMAIN} \
        --set global.namespace=${NAMESPACE} \
        --set global.registry.host=${HELM_REGISTRY_HOST} \
        --set global.deployment.type=existing-cluster \
        --set vault.type=internal \
        --set storage.vault.storageClassName=${STORAGE_CLASS_VAULT} \
        --set storage.vault.size=20Gi \
        --wait \
        --timeout 10m
    - |
      kubectl wait --for=condition=ready pod -l app=backend -n ${NAMESPACE} --timeout=300s
      kubectl wait --for=condition=ready pod -l app=frontend -n ${NAMESPACE} --timeout=300s

deploy:staging:
  <<: *deploy_template
  only:
    - staging
  environment:
    name: staging
    url: https://kleidia-staging.example.com

deploy:production:
  <<: *deploy_template
  only:
    - main
  when: manual
  environment:
    name: production
    url: https://kleidia.example.com
```

## Standalone Server Deployment

```yaml
deploy:standalone:
  stage: deploy
  image: alpine/helm:latest
  before_script:
    - apk add --no-cache curl kubectl
  script:
    - |
      helm upgrade --install kleidia ./helm/kleidia \
        --namespace kleidia \
        --create-namespace \
        --set global.domain=${DOMAIN} \
        --set global.namespace=kleidia \
        --set global.registry.host=${HELM_REGISTRY_HOST} \
        --set global.deployment.type=standalone \
        --set vault.type=internal \
        --wait \
        --timeout 10m
  only:
    - main
  when: manual
```

## Existing Cluster Deployment

### External PostgreSQL and Internal Vault

```yaml
deploy:external-db:
  stage: deploy
  image: alpine/helm:latest
  before_script:
    - apk add --no-cache curl kubectl
  script:
    - |
      kubectl create secret generic postgres-credentials \
        --from-literal=password="${DB_PASSWORD}" \
        --namespace ${NAMESPACE} \
        --dry-run=client -o yaml | kubectl apply -f -
    - |
      helm upgrade --install kleidia ./helm/kleidia \
        --namespace ${NAMESPACE} \
        --set global.domain=${DOMAIN} \
        --set global.namespace=${NAMESPACE} \
        --set global.registry.host=${HELM_REGISTRY_HOST} \
        --set global.deployment.type=existing-cluster \
        --set database.type=external \
        --set database.host=${DB_HOST} \
        --set database.port=${DB_PORT} \
        --set database.name=${DB_NAME} \
        --set database.username=${DB_USERNAME} \
        --set database.passwordSecret=postgres-credentials \
        --set vault.type=internal \
        --set storage.vault.storageClassName=${STORAGE_CLASS_VAULT} \
        --set storage.vault.size=20Gi \
        --wait \
        --timeout 10m
```

### External Vault Configuration

```yaml
deploy:external-vault:
  stage: deploy
  image: alpine/helm:latest
  before_script:
    - apk add --no-cache curl kubectl
  script:
    - |
      kubectl create secret generic vault-approle-secret \
        --from-literal=secret-id="${VAULT_SECRET_ID}" \
        --namespace ${NAMESPACE} \
        --dry-run=client -o yaml | kubectl apply -f -
    - |
      helm upgrade --install kleidia ./helm/kleidia \
        --namespace ${NAMESPACE} \
        --set global.domain=${DOMAIN} \
        --set global.namespace=${NAMESPACE} \
        --set global.registry.host=${HELM_REGISTRY_HOST} \
        --set global.deployment.type=existing-cluster \
        --set vault.type=external \
        --set vault.address=${VAULT_ADDRESS} \
        --set vault.appRole.roleId=${VAULT_ROLE_ID} \
        --set vault.appRole.secretIdSecret=vault-approle-secret \
        --set vault.path=${VAULT_PATH} \
        --wait \
        --timeout 10m
```

## Multi-Environment Deployment

**Multi-Environment Pipeline:**

```yaml
stages:
  - deploy

.deploy_base: &deploy_base
  image: alpine/helm:latest
  before_script:
    - apk add --no-cache curl kubectl
  script:
    - kubectl create namespace ${CI_ENVIRONMENT_NAME} --dry-run=client -o yaml | kubectl apply -f -
    - |
      helm upgrade --install kleidia ./helm/kleidia \
        --namespace ${CI_ENVIRONMENT_NAME} \
        --set global.domain=kleidia-${CI_ENVIRONMENT_NAME}.example.com \
        --set global.registry.host=${HELM_REGISTRY_HOST} \
        --wait \
        --timeout 10m

deploy:dev:
  <<: *deploy_base
  stage: deploy
  environment:
    name: development
  only:
    - develop

deploy:staging:
  <<: *deploy_base
  stage: deploy
  environment:
    name: staging
  only:
    - staging

deploy:production:
  <<: *deploy_base
  stage: deploy
  environment:
    name: production
  only:
    - main
  when: manual
```

## Rollback Support

**Rollback Job:**

```yaml
rollback:
  stage: deploy
  image: alpine/helm:latest
  before_script:
    - apk add --no-cache curl kubectl
  script:
    - |
      REVISION=${CI_COMMIT_REF_NAME}
      if [ -z "$REVISION" ]; then
        REVISION=$(helm history kleidia -n ${NAMESPACE} --output json | jq -r '.[1].revision // "0"')
      fi
      helm rollback kleidia ${REVISION} -n ${NAMESPACE}
  when: manual
  only:
    - main
  environment:
    name: production
    action: rollback
```

**Automated Rollback on Failure:**

```yaml
deploy:
  stage: deploy
  image: alpine/helm:latest
  script:
    - |
      CURRENT_REVISION=$(helm history kleidia -n ${NAMESPACE} --output json | jq -r '.[0].revision // "0"')
      if ! helm upgrade --install kleidia ./helm/kleidia ...; then
        helm rollback kleidia ${CURRENT_REVISION} -n ${NAMESPACE}
        exit 1
      fi
  after_script:
    - |
      if [ "$CI_JOB_STATUS" == "failed" ]; then
        echo "Deployment failed, check logs above"
      fi
```

## Image Tagging

**Dynamic Image Tagging:**

```yaml
variables:
  IMAGE_TAG: ${CI_COMMIT_SHORT_SHA}

script:
  - |
    helm upgrade --install kleidia ./helm/kleidia \
      --set components.backend.image.tag=${IMAGE_TAG} \
      --set components.frontend.image.tag=${IMAGE_TAG} \
      ...
```

**Branch-Specific Tagging:**

```yaml
variables:
  IMAGE_TAG: "${CI_COMMIT_REF_SLUG}-${CI_COMMIT_SHORT_SHA}"

script:
  - |
    helm upgrade --install kleidia ./helm/kleidia \
      --set components.backend.image.tag=${IMAGE_TAG} \
      --set components.frontend.image.tag=${IMAGE_TAG} \
      ...
```

## Validation and Testing

**Pre-Deployment Validation:**

```yaml
validate:
  stage: .pre
  image: alpine/helm:latest
  before_script:
    - apk add --no-cache curl kubectl
  script:
    - helm lint ./helm/kleidia
    - helm upgrade --install kleidia ./helm/kleidia \
        --namespace ${NAMESPACE} \
        --dry-run \
        --debug

deploy:
  stage: deploy
  image: alpine/helm:latest
  script:
    - helm upgrade --install kleidia ./helm/kleidia ...
  after_script:
    - |
      kubectl wait --for=condition=ready pod -l app=backend -n ${NAMESPACE} --timeout=300s
      curl -f https://${DOMAIN}/api/health || exit 1
```

## Secrets Management

### Configuring Variables

1. Navigate to project **Settings → CI/CD → Variables**
2. Click **Add variable**
3. Enter variable key and value
4. Mark sensitive variables as **Masked** and **Protected**
5. For file content (like kubeconfig), mark as **File**
6. Click **Add variable**

### Using Variables

Access variables in pipelines using `${VARIABLE_NAME}` or `$VARIABLE_NAME`:

```yaml
script:
  - |
    helm upgrade --install kleidia ./helm/kleidia \
      --set global.domain=${DOMAIN} \
      ...
```

### Environment-Specific Variables

Use GitLab Environments to configure environment-specific variables:

1. Navigate to **Operations → Environments**
2. Create or edit environments
3. Configure environment-specific variables
4. Use `environment:` in pipeline jobs:

```yaml
deploy:production:
  environment:
    name: production
    url: https://kleidia.example.com
  script:
    ...
```

### Variable Types

- **Variable**: Standard variable (visible in job logs if not masked)
- **File**: File content (saved to file, path in `$VARIABLE_NAME`)
- **Masked**: Variable value hidden in job logs
- **Protected**: Variable only available for protected branches/tags

### Best Practices

- **Never commit secrets**: Never store secrets in `.gitlab-ci.yml` or repository
- **Use Masked and Protected**: Mark sensitive variables as Masked and Protected
- **Use File type for kubeconfig**: Save kubeconfig as File variable
- **Rotate secrets regularly**: Implement secret rotation policies
- **Use minimal permissions**: Grant only necessary permissions to GitLab runners
- **Audit access**: Monitor variable access in GitLab audit logs

## Troubleshooting

### Common Issues

**Pipeline Not Triggering:**
- Check `.gitlab-ci.yml` file location (repository root)
- Verify branch/tag conditions in `only:` or `rules:`
- Check GitLab CI/CD settings are enabled

**Runner Not Available:**
- Verify GitLab runners are registered and active
- Check runner tags match job tags
- Verify runner has necessary tools (kubectl, helm) installed

**Kubernetes Connection Issues:**
- Verify `KUBECONFIG` variable is configured correctly (File type)
- Check network connectivity from GitLab runner to Kubernetes cluster
- Verify cluster access permissions

**Variable Not Found:**
- Verify variable name matches exactly (case-sensitive)
- Check variable is configured for correct environment (Protected variables)
- Ensure variable is not masked when debugging (temporarily disable Masked)

### Debug Pipeline

Add debugging steps:

```yaml
debug:
  stage: deploy
  image: alpine/helm:latest
  script:
    - echo "Project: ${CI_PROJECT_NAME}"
    - echo "Branch: ${CI_COMMIT_REF_NAME}"
    - echo "SHA: ${CI_COMMIT_SHA}"
    - kubectl version --client
    - helm version
    - echo "Variables available:"
    - env | grep -E "(DOMAIN|NAMESPACE|HELM)" || true
```

## Best Practices

1. **Use Pipeline Templates**: Reuse common job templates with YAML anchors
2. **Cache Dependencies**: Cache Helm chart dependencies for faster builds
3. **Parallel Jobs**: Run validation and deployment in parallel when possible
4. **Environment Promotion**: Use GitLab environments for clear environment separation
5. **Protected Branches**: Configure protected branches with required pipeline status
6. **Notifications**: Configure pipeline notifications (Slack, email, etc.)
7. **Artifacts**: Save deployment artifacts for debugging and rollback

## Related Documentation

- [CI/CD Pipeline Deployment Guide](CI_CD_DEPLOYMENT.md) - General CI/CD concepts and prerequisites
- [Helm Deployment Guide](HELM_DEPLOYMENT.md) - Manual Helm chart deployment
- [Prerequisites](PREREQUISITES.md) - Prerequisites and requirements

## Support

For GitLab CI deployment issues:

- Review troubleshooting section above
- Check GitLab CI/CD pipeline logs
- Review Helm deployment status: `helm status kleidia -n <namespace>`
- Contact your account representative for support

