
# Start Here: Security Leads & Architects

**Audience**: CISOs, Security Architects, Security Engineers, Compliance Officers  
**Prerequisites**: Understanding of enterprise security concepts, PKI, and identity management  
**Outcome**: Evaluate Kleidia's security architecture, trust model, and compliance capabilities

## Your Role

As a security lead, you're responsible for evaluating whether Kleidia meets your organization's security requirements. You need to understand the architecture, trust boundaries, key management model, and how Kleidia supports compliance with frameworks like NIS2 and ISO 27001.

## Recommended Reading Path

### 1. Understand the Architecture

Start with a high-level understanding of how Kleidia works:

- **[Overview](../overview/)** - What Kleidia does and its deployment model (self-hosted, no SaaS)
- **[Architecture Overview](../architecture/)** - Components, data flows, and deployment topology

### 2. Deep Dive on Security

Understand the security model and trust boundaries:

- **[Security Overview for Auditors](../security/for-auditors/)** - One-page security summary with trust boundaries and compliance mapping
- **[Authentication Model](../security/auth-model/)** - How users and systems authenticate
- **[Vault and Secrets](../security/vault-and-secrets/)** - Secret management architecture using OpenBao
- **[Certificates & PKI](../security/certificates-and-pki/)** - PKI architecture and certificate lifecycle

### 3. PKI Integration

Understand how Kleidia integrates with your existing PKI:

- **[PKI Integration Patterns](../deployment/pki-integration/)** - Integration with AD CS, EJBCA, and existing Vault infrastructure
- Key ownership model: who controls which keys

### 4. Compliance Considerations

Review how Kleidia supports compliance:

- **[Compliance Considerations](../security/compliance/)** - NIS2, ISO 27001, and regulatory alignment
- Audit logging capabilities and SIEM integration

### 5. Operations Overview

Understand day-2 security operations:

- **[Runbooks](../operations/runbooks/)** - Incident response procedures (lost YubiKey, user departure)
- **[Monitoring & Logs](../operations/monitoring/)** - Security event monitoring

## Key Questions Answered

| Question | Where to Find Answer |
|----------|---------------------|
| Where do private keys reside? | [Security for Auditors](../security/for-auditors/) - Keys stay on YubiKey hardware |
| How does Kleidia integrate with our CA? | [PKI Integration Patterns](../deployment/pki-integration/) |
| Is there a SaaS dependency? | [Overview](../overview/) - Fully self-hosted, no external dependencies |
| What gets logged for compliance? | [Compliance Considerations](../security/compliance/) |
| How are secrets protected? | [Vault and Secrets](../security/vault-and-secrets/) |

## Next Steps

After completing your security review:

1. **Technical Evaluation**: Work with your operations team to deploy a [POC](../getting-started/poc-quickstart/)
2. **Production Planning**: Review [Deployment Prerequisites](../deployment/prerequisites/)
3. **Contact Us**: Reach out to discuss your specific security requirements




