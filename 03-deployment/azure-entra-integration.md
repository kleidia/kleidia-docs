# Azure Entra ID Integration with Kleidia

This guide covers integrating Kleidia-managed YubiKeys with Microsoft Azure Entra ID (formerly Azure Active Directory) for passwordless authentication.

## Overview

Kleidia enables organizations to manage YubiKey FIDO2 credentials alongside PIV certificates. When combined with Azure Entra ID, users can leverage their YubiKeys for:

- **Passwordless sign-in** to Microsoft 365, Azure Portal, and Entra ID-connected applications
- **Multi-factor authentication (MFA)** as a phishing-resistant second factor
- **Conditional Access policies** requiring hardware security keys

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          User Workstation                                │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────┐ │
│  │   Browser    │────▶│ Kleidia      │────▶│ Local Agent              │ │
│  │              │     │ Frontend     │     │ (ykman fido commands)    │ │
│  └──────────────┘     └──────────────┘     └───────────┬──────────────┘ │
│                                                        │                │
│                                                        ▼                │
│                                              ┌─────────────────┐        │
│                                              │    YubiKey      │        │
│                                              │ ┌─────────────┐ │        │
│                                              │ │ PIV Applet  │ │        │
│                                              │ ├─────────────┤ │        │
│                                              │ │ FIDO2 Applet│◀────┐    │
│                                              │ └─────────────┘ │   │    │
│                                              └─────────────────┘   │    │
└────────────────────────────────────────────────────────────────────┼────┘
                                                                     │
                                                    WebAuthn Challenge
                                                                     │
┌────────────────────────────────────────────────────────────────────┼────┐
│                        Azure Entra ID                              │    │
│  ┌───────────────────────────────────────────────────────────────┐ │    │
│  │                   Authentication Service                       │ │    │
│  │  ┌─────────────────┐   ┌─────────────────┐   ┌──────────────┐ │◀┘    │
│  │  │ FIDO2 Registry  │   │ Conditional     │   │ User Sign-In │ │     │
│  │  │ (Passkeys)      │   │ Access Policies │   │ Methods      │ │     │
│  │  └─────────────────┘   └─────────────────┘   └──────────────┘ │     │
│  └───────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Kleidia Requirements
- Kleidia deployed and accessible to users
- Local agent installed on user workstations
- YubiKey 5 series (or newer) with FIDO2 support

### Azure Entra ID Requirements
- Azure Entra ID Premium P1 or P2 license
- FIDO2 security key authentication method enabled
- User has appropriate licensing

## FIDO2 Registration Process

### Step 1: Set FIDO2 PIN in Kleidia

Before registering the YubiKey with Azure Entra ID, users must set a FIDO2 PIN:

1. Navigate to **Dashboard > YubiKeys** in Kleidia
2. Select the YubiKey to configure
3. Open the **FIDO2** management card
4. In the **PIN** tab, set a FIDO2 PIN (4-63 characters)

> **Note:** FIDO2 PIN is separate from PIV PIN. Users should track both.

### Step 2: Register Security Key with Azure Entra ID

1. Navigate to [Microsoft Security Info](https://aka.ms/mysecurityinfo)
2. Click **Add sign-in method**
3. Select **Security key**
4. Choose **USB device**
5. Follow the prompts:
   - Insert YubiKey when prompted
   - Enter FIDO2 PIN
   - Touch the YubiKey when LED flashes
6. Name the security key (e.g., "Work YubiKey - Kleidia Managed")

### Step 3: Verify Registration in Kleidia

After registration, the service domain should appear in Kleidia:

1. Navigate to the YubiKey in Kleidia
2. Open the **FIDO2** card
3. Go to the **Credentials** tab
4. Enter FIDO2 PIN to view registered services
5. Verify `login.microsoftonline.com` appears in the list

## Dual Deployment: PIV + FIDO2

Organizations can leverage both PIV and FIDO2 capabilities on the same YubiKey:

### Use Cases

| Authentication Scenario | Recommended Method |
|-------------------------|-------------------|
| Windows Smart Card Login | PIV Certificate |
| VPN/Network Access | PIV Certificate |
| Microsoft 365 | FIDO2 (WebAuthn) |
| Azure Portal | FIDO2 (WebAuthn) |
| Web Applications (SSO) | FIDO2 (WebAuthn) |
| Code Signing | PIV Certificate (9c) |
| Email Signing (S/MIME) | PIV Certificate (9d) |

### Best Practices for Dual Deployment

1. **PIN Management**
   - PIV PIN and FIDO2 PIN are independent
   - Consider using the same PIN for user convenience (but understand the security trade-off)
   - Document both PINs in user's password manager

2. **Certificate vs. Passkey**
   - Use PIV certificates for legacy systems and smart card requirements
   - Use FIDO2 for modern cloud services and phishing-resistant authentication

3. **Recovery Planning**
   - PIV: PUK can unblock locked PIN
   - FIDO2: No PUK equivalent; locked FIDO2 requires applet reset
   - Maintain backup authentication methods in Azure Entra ID

## Conditional Access Configuration

### Example Policy: Require FIDO2 for Sensitive Resources

```json
{
  "displayName": "Require FIDO2 Security Key for Azure Portal",
  "state": "enabled",
  "conditions": {
    "applications": {
      "includeApplications": [
        "Azure Portal"
      ]
    },
    "users": {
      "includeUsers": ["All"]
    }
  },
  "grantControls": {
    "operator": "AND",
    "builtInControls": [
      "mfa"
    ],
    "authenticationStrength": {
      "id": "00000000-0000-0000-0000-000000000004"
    }
  }
}
```

> **Note:** Authentication strength ID `00000000-0000-0000-0000-000000000004` corresponds to "Phishing-resistant MFA" which requires FIDO2 or certificate-based authentication.

### Creating a Custom Authentication Strength

To specifically require YubiKey FIDO2 authentication:

1. Navigate to **Entra Admin Center > Protection > Authentication methods > Authentication strengths**
2. Create a new custom strength
3. Select only **FIDO2 security key**
4. Optionally add **Certificate-based authentication** for PIV fallback
5. Use this custom strength in Conditional Access policies

## Troubleshooting

### Common Issues

#### "No security key registered" during sign-in

1. Ensure FIDO2 PIN is set in Kleidia
2. Verify key is registered at [aka.ms/mysecurityinfo](https://aka.ms/mysecurityinfo)
3. Check if FIDO2 method is enabled for the user in Entra ID

#### "Wrong PIN" error during registration

1. Verify you're using FIDO2 PIN (not PIV PIN)
2. Check FIDO2 PIN retries in Kleidia FIDO2 card
3. If locked, reset FIDO2 applet in Kleidia (erases all passkeys)

#### Registration fails with "Security key not supported"

1. Ensure YubiKey firmware supports CTAP 2.0+
2. Check browser compatibility (Chrome, Edge, Firefox supported)
3. Verify WebAuthn/FIDO2 is enabled in Azure Entra ID

#### User can't sign in after YubiKey deletion in Kleidia

When a YubiKey is deleted in Kleidia with factory reset:
1. All FIDO2 credentials are erased from the key
2. Azure Entra ID still shows the key as registered
3. User must manually remove the old key from [Security Info](https://aka.ms/mysecurityinfo)
4. Re-register the reset YubiKey as a new security key

### Diagnostic Commands

Check FIDO2 status on YubiKey (via ykman):
```bash
# List FIDO2 info
ykman fido info

# List registered credentials (requires PIN)
ykman fido credentials list
```

## Security Considerations

### Phishing Resistance

FIDO2/WebAuthn provides strong phishing resistance because:
- Credentials are bound to specific domain origins
- Private keys never leave the YubiKey
- Registration and authentication require physical presence (touch)

### PIN Protection

- FIDO2 PIN protects against stolen device scenarios
- 8 retry attempts before lockout
- Lockout requires FIDO2 applet reset (erases all credentials)

### Credential Management

- Kleidia provides visibility into registered RP domains
- Full usernames are not displayed for privacy
- Factory reset erases all FIDO2 credentials when YubiKey is deleted

## Related Documentation

- [Kleidia FIDO2 Management Guide](../05-using-the-system/fido2-management.md)
- [YubiKey Lifecycle Management](../05-using-the-system/yubikey-lifecycle.md)
- [Microsoft: Configure FIDO2 security keys](https://learn.microsoft.com/en-us/azure/active-directory/authentication/howto-authentication-passwordless-security-key)

