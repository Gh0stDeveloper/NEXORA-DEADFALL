# Portal deployment recovery and main integration — 2026-09-16

The owner explicitly requested merging `agent/bootstrap-deadfall` into `main`.
That authorization supersedes the earlier Draft-only restriction for PR #1.
Use `main` for installation and VPS updates after this integration. The branch
and PR history are retained; no force push, signing-key replacement or version
bump is part of this change.

## Reported failure

The VPS update at `eea4df40ae5ec46c711bb34f0ba159a75818cfee` passed the Android
template sanitizer and Godot compile/assets/account/gameplay/mobile/lifecycle,
project, closed-beta and Phase 11 gates. Next.js built successfully, but the
updater stopped with HTTP 404 before running Android export.

The generated routes were `/versions` and `/versions/[version]`, while the portal
links and VPS probes requested `/versiones`. The initial connection refusal on
3100 occurred during service startup and was retried. The ADB daemon message on
5037 was not a failing gate.

An additional regression exposed a catalog validation mismatch: historical
beta.1 has `version_code: null`, as allowed by the publisher and TypeScript model,
but the runtime reader rejected the entire catalog. This silently fell back to
seed data and hid the live APK hash/size after publication.

## Corrections

- Spanish `/versiones` routes are canonical; the previous English index/detail
  URLs permanently redirect to them.
- Runtime catalog validation accepts unknown historical version codes.
- Dynamic filesystem reads explicitly exclude the external history file from
  Turbopack tracing, eliminating the whole-project NFT warning while retaining
  live reads after APK publication.
- `deploy/vps/lib/portal.sh` supplies the route validator used by both the actual
  updater and the portal regression. Failures identify the requested URL and
  missing content. HTML is read fully before matching to avoid pipefail/SIGPIPE
  failures from an early-exiting grep.
- Expected startup connection refusals no longer print as deployment errors.
- TypeScript includes Next.js development types without rewriting tsconfig on
  each build.
- Installation docs now use main and explain switching an existing installation.

## Validation completed locally

Node 24.19.0, Next.js 16.2.11, Linux:

- `bash scripts/ci/vps_installer_smoke.sh` passed.
- `bash scripts/ci/download_portal_smoke.sh` passed, including the production
  Next.js/TypeScript build and the copied standalone server with its static and
  public assets.
- The same route validator as the VPS passed homepage, history, current detail,
  catalog, integrity hash and unknown-version 404 checks.
- Legacy index/detail redirects returned 308; compatibility, beta, favicon and
  the generated stylesheet returned successfully.
- An isolated runtime catalog was changed after server startup. JSON and the
  rendered detail page reflected its new summary, size and SHA without rebuilding
  or restarting. The fixture includes the historical null version code.
- The first run of this stronger test reproduced the discarded runtime catalog;
  it passed after the nullable-version-code correction.

The existing GitHub Actions portal job invokes this regression. Remote Actions
has previously failed before assigning runners; inspect the new commit's runs
without treating that infrastructure state as executed source validation.

## Resume the user's VPS update

```bash
sudo sed -i "s|^DEADFALL_BRANCH=.*|DEADFALL_BRANCH='main'|" /etc/nexora-deadfall/nexora-deadfall.env
sudo nexora-deadfall update --force
```

The updater fetches the configured branch and reexecutes its new version before
validation/build. Successful completion publishes
`/var/www/nexora-deadfall/downloads/NEXORA-DEADFALL-latest.apk`.

No VPS execution, new Android export or physical-device acceptance is claimed by
this local fix. The last confirmed production deployment remains
`f402f1696c0438447d76236122a5d82101a94cc0` until the user confirms the resumed build.
Version `0.9.0-beta.5 / 900005`, protocol 2, API 36 and the pinned Objetos3D source
remain unchanged.
