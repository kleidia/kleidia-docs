# Kleidia Customer Documentation

**Version**: 2.2.0  
**Last Updated**: November 2025

## About This Documentation

This documentation is designed for **Kleidia customers** who need to:

- **Deploy and operate** Kleidia in production environments
- **Understand the architecture** and security model
- **Configure and maintain** the system
- **Use the system** for YubiKey management

## Documentation Structure

### [00 - Overview](00-overview/)
- Product overview and value proposition
- Core architectural principles
- System capabilities and features

### [01 - Architecture](01-architecture/)
- System architecture overview
- Component descriptions and responsibilities
- Data flows and communication patterns
- Architecture diagrams

### [02 - Security](02-security/)
- Security model and threat mitigation
- Vault and secrets management
- Certificate and PKI management
- Authentication and authorization
- Compliance considerations

### [03 - Deployment](03-deployment/)
- Prerequisites and system requirements
- Helm chart deployment
- Configuration management
- OpenBao setup
- Upgrade and rollback procedures

### [04 - Operations](04-operations/)
- Daily operations and monitoring
- Health checks and log management
- Backup and restore procedures
- Troubleshooting runbooks
- Performance optimization

### [05 - Using the System](05-using-the-system/)
- **[Agent Installation](05-using-the-system/agent-installation.md)** - Install agent on workstations
- End-user guide
- Administrator guide
- YubiKey lifecycle management

### [06 - Reference](06-reference/)
- **[Agent Quick Reference](06-reference/agent-quick-reference.md)** - Commands and scripts for agent deployment
- Glossary of terms
- Ports and services
- Permissions and policies
- Compatibility matrix

## Quick Start

1. **New to Kleidia?** Start with [Overview](00-overview/index.md)
2. **Planning deployment?** Read [Deployment Guide](03-deployment/prerequisites.md)
3. **Need to configure?** See [Configuration](03-deployment/configuration.md)
4. **Installing agent?** Follow [Agent Installation](05-using-the-system/agent-installation.md)
5. **Using the system?** Check [User Guides](05-using-the-system/)

## Audience

This documentation is written for:

- **Operations Administrators**: Deploying, configuring, and maintaining Kleidia
- **Security Professionals**: Understanding security controls, compliance, and audit requirements
- **End Users**: Using Kleidia to manage YubiKey devices

## What's Not Included

This documentation does **not** include:

- Developer debugging guides
- Internal API development details
- Code-level implementation details
- Testing procedures for developers
- Experimental or deprecated features

## Support

For technical support or questions about this documentation:

- Check the troubleshooting sections in [Operations](04-operations/)
- Review the [Reference](06-reference/) section for technical details
- Contact your Kleidia support representative

## Documentation Version

This documentation corresponds to **Kleidia version 2.2.0**.

For version-specific information, see [CHANGELOG](CHANGELOG.md).

## License

See [LICENSE](LICENSE) for licensing information.

