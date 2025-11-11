# Agent Communication Model

**Audience**: Operations Administrators, Security Professionals  
**Prerequisites**: Understanding of HTTP and encryption  
**Outcome**: Understand how agents communicate with the system

## Overview

YubiMgr agents use a simplified HTTP-based communication model where agents run anonymously on localhost and communicate directly with the browser. All sensitive operations are encrypted using RSA-OAEP encryption.

## Communication Architecture

### Frontend-Mediated Communication

```
Browser (Frontend)
    │
    ├── HTTPS ──────────▶ Backend (API)
    │                        │
    │                        ├── PostgreSQL (Database)
    │                        └── OpenBao (Vault)
    │
    └── HTTP ────────────▶ Agent (localhost:56123)
                              │
                              └── YubiKey (USB)
```

**Key Points**:
- Browser orchestrates all operations
- Direct HTTP calls to localhost agent (no backend intermediary)
- Backend handles authentication, encryption, and Vault operations
- Agent executes YubiKey operations locally

## Agent Startup and Registration

### Agent Lifecycle

1. **Agent Starts**: Generates ephemeral RSA-4096 keypair stored in memory
2. **HTTP Server**: Starts on localhost:56123
3. **Public Key Exposure**: Available via `GET /pubkey`
4. **Frontend Detection**: Browser detects agent via `/.well-known/yubimgr-agent`
5. **Key Registration**: Frontend registers public key with backend
6. **Ready for Operations**: Agent ready to receive encrypted operations

### Registration Flow

```
Agent Startup:
  ├── Generate RSA-4096 keypair (in memory)
  ├── Start HTTP server on localhost:56123
  └── Expose public key via GET /pubkey

User Login:
  ├── Frontend detects agent (GET /.well-known/yubimgr-agent)
  ├── Frontend gets public key (GET /pubkey)
  ├── Frontend registers key with backend (POST /api/session/{id}/register-agent)
  └── Backend stores key in user_sessions.agent_pubkey

Ready State:
  └── Agent ready to receive encrypted operations
```

## Operation Communication Pattern

### Standard Operation Flow

1. **User Action**: User initiates operation in frontend
2. **Secret Request**: Frontend requests secrets from backend
3. **Encryption**: Backend encrypts secrets with agent's public key
4. **Operation Request**: Frontend sends encrypted data to agent
5. **Decryption**: Agent decrypts data using private key
6. **Execution**: Agent executes YubiKey operation
7. **Response**: Agent returns result to frontend

### Example: PIN Change

```
1. User → Frontend: Request PIN change
2. Frontend → Backend: GET /api/yubikey/{serial}/secrets
3. Backend:
   - Retrieves PIN from Vault
   - Gets agent_pubkey from PostgreSQL
   - Encrypts PIN with RSA-OAEP
4. Backend → Frontend: { encrypted: true, pin: "encrypted_data" }
5. Frontend → Agent: POST http://127.0.0.1:56123/piv/set-pin
   Body: { encrypted: true, pin: "encrypted_data", serial: "..." }
6. Agent:
   - Decrypts PIN using private key
   - Executes: ykman piv change-pin --pin {decrypted_pin} --new-pin {new_pin}
7. Agent → Frontend: { success: true }
8. Frontend: Update UI
```

## Security Model

### Encryption

- **Algorithm**: RSA-OAEP (RSA 4096-bit)
- **Purpose**: Encrypt sensitive data before transmission
- **Key Management**: Ephemeral keys generated on agent startup
- **Key Storage**: Private keys never persisted to disk

### Authentication

- **Agent**: Anonymous (no authentication required)
- **Backend**: JWT tokens for user authentication
- **Session Binding**: Agent keys tied to user sessions

### Network Security

- **Agent Endpoints**: localhost only (127.0.0.1:56123)
- **No External Access**: Agents not accessible from network
- **Browser Security**: CORS protection for localhost access

## Agent Endpoints

### Discovery and Status

- `GET /.well-known/yubimgr-agent` - Agent discovery and status
- `GET /health` - Health check endpoint
- `GET /pubkey` - Get agent's ephemeral public key
- `GET /system/info` - System information

### YubiKey Operations

- `GET /discover` - List connected YubiKeys
- `GET /piv/info?serial={serial}` - Get PIV information
- `POST /piv/set-pin` - Set/change PIN
- `POST /piv/set-puk` - Set/change PUK
- `POST /piv/unblock-pin` - Unblock PIN using PUK
- `POST /piv/generate-csr` - Generate Certificate Signing Request
- `POST /piv/import-certificate` - Import certificate to YubiKey
- `POST /piv/reset` - Reset PIV application
- `GET /piv/check-defaults?serial={serial}` - Check default credentials
- `POST /piv/rotate-management-key` - Rotate management key

## Error Handling

### Common Error Scenarios

1. **Agent Not Running**: Frontend cannot connect to localhost:56123
   - **Response**: Show "Agent not detected" message
   - **Action**: User starts agent or checks installation

2. **Agent Restarted**: New keypair generated, old key invalid
   - **Response**: Frontend detects new key, re-registers
   - **Action**: Automatic re-registration on next operation

3. **YubiKey Not Connected**: Agent cannot find YubiKey
   - **Response**: Agent returns error with device list
   - **Action**: User connects YubiKey and retries

4. **Decryption Failure**: Agent cannot decrypt data
   - **Response**: Agent returns error
   - **Action**: Frontend requests new key registration

## Session Management

### Key Lifecycle

- **Generation**: New keypair on agent startup
- **Registration**: Public key stored in user_sessions table
- **Expiration**: Key expires when user session expires
- **Cleanup**: Automatic cleanup on session logout

### Session Binding

- Agent public keys stored in `user_sessions.agent_pubkey`
- Keys expire with user session expiration
- Zero standing access for logged-out users
- Automatic re-registration on user login

## Operational Considerations

### Agent Deployment

- **Location**: User workstations only
- **Installation**: Binary installation or system service
- **Port**: 56123 (configurable)

### Network Requirements

- **Outbound**: Agent needs outbound HTTPS to backend for agent operations
- **Inbound**: No inbound ports required (localhost only)
- **Firewall**: No firewall rules needed for agent

### Resource Usage

- **CPU**: <1% when idle, ~10% during operations
- **Memory**: ~50-100 MB
- **Network**: Minimal (synchronous operations only)

## Related Documentation

- [Components](components.md)
- [Data Flows](data-flows.md)
- [Security Model](../02-security/security-overview.md)
- [Agent Installation](../05-using-the-system/end-user-guide.md)

