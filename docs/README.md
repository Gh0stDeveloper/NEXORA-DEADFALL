# NEXORA: DEADFALL — Documentation Index

Last updated: 2026-08-17.

Use this file to decide which documents represent the current project state.

## Current authoritative documents

Read these first, in this order:

1. **`HANDOFF_BETA_5.md`** — exact continuation point for a new development chat, including the copy/paste prompt.
2. **`CURRENT_STATUS.md`** — current runtime/version/deployment and immediate next gate.
3. **`ROADMAP.md`** — completed work, pending work and ordered future phases.
4. **`DOWNLOAD_PORTAL_PLAN.md`** — planned redesign of the public download/version-history portal.
5. **`beta/RELEASE_HISTORY.md`** — maintainers' release history/index.
6. **`PROJECT_CONTEXT.md`** — durable product/architecture/workflow rules.

If an older planning document conflicts with one of the above, the documents above win unless source/current runtime evidence says otherwise.

## Product/game design

- `GDD.md` — game design document.
- `ARCHITECTURE.md` — technical architecture.
- `COMBAT.md` — combat system.
- `ZOMBIE_AI.md` — zombie AI.
- `HORDE.md` — Horde/rounds.
- `GORE.md` — gore/dismemberment.
- `CAMPAIGN.md` — Campaign framework/content.

## Networking / online

- `NETWORKING.md`
- `NETWORK_DUO.md`
- `NETWORK_SQUAD.md`
- `NETWORK_AUTHORITY_AND_MATCHMAKING.md`
- `VOICE_CHAT_DESIGN.md` — future/deferred voice design only.

Current lifecycle/reconnect state should also be read from `CURRENT_STATUS.md` and `HANDOFF_BETA_5.md` because they postdate the original networking phases.

## Android / beta / release

- `ANDROID.md`
- `ANDROID_VALIDATION.md`
- `BETA_HARDENING.md`
- `QUALITY_GATES.md`
- `beta/COMPATIBILITY_MATRIX.md`
- `beta/RELEASE_CHECKLIST.md`
- `beta/TESTER_GUIDE.md`
- `beta/RELEASE_HISTORY.md`
- `beta/RELEASE_NOTES_0.9.0-beta.1.md`
- `beta/RELEASE_NOTES_0.9.0-beta.4.md`
- `beta/RELEASE_NOTES_0.9.0-beta.5.md`

Detailed beta.2/beta.3 public changelogs must be reconstructed from Git/deployment history before being presented as exact release notes.

## VPS / production

- `VPS_INSTALLER.md` — current managed VPS runbook.
- `SERVER_UBUNTU.md` — server notes.
- `THIRD_PARTY_3D_ASSETS.md` — external model/source information.

Current production runtime anchor is documented in `CURRENT_STATUS.md` rather than inferred from a random repository HEAD.

## Public web/download portal

- `DOWNLOAD_PORTAL_PLAN.md` — authoritative future portal plan.
- source: `../web/download-site/`

Planned major additions:

- hamburger menu;
- durable release/version history;
- version detail routes;
- features/fixes/changes/known limitations;
- compatibility information;
- APK integrity metadata;
- current/superseded/withdrawn release states.

## Legal/store preparation

- `legal/PRIVACY_POLICY.md`
- `legal/TERMS_OF_BETA.md`
- `legal/CODE_OF_CONDUCT.md`
- `store/PLAY_LISTING.md`
- `store/DATA_SAFETY_NOTES.md`
- `store/CONTENT_RATING_NOTES.md`

## ADRs

- `adr/0001-shared-authority-model.md`
- `adr/0002-enet-dedicated-server.md`

Architecture decisions remain binding unless superseded by a later documented decision/source change.

## Historical planning/handoffs

These files are retained to preserve the project's evolution but **are not the starting point for current work**:

- `PHASE_11_PLAN.md`
- `HANDOFF_PHASE_11_3.md`

They describe earlier milestones before the currently deployed beta.5 lifecycle.

## Runtime vs documentation HEAD

The repository branch may advance through documentation-only commits. Do not assume the latest Git HEAD is the runtime currently deployed to production.

The current runtime deployment anchor and current source/version must always be checked in:

- `CURRENT_STATUS.md`;
- `src/release/BuildInfo.gd`;
- actual VPS deployment output when making a new runtime claim.

## New chat rule

For a new AI development session, start with `HANDOFF_BETA_5.md` and use its prompt. Then fetch current branch/PR state before making changes.