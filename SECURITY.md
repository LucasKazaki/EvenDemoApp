# Security Policy

## Current credential notice

Earlier commits in this public repository contained provider API keys as source-code defaults. The Agent Studio branch removes those defaults, but removing a key from the latest file does not remove it from Git history.

Treat every previously committed provider key as compromised:

1. Revoke or rotate it at the provider.
2. Review its recent usage and billing.
3. Remove it from local configuration files and build scripts.
4. Consider rewriting public Git history after rotation if keeping the old value discoverable is undesirable.

Never reuse the exposed values.

## Mobile credential model

The G1 companion stores only a device-scoped Agent Studio token. It does not store cloud-model API keys or a general-purpose password-vault export.

The device token is stored with platform secure storage:

- iOS and macOS: Keychain.
- Android: Keystore-backed encrypted storage.
- Windows and Linux: The secure-storage backend supplied by the Flutter plugin.

The iOS configuration uses `first_unlock_this_device`, so the token is unavailable after reboot until the phone has been unlocked once and does not migrate to another device through ordinary backup restoration.

## Token scopes

A G1 token should permit only:

- Sending a user message.
- Reading the paired user's authorized event stream.
- Reading concise project and task status.
- Receiving informational approval notices.

A G1 token should not permit:

- Exporting or revealing passwords.
- Reading unrelated files or projects.
- Executing shell commands directly.
- Modifying Agent Studio policy.
- Creating new administrator credentials.
- Approving purchases, messages, applications, releases, destructive changes, or security changes.

## Transport

Use HTTPS and secure WebSockets. The recommended deployment exposes a localhost Agent Studio service privately through Tailscale or another authenticated private network. Do not expose an unauthenticated development server directly to the public internet.

For local development, HTTP may be used only on a trusted private network. Production pairing should reject plaintext transport.

## Browser sessions and saved passwords

Agent Studio should use dedicated automation browser profiles with persistent authenticated sessions. It may let Chrome perform normal autofill inside that profile. It should not scrape, decrypt, export, or copy the Google Password Manager database.

Account safeguards such as passkey confirmation, Windows Hello, Face ID, multifactor authentication, CAPTCHA, first-time consent, and account recovery remain human-presence boundaries. The orchestrator should pause and present the exact required step rather than attempting to bypass it.

## Approval integrity

Consequential approvals should contain:

- Exact action type.
- Exact target.
- Exact parameters.
- Human-readable consequence.
- Expiration time.
- One-time nonce.
- Hash of the action payload.

Changing any material parameter after approval invalidates the approval.

## Reporting vulnerabilities

Do not open a public issue containing credentials, private endpoints, access tokens, browser cookies, or sensitive logs. Revoke exposed credentials first, then use a private communication channel with the repository owner.
