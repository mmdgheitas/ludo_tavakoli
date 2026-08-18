# Security model

## Controls in source

- Short-lived JWT access tokens and rotating, hashed refresh sessions.
- Bans checked on every authenticated HTTP request; refresh sessions revoked on ban.
- Global and sensitive-route throttles, validation whitelist and unknown-field rejection.
- Prisma parameterization, strict DTOs, Helmet, explicit CORS and no raw client SQL.
- Cryptographic server dice (`crypto.randomInt`), server-only movement/winner/reward logic.
- Redis token locks plus PostgreSQL optimistic versions for concurrent commands.
- Receipt hashes, provider transaction uniqueness, server catalog and fail-closed verification.
- Role guards on analytics/admin routes and immutable admin audit records.
- No free-text chat and no client-provided reward values.
- Zero known npm audit findings at the time of implementation.

## Modified APK posture

A modified client can automate requests or alter visuals, but it cannot choose dice, move out of turn, mint coins, activate VIP, reuse Fattah, define chat text or validate its own receipt. This is the primary anti-cheat boundary.

For release, add Play Integrity for Google Play builds and the available equivalent/signature attestation for Bazaar/Myket as a risk signal. Do not make attestation the sole authentication mechanism; verify package name, signing certificate digest, nonce, timestamp and replay. Rate-limit by user/device/IP, detect impossible command cadence and retain evidence before sanctions.

## Production checklist

- Generate independent 32+ byte JWT secrets in a secret manager; never place them in APK or Git.
- TLS 1.2+ end to end; pinning may be defense-in-depth but must support certificate rotation.
- Admin behind MFA SSO/VPN; bootstrap password disabled or rotated.
- Provider credentials server-side only; verify documented Bazaar/Myket response signatures and consumption state in concrete adapters.
- Signed upload URLs, MIME/content scanning and fixed-size avatar transforms.
- PostgreSQL least-privilege users, encrypted backups and tested restore.
- Redis authentication/TLS and no public network exposure.
- Central redaction-aware logs, alerts on payment failures, reward spikes, lock conflicts and auth abuse.
- Independent penetration test and marketplace privacy/data-retention review before launch.

## Reporting

Do not open a public issue containing an exploit, token or receipt. Use the product owner’s private security contact and include reproduction steps with secrets redacted.
