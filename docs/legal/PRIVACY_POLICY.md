# NEXORA: DEADFALL Closed Beta Privacy Notice

Effective for the closed beta build `0.9.0-beta.1`.

## Data processed by the game

NEXORA: DEADFALL uses network data required to provide multiplayer sessions, including transient connection information, room/session identity, player display name, gameplay state and reconnect identity. The dedicated server processes these values to run the authoritative game session.

The beta build also creates local diagnostic data on the player's device. This can include app/build version, device model, operating-system version, processor/memory information, renderer/GPU information, game subsystem breadcrumbs and whether the previous session ended cleanly. These beta diagnostics are stored locally by default and are not automatically uploaded by the game.

## Sensitive values

The beta diagnostic layer is designed to omit resume tokens, passwords, secrets, host/address fields and IP fields from its event payloads. Network infrastructure may still necessarily process an IP address to establish an Internet connection.

## Microphone and voice

Voice chat is not implemented in this closed-beta build. The game does not request microphone access for the deferred voice-chat design.

## Advertising, purchases and sale of data

This beta build contains no advertising and no in-app purchases. The project does not sell beta diagnostic data to advertisers.

## Retention

Gameplay session state is transient unless needed for the short reconnect window. Local Campaign checkpoints and beta diagnostic files remain on the device until replaced, cleared by the app, or the app's storage is removed. Operational server logs should be retained only as long as reasonably necessary for beta security and reliability investigation.

## Tester reports

A tester may choose to provide screenshots, videos or diagnostic bundles when reporting a bug. Testers should remove unrelated personal information before sharing those files.

## Changes

This notice must be re-reviewed before adding accounts, analytics upload, crash-reporting providers, voice chat, advertising, purchases or other data-processing features.

## Contact

Closed-beta privacy questions should use the official support/contact channel supplied with the beta invitation.
