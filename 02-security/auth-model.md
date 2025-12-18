# Authentication Model

**Audience**: Security Professionals, Operations Administrators  
**Prerequisites**: Understanding of authentication and authorization  
**Outcome**: Understand Kleidia's authentication and authorization model

## Overview

Kleidia uses JWT-based authentication with Argon2id password hashing, session management, and role-based access control (RBAC) for secure user authentication and authorization.

## Authentication Flow

### User Login

```
1. User → Frontend: Enter credentials
2. Frontend → Backend: POST /api/auth/login
3. Backend → PostgreSQL: Validate credentials (Argon2id hash)
4. Backend: Generate JWT token pair
5. Backend → Frontend: Access token + Refresh token
6. Frontend: Store tokens, redirect to dashboard
```

### Login Pages

Kleidia provides two login entry points:

| Page | URL | Purpose |
|------|-----|---------|
| Main Login | `/login` | Standard user login (local + SSO when enabled) |
| Admin Login | `/admin-login` | Local login only (for admin break-glass access) |

When OIDC is enabled with "Disable Local Login" active:
- **`/login`**: Shows only the SSO button
- **`/admin-login`**: Always shows local username/password form

The `/admin-login` page provides an escape hatch for administrators when:
- OIDC provider is unavailable
- SSO configuration needs troubleshooting
- Emergency access is required

### Token Structure

#### Access Token (JWT)

```json
{
  "user_id": 1,
  "username": "admin",
  "is_admin": true,
  "session_id": 123,
  "exp": 1640997000,
  "iat": 1640995200,
  "iss": "kleidia",
  "sub": "1"
}
```

**Properties**:
- **Lifetime**: 30 minutes (configurable)
- **Algorithm**: HS256 (HMAC-SHA256)
- **Claims**: User ID, username, admin status, session ID
- **Expiration**: Automatic expiration after configured time

#### Refresh Token

**Properties**:
- **Lifetime**: 7 days (configurable)
- **Purpose**: Obtain new access tokens
- **Storage**: Database (for revocation)
- **Revocation**: Immediate on logout

### Session Management

#### Session Creation

1. User logs in successfully
2. Backend creates session record in database
3. Session includes:
   - User ID
   - Session token (random string)
   - IP address
   - User agent
   - Expiration time (1 hour)
   - Agent public key (after registration)

#### Session Validation

1. Frontend sends JWT token in `Authorization` header
2. Backend validates token signature
3. Backend checks token expiration
4. Backend validates session in database
5. Backend checks user account status

#### Session Expiration

- **Access Token**: Expires after 30 minutes
- **Session**: Expires after 1 hour
- **Automatic Refresh**: Frontend refreshes token before expiration
- **Logout**: Immediate session invalidation

## Password Security

### Argon2id Hashing

Kleidia uses **Argon2id** for password hashing:

- **Algorithm**: Argon2id (winner of Password Hashing Competition)
- **Memory**: 64 MB
- **Time**: 1 iteration
- **Threads**: 4 parallel threads
- **Output**: 32-byte hash

**Why Argon2id?**:
- Memory-hard (resistant to ASIC/GPU attacks)
- Side-channel resistant
- Industry standard (NIST, OWASP recommended)
- Configurable parameters

### Password Storage

- **Database**: Only Argon2id hashes stored
- **No Plaintext**: Passwords never stored in plaintext
- **Salt**: Unique salt per password
- **Verification**: Constant-time comparison

### Password Requirements

- **Minimum Length**: Configurable (default 8 characters)
- **Complexity**: Configurable requirements
- **Change Policy**: Configurable password expiration

## Authorization Model

### Role-Based Access Control (RBAC)

#### Roles

1. **Admin**
   - Full system access
   - User management
   - Policy management
   - System configuration
   - Audit log access
   - Can not delete data (users, logs)

2. **User**
   - Personal YubiKey management
   - Own device operations
   - Certificate generation
   - PIN/PUK management

#### Permissions

Permissions are enforced at the API level:

- **User Operations**: Users can only access their own resources
- **Admin Operations**: Admins can access all resources
- **Policy Enforcement**: Backend validates permissions on each request

### API Authorization

#### Middleware

All API requests go through authorization middleware:

1. **JWT Validation**: Verify token signature and expiration
2. **Session Check**: Validate session in database
3. **User Status**: Check user account is active
4. **Permission Check**: Verify user has required permissions
5. **Resource Access**: Validate user can access requested resource

#### Authorization Headers

```http
Authorization: Bearer <access_token>
```

## Agent Authentication

### Ephemeral Key Model

Agents use ephemeral RSA keypairs (not traditional authentication):

1. **Agent Startup**: Generates RSA-4096 keypair
2. **Public Key Exposure**: Available via `GET /pubkey`
3. **Key Registration**: Frontend registers public key with backend
4. **Session Binding**: Public key stored in user session
5. **Expiration**: Key expires with user session

### Security Properties

- **No Persistent Auth**: No long-lived agent credentials
- **Session Binding**: Keys tied to user sessions
- **Zero Standing Access**: No valid keys for logged-out users
- **Forward Secrecy**: New keys on each agent restart

## Token Security

### Token Generation

- **Cryptographically Secure**: Uses crypto/rand for randomness
- **HMAC-SHA256**: Secure signing algorithm
- **Secret Rotation**: JWT secret stored in Vault
- **Unique Tokens**: Each token has unique ID (JTI)

### Token Validation

- **Signature Verification**: HMAC signature validated
- **Expiration Check**: Token expiration verified
- **Session Validation**: Session checked in database
- **User Status**: User account status verified

### Token Revocation

- **Immediate Logout**: Tokens revoked on logout
- **Session Invalidation**: Session marked as inactive
- **Database Cleanup**: Expired sessions cleaned up automatically

## Security Features

### Session Tracking

- **IP Address Tracking**: IP address stored in session
- **User Agent Tracking**: User agent stored in session

### Rate Limiting

- **Login Attempts**: Limited failed login attempts
- **API Requests**: Rate limiting on API endpoints
- **Brute Force Protection**: Automatic lockout after failed attempts

### Audit Logging

All authentication events logged:

- **Login**: Successful and failed login attempts
- **Logout**: User logout events
- **Token Refresh**: Token refresh operations
- **Session Creation**: Session creation events
- **Permission Denials**: Authorization failures

## Troubleshooting

### Common Issues

1. **Token Expired**
   - **Symptom**: 401 Unauthorized errors
   - **Solution**: Refresh token or re-login

2. **Invalid Token**
   - **Symptom**: 401 Unauthorized errors
   - **Solution**: Clear browser storage, re-login

3. **Session Expired**
   - **Symptom**: Session not found errors
   - **Solution**: Re-login to create new session

4. **Permission Denied**
   - **Symptom**: 403 Forbidden errors
   - **Solution**: Verify user has required permissions

## Related Documentation

- [Security Overview](security-overview.md)
- [Vault and Secrets](vault-and-secrets.md)
- [Compliance Considerations](compliance-considerations.md)

