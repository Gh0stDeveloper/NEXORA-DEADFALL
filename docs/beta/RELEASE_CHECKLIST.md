# Closed Beta release checklist

## Code gates

- [ ] Current branch imports cleanly in Godot 4.6.3.
- [ ] Project/combat/zombie/gore/Horde/network/Squad/Campaign/Beta hardening smoke tests pass.
- [ ] Two-peer and four-peer integration tests pass.
- [ ] Campaign four-peer integration passes.
- [ ] Dedicated Docker server boots and publishes build metadata.

## Signing and artifacts

- [ ] Persistent upload keystore exists outside the repository.
- [ ] GitHub Secrets are configured for keystore base64, alias and password.
- [ ] `Android Closed Beta` AAB exports successfully.
- [ ] Direct-test APK exports successfully.
- [ ] AAB/APK signature verification passes.
- [ ] `SHA256SUMS.txt` and `release-manifest.json` match delivered binaries.
- [ ] Version code is greater than every previously distributed beta.

## Android / device gates

- [ ] Compatibility matrix contains representative low/mid/high devices.
- [ ] 20+ minute thermal/FPS soak on representative devices.
- [ ] Wi-Fi and mobile-data Squad sessions tested.
- [ ] Background/foreground and reconnect tested.
- [ ] No unresolved launch blocker, save-loss blocker, ANR or repeatable crash.

## Store/compliance

- [ ] Privacy notice reviewed and published at the beta distribution location.
- [ ] Beta terms and code of conduct reviewed.
- [ ] Play listing copy/screenshots/changelog reviewed.
- [ ] Content rating questionnaire completed in Play Console from the notes in this repo.
- [ ] Data Safety answers verified against the actual shipped build and server behavior.
- [ ] Tester eligibility/testing-duration requirements for the specific Play developer account are satisfied.

## Release decision

Ship only when all applicable code, signing, device and policy gates are checked. CI definitions existing in the repository are not equivalent to successful execution.
