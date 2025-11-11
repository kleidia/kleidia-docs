# Glossary

**Audience**: All Users  
**Prerequisites**: None  
**Outcome**: Understand YubiMgr terminology

## Terms

### A

**Agent**: Local HTTP server running on user workstations for YubiKey operations.

**AppRole**: Vault authentication method used by backend to authenticate to Vault.

**Argon2id**: Password hashing algorithm used for secure password storage.

**Audit Log**: Record of all operations and events in the system for compliance and security.

### B

**Backend**: Go/Gin REST API server handling authentication, authorization, and Vault integration.

### C

**Certificate Authority (CA)**: Entity that issues and signs certificates. YubiMgr uses Vault PKI as CA.

**Certificate Signing Request (CSR)**: Request for certificate signing generated on YubiKey using hardware private key.

**CORS**: Cross-Origin Resource Sharing, security feature allowing browser to make requests to localhost agent.

### D

**Device ID**: Unique identifier for YubiKey device (serial number).

### E

**Ephemeral Keys**: Temporary RSA keypairs generated on agent startup, not persisted to disk.

### F

**Frontend**: Vue.js 3 with Nuxt.js 4 web application providing user interface.

### H


### J

**JWT**: JSON Web Token used for user authentication and authorization.

### K


### M

**Management Key**: Cryptographic key used for PIV operations on YubiKey.

**Machine ID**: Unique identifier for workstation, used for agent pairing.

### O

**OpenBao**: OpenBao (Vault fork) used for secrets management and PKI.

### P

**PIV**: Personal Identity Verification, application on YubiKey for certificate storage.

**PKI**: Public Key Infrastructure for certificate management.

**PIN**: Personal Identification Number for YubiKey authentication.

**PUK**: PIN Unlock Key for recovering locked PIN.

**PVC**: Persistent Volume Claim for Kubernetes storage.

### R

**RSA-OAEP**: Encryption algorithm used for encrypting sensitive data before transmission to agent.

**RBAC**: Role-Based Access Control for user permissions.

### S

**Session**: User login session with expiration and agent key binding.

**StatefulSet**: Kubernetes resource for stateful applications like PostgreSQL and Vault.

### V

**Vault**: OpenBao for secrets management and PKI.

### Y

**YubiKey**: Hardware security key device for authentication and certificate storage.

**ykman**: YubiKey Manager CLI tool for YubiKey operations.

## Related Documentation

- [Reference Guide](../06-reference/)

