# Google Play Data Safety preparation notes

This is an engineering inventory, not a substitute for the final Play Console declaration.

## Current beta behavior

- Multiplayer necessarily transmits connection/session traffic to the dedicated game server.
- Player display name, room/session identity and authoritative gameplay state are processed for online play.
- A reconnect token is stored locally and exchanged for reconnect functionality; it must be treated as a session credential.
- Campaign checkpoint data is stored locally.
- Beta device/runtime diagnostics are stored locally by default and are not automatically uploaded by the application.
- There is no advertising SDK, analytics-upload SDK, in-app purchase SDK or voice-chat transport in `0.9.0-beta.1`.

## Verification before submission

Before filling the Play Data Safety form, inspect the exact release dependency/export output and server behavior. If a crash/analytics provider, account system, voice chat, purchase system or other SDK is added later, reassess the declaration before shipping that build.
