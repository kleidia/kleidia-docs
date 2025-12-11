
# Start Here: Operations & DevOps

**Audience**: DevOps Engineers, Platform Engineers, System Administrators, Infrastructure Engineers  
**Prerequisites**: Familiarity with Kubernetes, Helm, and infrastructure management  
**Outcome**: Understand how to deploy, configure, operate, and maintain Kleidia

## Your Role

As an operations engineer, you're responsible for deploying Kleidia, integrating it with your infrastructure, and ensuring reliable day-2 operations. You need to understand deployment options, configuration, monitoring, backup procedures, and troubleshooting.

## Recommended Reading Path

### 1. Understand the Architecture

Before deploying, understand what you're working with:

- **[Overview](../overview/)** - What Kleidia does and its components
- **[Architecture Overview](../architecture/)** - Component diagram, data flows, and scalability

### 2. Plan Your Deployment

Prepare your environment:

- **[Prerequisites](../deployment/prerequisites/)** - Infrastructure requirements (Kubernetes, storage, networking)
- **[Helm Installation](../deployment/helm-install/)** - Helm chart deployment guide
- **[Configuration](../deployment/configuration/)** - Configuration options and customization

### 3. Set Up Integrations

Configure required integrations:

- **[Vault/OpenBao Setup](../deployment/vault-setup/)** - Configure the secrets and PKI backend
- **[PKI Integration](../deployment/pki-integration/)** - Connect to your enterprise CA (AD CS, EJBCA)
- **[Azure Entra Integration](../deployment/azure-entra/)** - Configure OIDC authentication
- **[Storage Configuration](../deployment/storage/)** - Database and persistent volume setup
- **[Load Balancer Setup](../deployment/load-balancer/)** - Ingress and TLS termination

### 4. Day-2 Operations

Prepare for ongoing operations:

- **[Daily Operations](../operations/daily-operations/)** - Routine operational tasks
- **[Monitoring & Logs](../operations/monitoring/)** - Health checks, metrics, and log aggregation
- **[Backups & Restore](../operations/backups/)** - Backup procedures and disaster recovery
- **[Upgrades & Rollback](../deployment/upgrades/)** - Upgrade procedures and rollback strategies

### 5. Troubleshooting

When things go wrong:

- **[Troubleshooting Guide](../deployment/troubleshooting/)** - Common issues and solutions
- **[Runbooks](../operations/runbooks/)** - Incident response procedures

## Quick Reference

| Task | Documentation |
|------|---------------|
| Deploy Kleidia | [Helm Installation](../deployment/helm-install/) |
| Configure OIDC/SSO | [Azure Entra Integration](../deployment/azure-entra/) |
| Set up PKI | [Vault Setup](../deployment/vault-setup/) + [PKI Integration](../deployment/pki-integration/) |
| Monitor health | [Monitoring & Logs](../operations/monitoring/) |
| Back up data | [Backups & Restore](../operations/backups/) |
| Upgrade version | [Upgrades & Rollback](../deployment/upgrades/) |
| Troubleshoot issues | [Troubleshooting](../deployment/troubleshooting/) |

## Deployment Checklist

Before going to production, ensure you've completed:

- [ ] Kubernetes cluster meets [prerequisites](../deployment/prerequisites/)
- [ ] Helm chart deployed with production values
- [ ] OpenBao configured as intermediate CA (not self-signed)
- [ ] OIDC/SSO configured and tested
- [ ] TLS certificates installed
- [ ] Persistent storage configured
- [ ] Backup procedures tested
- [ ] Monitoring and alerting configured
- [ ] Runbooks reviewed with support team

## Next Steps

1. **Start with POC**: Deploy a [test environment](../getting-started/poc-quickstart/) first
2. **Review Security**: Coordinate with security team on [PKI integration](../deployment/pki-integration/)
3. **Plan Production**: Use the checklist above for production readiness




