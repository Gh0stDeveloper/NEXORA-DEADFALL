# Security policy

This is a private game project. Do not disclose security-sensitive findings publicly before they are reviewed.

## Never commit

- Android keystores or signing passwords.
- VPS SSH keys or passwords.
- API keys, database service keys or tokens.
- Production room/match service credentials.
- Private player data or production logs containing identifiers.

## Multiplayer threat model

Clients are untrusted. Server code must validate movement, fire cadence, ammunition, damage, inventory, match actions and RPC rate. Security checks should fail closed and produce bounded diagnostic logs.

## Reporting

Use a private repository issue or direct project-maintainer channel for vulnerabilities. Include reproduction steps, affected commit/version and expected impact.
