# Security boundaries

The service enforces citizen-only signup, issued staff, revocable sessions, role/assignment checks, evidence ownership, idempotent retries, fresh distinct crew proof and officer closure. Protected photos require authorization and no-store responses.

Passwords use salted scrypt; refresh tokens/OTP codes are digested. Login lockout, OTP expiry/attempt/cooldown rules and persisted session revocation are implemented. Service-edge rate limiting, jurisdiction enforcement and an independent audit remain deployment work.

GPS/time are client assertions; hashing does not authenticate a scene. Audit records are mutable by database administrators. Web storage cannot protect a compromised origin; native device security requires review. Automatic Android backup is disabled for encrypted storage compatibility.

Public fixture passwords/accounts are for a loopback demo. Deployment rejects fixture coordinates and requires SMTP, PostgreSQL/private JWT material; operators must also provide HTTPS, access controls, backups and retention. Private runtime state is ignored by Git.

Use GitHub private vulnerability reporting if enabled or an arranged private maintainer contact. Do not post live credentials, identifiable photos or operational exploits publicly. Rotate exposed credentials through the operator's incident process.
