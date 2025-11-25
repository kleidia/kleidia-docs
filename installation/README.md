# Kleidia Installation Guide

## Overview

This guide covers the complete installation and setup process for Kleidia using Helm charts as the primary deployment method. Kleidia supports two deployment scenarios:

- **Standalone Server Deployment**: Deploy on a standalone server with automatic k0s Kubernetes cluster provisioning
- **Existing Kubernetes Cluster Deployment**: Deploy into an existing Kubernetes cluster (k0s, k3s, EKS, AKS, GKE, or compatible)

The installation process is designed to be straightforward and automated, with comprehensive documentation for each step. Both air-gapped (offline) and online environments are supported.

## Installation Process

The Kleidia installation consists of three main phases:

1. **Prerequisites Setup**: Verify server requirements and prepare the environment
2. **Helm Chart Deployment**: Deploy all infrastructure components using Helm charts
3. **Agent Setup**: Install and configure agents on user workstations

## Quick Start

For a complete installation, follow these steps:

```bash
# 1. Verify prerequisites
# See PREREQUISITES.md for detailed requirements

# 2. Deploy with Helm chart
# Standalone server deployment:
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.registry.host=your-registry.example.com

# Existing Kubernetes cluster deployment:
helm install kleidia ./helm/kleidia \
  --namespace kleidia \
  --create-namespace \
  --set global.domain=your-domain.com \
  --set global.registry.host=your-registry.example.com \
  --set global.deployment.type=existing-cluster

# 3. Verify deployment
kubectl get pods -n kleidia

# 4. Install agent on workstations
# See AGENT_SETUP.md for agent installation
```

## Installation Methods

### Primary Method: Helm Charts

**Helm charts are the recommended deployment method** for all Kleidia installations. The comprehensive Helm chart provides:

- **Infrastructure as Code**: Complete Kubernetes deployment definitions
- **Automatic Secret Management**: Auto-generated secrets and credentials
- **Operator Integration**: PostgreSQL and Vault operators
- **Security Standards**: Pod security standards and RBAC
- **Health Monitoring**: Built-in health checks and readiness probes

## Documentation Structure

### Prerequisites
[Prerequisites](PREREQUISITES.md) covers all requirements before installation:

- **Deployment Scenarios**: Standalone server or existing Kubernetes cluster
- **Server Requirements**: CPU, RAM, disk, network (varies by deployment scenario)
- **Container Registry**: Customer Docker registry or Artifactory (images must be pre-loaded)
- **Domain and SSL**: Customer-provided SSL/TLS certificates or Let's Encrypt (optional)
- **Vault**: Internal Vault (deployed within Kubernetes, default) or External Vault (customer-managed existing instance) for PKI and secret management
- **Network**: Supports both air-gapped (offline) and online environments
- **Workstation Requirements**: Agent installation requirements
- **Software Prerequisites**: Kubernetes, kubectl, Helm (varies by deployment scenario)

### Helm Deployment
[Helm Deployment](HELM_DEPLOYMENT.md) provides complete deployment instructions:

- Prerequisites setup
- Helm chart installation
- Post-deployment verification
- Configuration options
- Troubleshooting common issues

### CI/CD Pipeline Deployment
[CI/CD Pipeline Deployment](CI_CD_DEPLOYMENT.md) covers automated deployment using CI/CD pipelines:

- [GitHub Actions Deployment](GITHUB_ACTIONS_DEPLOYMENT.md) - Complete guide for GitHub Actions workflows
- [GitLab CI Deployment](GITLAB_CI_DEPLOYMENT.md) - Complete guide for GitLab CI pipelines
- [Bamboo Deployment](BAMBOO_DEPLOYMENT.md) - Complete guide for Atlassian Bamboo plans
- Secrets management in CI/CD
- Environment promotion strategies
- Rollback procedures
- Best practices for automated deployments

### Agent Setup
[Agent Setup](AGENT_SETUP.md) covers workstation agent installation:

- Agent installation on workstations
- Configuration requirements
- Verification steps
- Troubleshooting common issues

## Installation Timeline

Expected installation time:

- **Prerequisites Verification**: ~5 minutes
- **Database Setup**: ~2 minutes
- **Vault Configuration**: 
  - Internal Vault: ~3-5 minutes (automatic configuration)
  - External Vault: Vault connectivity verified during deployment
- **Total Installation**: ~5-7 minutes

## Post-Installation

After installation completes:

1. **Verify Deployment**: Check all pods are running
2. **Access Web Portal**: Navigate to `https://your-domain.com`
3. **Configure Admin User**: Use default credentials (change immediately)
4. **Install Agents**: Install agents on user workstations
5. **Test Operations**: Perform test YubiKey operations

## Next Steps

After successful installation:

1. Review [Architecture Documentation](../architecture/README.md) for system overview
2. Configure [Administrative Settings](../architecture/ARCHITECTURE.md) for your organization
3. Install [Workstation Agents](AGENT_SETUP.md) on user machines
4. Register your first YubiKey device through the web portal

## Support

For installation issues or questions:

- Review troubleshooting sections in each guide
- Check deployment logs: `kubectl logs -n kleidia`
- Contact your account representative for support

## Related Documentation

- [Architecture Overview](../architecture/README.md) - System architecture overview
- [Detailed Architecture](../architecture/ARCHITECTURE.md) - Complete technical documentation
- [Architecture Diagrams](../architecture/diagrams/) - Visual architecture diagrams







