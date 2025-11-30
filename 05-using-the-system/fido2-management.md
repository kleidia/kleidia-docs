# FIDO2 Management Guide

This guide explains how to manage FIDO2/WebAuthn credentials on your Kleidia-managed YubiKey.

## What is FIDO2?

FIDO2 is a modern authentication standard that enables passwordless and phishing-resistant login to websites and applications. When you register your YubiKey with a service supporting FIDO2 (like Microsoft 365, Google, GitHub, etc.), you can log in by simply touching your YubiKey instead of typing a password.

## Accessing FIDO2 Management

1. Navigate to **Dashboard > YubiKeys**
2. Select the YubiKey you want to manage
3. Scroll down to the **FIDO2 / WebAuthn Management** card

## FIDO2 PIN Management

### Understanding FIDO2 PIN

The FIDO2 PIN is **separate from your PIV PIN**. You will need to manage both independently:

| PIN Type | Purpose | Length | Lockout |
|----------|---------|--------|---------|
| PIV PIN | Smart card operations, certificate signing | 6-8 digits | 3 retries, PUK to unlock |
| FIDO2 PIN | Passwordless login, WebAuthn | 4-63 characters | 8 retries, reset required |

### Setting Your FIDO2 PIN

If your YubiKey doesn't have a FIDO2 PIN set:

1. Go to the **PIN** tab in the FIDO2 card
2. Enter a new PIN (4-63 characters)
   - Can include letters, numbers, and symbols
   - Longer PINs provide better security
3. Confirm the PIN by entering it again
4. Click **Set PIN**

### Changing Your FIDO2 PIN

If your FIDO2 PIN is already set:

1. Go to the **PIN** tab in the FIDO2 card
2. Enter your current PIN
3. Enter your new PIN (4-63 characters)
4. Confirm the new PIN
5. Click **Change PIN**

### What If I Forget My FIDO2 PIN?

Unlike PIV, **FIDO2 has no PUK** for recovery. If you forget your FIDO2 PIN or exhaust all 8 retry attempts:

1. You must reset the FIDO2 applet
2. **All FIDO2 credentials will be permanently erased**
3. You will need to re-register with all services

## Viewing Registered Services

The **Credentials** tab shows which services have FIDO2 credentials registered on your YubiKey.

### To View Your Credentials:

1. Go to the **Credentials** tab
2. Enter your FIDO2 PIN
3. Click **View Credentials**

You will see a list of domains (service providers) where your YubiKey is registered. Common examples:
- `login.microsoftonline.com` - Microsoft 365/Azure
- `github.com` - GitHub
- `google.com` - Google accounts
- `login.salesforce.com` - Salesforce

> **Privacy Note:** Only domain names are displayed. Usernames and full credential details are not shown.

## Registering Your YubiKey with Services

To use FIDO2 authentication, you must register your YubiKey with each service. This is typically done in the service's security settings.

### Microsoft 365 / Azure Entra ID

1. Go to [aka.ms/mysecurityinfo](https://aka.ms/mysecurityinfo)
2. Click **Add sign-in method**
3. Select **Security key** > **USB device**
4. Insert your YubiKey and follow prompts
5. Enter your FIDO2 PIN when asked
6. Touch the YubiKey when the LED flashes

### GitHub

1. Go to **Settings > Password and authentication > Security keys**
2. Click **Add new security key**
3. Insert YubiKey and follow prompts
4. Name your key (e.g., "Kleidia YubiKey")

### Google

1. Go to [myaccount.google.com/security](https://myaccount.google.com/security)
2. Under **How you sign in to Google**, click **2-Step Verification**
3. Add a security key
4. Follow registration prompts

## Resetting FIDO2 Applet

> ⚠️ **Warning:** Resetting the FIDO2 applet **permanently erases all FIDO2 credentials**. You will lose access to all services registered with this YubiKey.

### When to Reset FIDO2

- FIDO2 PIN is locked (0 retries remaining)
- You want to clear all passkeys for re-provisioning
- Decommissioning the YubiKey

### How to Reset FIDO2

1. Go to the **Advanced** tab in the FIDO2 card
2. Click **Reset FIDO2 Applet**
3. Confirm the warning
4. **Important:** The reset must be performed within 5 seconds of inserting the YubiKey
5. If it fails, unplug the YubiKey, reinsert it, and try again immediately

After reset:
- FIDO2 PIN is cleared (you can set a new one)
- All passkeys are deleted
- You must re-register with all services

## YubiKey Deletion (Factory Reset)

When you delete a YubiKey from Kleidia, a **full factory reset** is performed:

| Applet | What Gets Erased |
|--------|------------------|
| **PIV** | All certificates, private keys, PIN, PUK, management key |
| **FIDO2** | All passkeys, FIDO2 PIN |
| **OTP** | All OTP slot configurations |
| **OATH** | All TOTP/HOTP credentials |

### After Deletion

- You will be locked out of all services using this YubiKey
- Services still show the key as registered (remove manually)
- The YubiKey can be re-registered as a fresh device

## Best Practices

### PIN Security

1. Use a strong, unique FIDO2 PIN
2. Store your PIN in a password manager
3. Don't reuse your PIV PIN as FIDO2 PIN (if possible)

### Credential Management

1. Keep a list of services where your YubiKey is registered
2. Regularly check the Credentials tab for unexpected entries
3. Report any unknown services to your IT security team

### Recovery Planning

1. Ensure backup authentication methods are configured for critical services
2. Document which services use FIDO2 vs PIV authentication
3. Consider registering a second YubiKey as backup

## Troubleshooting

### "PIN not set" warning

Your FIDO2 PIN hasn't been configured yet. Set it in the PIN tab before registering with services.

### "Wrong PIN" when registering with a service

Make sure you're using your **FIDO2 PIN**, not your PIV PIN. They are different!

### Can't see my credentials

- Ensure FIDO2 PIN is set
- Enter the correct PIN in the Credentials tab
- Try refreshing the page

### Reset fails with "timing error"

FIDO2 reset has strict timing requirements:
1. Unplug your YubiKey
2. Reinsert it
3. Click "Reset FIDO2 Applet" within 5 seconds
4. Touch the key when prompted

### Service still asks for password after registering YubiKey

- Check if the service has "passwordless" mode enabled
- Verify FIDO2 authentication is allowed in your organization's policies
- Try signing out and back in

## Related Guides

- [Azure Entra ID Integration](../03-deployment/azure-entra-integration.md)
- [YubiKey Lifecycle Management](yubikey-lifecycle.md)
- [PIV Certificate Management](piv-management.md)

