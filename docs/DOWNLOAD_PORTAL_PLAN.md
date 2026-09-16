# NEXORA: DEADFALL — Download Portal Plan

Last updated: 2026-09-11.

## Objective

Upgrade the existing beta download page from a single current-build card into the official public release/history portal for NEXORA: DEADFALL.

Current code lives in:

```text
web/download-site
```

The APK build writes current runtime metadata to:

```text
/var/www/nexora-deadfall/release.json
```

The portal consumes the durable generated catalog:

```text
/var/www/nexora-deadfall/releases.json
```

The existing page already displays current version, APK size, SHA-256 and a download button. The next iteration must preserve that reliable download path while adding version history and richer release information.

## UX direction

The portal should remain mobile-first, fast and visually consistent with DEADFALL. It should not expose internal server implementation details.

Primary header:

- NEXORA: DEADFALL branding.
- Current Closed Beta badge/status.
- Hamburger menu.
- Clear current-version download action.

The hamburger menu should open a mobile drawer/sheet with navigation such as:

- Inicio.
- Última versión.
- Historial de versiones.
- Cambios y correcciones.
- Requisitos/compatibilidad.
- Información de la beta.
- Privacidad/Términos if public legal routes are added.

Do not use emoji as product UI icons. Use proper vector/icon components.

## Version history requirement

Every public build should have a durable release record. The user must be able to select a version and see:

- version name;
- versionCode where appropriate;
- publication date;
- channel (`closed_beta`, later stable/test channels if needed);
- status: current / superseded / withdrawn;
- short summary;
- new features;
- fixes;
- networking/server changes;
- Android/performance changes;
- known limitations;
- compatibility requirement;
- APK size;
- SHA-256;
- optional Git commit/release identifier;
- download availability.

Older APKs should only remain downloadable if intentionally preserved. The portal history must still show their changelog even when the binary itself is no longer downloadable.

## Proposed public data model

Do not make the web UI scrape Markdown at runtime. The deployment/build pipeline should publish machine-readable release history derived from maintained source records.

Suggested public file:

```text
/var/www/nexora-deadfall/releases.json
```

Suggested structure:

```json
{
  "schema_version": 1,
  "current": "0.9.0-beta.5",
  "releases": [
    {
      "version": "0.9.0-beta.5",
      "version_code": 900005,
      "channel": "closed_beta",
      "published_unix": 0,
      "status": "current",
      "summary": "Dedicated match lifecycle and recovery.",
      "added": [],
      "fixed": [],
      "changed": [],
      "known_issues": [],
      "min_client_version_code": 900005,
      "protocol": 2,
      "content_version": 1,
      "bytes": 0,
      "sha256": "...",
      "git_sha": "...",
      "download": "/downloads/NEXORA-DEADFALL-latest.apk"
    }
  ]
}
```

Source Markdown release notes remain the human-maintained canonical detail under `docs/beta/`. A small build script can convert a structured source file or release manifest into the public JSON; do not hand-edit production history directly on the VPS.

## Recommended source-of-truth design

Add a tracked source record, for example:

```text
docs/beta/releases.json
```

or a TypeScript/JSON data module under the web app. Each release entry should reference the corresponding Markdown release notes for maintainers.

The VPS updater should:

1. build/sign APK;
2. compute size/SHA-256;
3. write/update `release.json` for the current build;
4. append/merge the current release into the durable public history dataset;
5. preserve old history entries;
6. rebuild/restart the portal when web/history source changes;
7. validate current version and history endpoints before marking deploy successful.

## Planned routes/components

Suggested App Router structure:

```text
web/download-site/src/app/
  page.tsx
  versions/page.tsx
  versions/[version]/page.tsx
  compatibility/page.tsx
  beta/page.tsx
  components/
    Header.tsx
    MobileMenu.tsx
    ReleaseCard.tsx
    ReleaseTimeline.tsx
    IntegrityBlock.tsx
    DownloadButton.tsx
```

Exact structure may change after implementation, but responsibilities should remain separated.

## Home page v2

The home page should show:

- current version prominently;
- current build status;
- download button;
- size;
- SHA-256/integrity toggle;
- release summary;
- a short “Qué cambió” section;
- link/button to full version details;
- compatibility note;
- beta warning;
- link to version history.

Keep the stable APK route unchanged unless there is a migration reason:

```text
/downloads/NEXORA-DEADFALL-latest.apk
```

## Hamburger menu behavior

Requirements:

- visible on mobile;
- icon-based trigger;
- drawer/sheet closes on route selection;
- keyboard/focus accessible where applicable;
- body scrolling handled correctly while open;
- no layout shift;
- active route indication;
- current version can optionally be shown in the drawer footer.

## Version detail page

Example route:

```text
/versions/0.9.0-beta.5
```

Sections:

1. header/version/status;
2. summary;
3. added;
4. changed;
5. fixed;
6. networking/server;
7. Android/performance;
8. known limitations;
9. compatibility;
10. integrity/download.

Release entries should be readable without requiring the APK to exist.

## Initial release history to expose

Tracked release notes currently exist for:

- `0.9.0-beta.1`;
- `0.9.0-beta.4`;
- `0.9.0-beta.5`.

Beta.4 includes the presentation/performance/model-animation pass and carried forward the major beta.3 gameplay/network work.

Beta.5 includes dedicated-match lifecycle/reconnect/heartbeat/result handling.

Before publicly presenting beta.2 and beta.3 as detailed historical releases, reconstruct their exact changelog from Git history/deployment records. Do not invent details that cannot be verified.

## Current version: beta.5

The portal history must record that `0.9.0-beta.5 / 900005` was successfully built and published from runtime deployment anchor:

```text
f402f1696c0438447d76236122a5d82101a94cc0
```

Production verification included APK Signature Scheme v2, one signer and successful localhost/HTTPS API validation.

## Security/privacy requirements

Never publish:

- match tickets;
- guest authentication secrets/verifiers;
- internal PIDs;
- private match config paths;
- signing keystore details/secrets;
- GitHub tokens;
- internal-only control API addresses beyond already-public architecture documentation;
- tester private identifiers.

SHA-256 of a public APK is intended to be public.

## SEO/share metadata later

Add clean public metadata when portal redesign is implemented:

- title/description per release;
- Open Graph metadata;
- canonical URLs;
- favicon/app branding;
- version-specific share cards later if useful.

Do not expose internal implementation notes in user-facing descriptions.

## Build/deployment requirements

A portal change must remain independently deployable without rebuilding the Android APK when application code did not change.

Expected flow:

```bash
nexora-deadfall build-web
```

or differential updater classification through:

```bash
sudo /opt/nexora-deadfall/deploy/vps/update.sh
```

The updater must continue to restart only the affected portal service for web-only changes.

## Validation gates to add with the redesign

- Next.js production build passes.
- Current release metadata loads.
- History metadata validates against schema.
- Current release exists in history exactly once.
- Version route returns the correct release.
- Invalid version returns a clean 404/not-found state.
- Hamburger menu renders and links to required routes.
- Stable APK link remains correct.
- SHA-256 shown by portal matches published APK.
- Nginx route remains healthy over HTTPS.
- Mobile viewport smoke/screenshots on at least one real Android browser.

## Implementation order

Do not let portal work hide gameplay blockers. Recommended order after beta.5 automated deployment:

1. complete physical beta.5 acceptance and record blockers;
2. fix any critical game/network blocker first;
3. add release-history source schema/data;
4. update updater/build pipeline to publish durable history;
5. implement shared header + hamburger drawer;
6. implement version list/timeline;
7. implement version detail route;
8. redesign current-build home card;
9. add compatibility/beta information pages;
10. add web tests/build gates;
11. deploy with web-only update and verify HTTPS.

If physical testing reveals no critical blocker, portal work can be the next contained development block.