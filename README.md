# Fermo

Fermo is a native macOS focus blocker planned for personal dogfooding and later Toolary distribution.

The first milestone is intentionally engineering-first: prove the focus-blocking model, schedule logic, focus-contract invariants, and macOS integration feasibility before investing in the final Claude Design pass.

The product difference is not "stricter blocker." Fermo is built around a focus contract:

- one task;
- intended outcome;
- local offline preset;
- Blocklist Mode or Focus Room Mode;
- Soft, Locked, or Emergency rigor;
- proof or not-done reason;
- local Markdown evidence log.

## Current Shape

- `FermoCore`: focus contracts, blocklists, domain/app rules, sessions, schedules, rigor policy, evidence logs, and local persistence.
- `FermoSystem`: macOS integration adapters for Network Extension, app interruption, helper registration, and shared app-group state.
- `FermoApp`: native SwiftUI/menu-bar dogfood app split into a small app shell, view model, navigation, screen files, reusable components, and system-extension approval adapter.
- `FermoHelper`: background helper executable used by the helper-persistence spike.
- `Fermo.xcodeproj`: signed macOS app + Network Extension + embedded Login Item helper handoff.
- `FermoFilterExtension`: macOS Network Extension `filter-data` provider target source.
- `docs/`: PRD, roadmap, technical spike, design brief, goal prompt, release notes, runtime matrix, and beta release runbook.

## Network Extension Spike

The first signed-build spike is scoped to blocking `reddit.com` and `youtube.com`. Manual signing, entitlement, and macOS approval steps are documented in `docs/macos-network-extension-signing.md`.

Local signed build `0.1.0/3` reaches `activated enabled` and blocks reddit/YouTube while allowing other domains. Firefox, private/incognito windows, Wi-Fi changes, sleep/wake, and reboot restore remain manual checks before any beta claim. The current Toolary beta checklist is `docs/toolary-beta-runtime-matrix.md`.

If macOS does not show an approval prompt, that usually means the System Extension approval already exists. Approval prompts are first-run or replacement events, not something to expect on every launch. Verify with `systemextensionsctl list`; when `com.toolary.fermo.filter` is `[activated enabled]`, start the website spike and check provider logs instead of waiting for another prompt.

## App Interruption Spike

The second signed-build spike interrupts a selected running app by bundle identifier during an active focus session. The local safe target is Calculator. Findings and the sandbox/non-sandbox decision are documented in `docs/macos-app-interruption-spike.md`.

## App Guard Spike

Toolary beta now requires Endpoint Security app launch enforcement, not only user-space interruption. `FermoAppGuardExtension` is embedded as a System Extension and the native app exposes App Guard approval in System Health, Preferences, and the menu bar. Signing, entitlement, approval, and launch-deny validation steps are documented in `docs/macos-endpoint-security-signing.md`.

System Health and Preferences also show a shared runtime onboarding checklist for website-filter approval, App Guard approval, and Login Item readiness.
The prepared Apple entitlement request draft is `docs/apple-endpoint-security-entitlement-request.md`.
The signed beta operator runbook is `docs/toolary-beta-release-runbook.md`.
Export the Apple Endpoint Security request packet with `scripts/export-endpoint-security-request-packet.sh <output-dir>`.
Export a signing-Mac operator packet with `scripts/export-signed-beta-operator-packet.sh <output-dir>`.
Both packet export commands require empty output directories and their checkers compare exported source-document copies back to the repository files so stale files are not mixed into Apple or signing-Mac evidence.

## Helper Persistence Spike

The third signed-build spike packages `FermoHelper.app` under `Fermo.app/Contents/Library/LoginItems` and registers it with `SMAppService.loginItem(identifier:)`. The first helper policy is intentionally scoped to reddit, YouTube, and Calculator. Manual signing and Login Items approval steps are documented in `docs/macos-helper-persistence-spike.md`.

Local signed build `0.1.0/3` keeps `FermoHelper` running after the main app quits, interrupts Calculator, and keeps the already-enabled content filter effective. Sleep/wake and reboot/login restore remain unverified.

## Dogfood UI

The native app can now start a real focus contract from local presets instead of only launching spike samples. The flow writes a `FermoCore` policy, activates the content filter path, starts app interruption, and records proof/break-glass entries into the local evidence log. Focus Room app interruption now uses the active policy allowlist with explicit exclusions for Fermo and critical macOS shell apps.

Active Session is now the dogfood control surface: timer, runtime health, rule boundary, Soft stop with reason, Locked/Emergency break-glass, proof-due state, and `LockedModeGuard`-backed rule edit locking.

Rooms/blocklists, custom Focus Room allowlists, one-off start-later sessions, recurring weekly schedules, Markdown evidence export, Preferences, System Health, App Guard approval entry points, diagnostics copy, and local release guardrails are implemented for dogfood/dev validation. Toolary beta status is still blocked until the signed/notarized `/Applications/Fermo.app` passes the full runtime matrix with Endpoint Security approval.

## Run Checks

```sh
scripts/check-local-release-readiness.sh
```

The local readiness script expands to:

```sh
scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json
scripts/check-release-copy.sh
scripts/check-endpoint-security-request.sh
scripts/check-endpoint-security-request-packet.sh
scripts/check-beta-release-runbook.sh
scripts/check-runtime-matrix-template.sh
scripts/check-beta-blocker-audit.sh
scripts/check-signed-beta-operator-packet.sh
scripts/check-app-copy-guardrails.sh
scripts/check-release-guardrails.sh
scripts/check-xcode-entitlements.sh
swift test
swift build
xcodebuild -project Fermo.xcodeproj -scheme Fermo -destination 'platform=macOS' -derivedDataPath /tmp/FermoPlanDerivedData CODE_SIGNING_ALLOWED=NO build
FERMO_SKIP_SIGNATURE_CHECKS=1 scripts/verify-beta-candidate.sh /tmp/FermoPlanDerivedData/Build/Products/Debug/Fermo.app
scripts/check-dogfood-package-flow.sh /tmp/FermoPlanDerivedData/Build/Products/Debug/Fermo.app
```

## Candidate Packaging

Unsigned dogfood/dev packaging can produce a ZIP, SHA-256 file, and manifest for local validation:

```sh
scripts/check-dogfood-package-flow.sh /tmp/FermoPlanDerivedData/Build/Products/Debug/Fermo.app
```

The dogfood package-flow check expands to:

```sh
FERMO_SKIP_SIGNATURE_CHECKS=1 scripts/package-beta-candidate.sh /tmp/FermoPlanDerivedData/Build/Products/Debug/Fermo.app /tmp/fermo-release
scripts/prepare-beta-runtime-matrix.sh /tmp/fermo-release/Fermo-0.1.0-3-dogfood-dev-manifest.md docs/toolary-beta-runtime-matrix.md /tmp/fermo-release/Fermo-0.1.0-3-dogfood-dev-runtime-matrix.md
```

`scripts/prepare-beta-runtime-matrix.sh` refuses incomplete or checksum-mismatched manifests before writing a matrix draft, and the runtime matrix output must not already exist or physically resolve inside the app bundle so manual matrix work is not overwritten and the signed app is not mutated.

For Toolary beta packaging, follow `docs/toolary-beta-release-runbook.md`: use a signed and notarized app installed exactly at `/Applications/Fermo.app`, keep signature checks enabled, replace every required runtime matrix `Status` cell with `Passed` or `passed`, and set `FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed` only after the runtime matrix has passed. `FERMO_RELEASE_CHANNEL` is limited to `dogfood-dev` or `beta`, `FERMO_RUNTIME_MATRIX_STATUS` is limited to `pending` or `passed`, and `FERMO_SKIP_SIGNATURE_CHECKS` is limited to `0` or `1`, so packaging fails fast on release-env typos. Beta packaging also requires a real numeric dot-separated version and build from the app `Info.plist` or explicit `FERMO_RELEASE_VERSION` / `FERMO_RELEASE_BUILD`, plus a real git commit SHA and clean git tree in the manifest; only dogfood/dev artifacts may fall back to `0.0.0/0`, and beta rejects those placeholder values even when passed explicitly.
The candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging so the generated ZIP, `.sha256`, and manifest are not mixed with stale artifacts or copied back into the submitted app. Candidate checksum files must contain exactly one ZIP entry for the generated ZIP basename.
`scripts/check-release-copy.sh` protects the EN/PL/DE release notes and Toolary copy drafts, including their version plus localized catalog title/short-description match with Toolary metadata. `scripts/check-endpoint-security-request.sh` checks the Apple Endpoint Security request packet against the current bundle IDs and privacy scope, `scripts/check-endpoint-security-request-packet.sh` exports that packet and validates exact copied request, signing checklist, entitlements, and Xcode/App Guard source summary before it goes to Apple, `scripts/check-xcode-entitlements.sh` checks source entitlements, expected bundle identifiers, and consistent Xcode `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` across app, helper, and extension targets, `scripts/check-runtime-matrix-template.sh` protects the required signed runtime checklist scope, including Content Filter and App Guard diagnostic snapshot rows, `scripts/check-app-copy-guardrails.sh` keeps in-app copy from overclaiming beta readiness or showing stale spike wording and keeps copyable Content Filter/App Guard diagnostics visible, `scripts/check-candidate-manifest-app.sh` verifies that the manifest `App path`, `Version`, and `Build` match the candidate `.app`, `scripts/verify-beta-candidate.sh` rejects extra arguments, verifies the app plus each embedded extension/helper signature when signature checks are enabled, and always checks embedded bundle identifiers and package types, and `scripts/check-release-guardrails.sh` codifies the negative release checks: beta packaging refuses skipped signatures, pending matrices, non-`/Applications/Fermo.app` paths, missing version/build metadata, and placeholder `0.0.0/0` values, signed readiness and signed runtime approval checks refuse skipped signature checks and app paths other than `/Applications/Fermo.app`, Endpoint Security request packet export rejects malformed invocation and validates copied packet contents, beta release gate rejects missing or non-`/Applications/Fermo.app` manifest app paths, non-canonical ZIP basenames, placeholder manifest version/build values, non-passing matrix statuses, missing Content Filter/App Guard diagnostic rows or ready evidence, manifest/matrix channel, version, date, git, app path, ZIP, SHA, Toolary publishable, checksum hash, or checksum ZIP filename mismatches, and missing signed-build audit fields, Toolary `beta` metadata requires the signed artifact gates, matching artifact version, and non-weakened releaseGate metadata, release notes must match metadata version, candidate manifests must match the app bundle they describe, built candidate bundles must keep the expected identifiers, and Xcode target versions plus bundle IDs must stay aligned.

Before changing Toolary metadata from `comingSoon` to `beta`, run the final gate checkers against the generated manifest and completed matrix. The metadata gate validates the signed artifact even while metadata still says `comingSoon`, so a version or artifact mismatch is caught before the release-branch status flip:

```sh
scripts/check-beta-release-gate.sh <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md
scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md
```

After changing Toolary metadata to `beta` in the release branch, run the final signed readiness wrapper. It also reruns the release-copy gate against the supplied metadata file, so localized catalog copy stays tied to the exact artifact version:

```sh
scripts/check-signed-build-environment.sh
scripts/install-signed-beta-app.sh <signed-export>/Fermo.app
FERMO_NOTARYTOOL_PROFILE=<profile> scripts/notarize-signed-beta-app.sh /Applications/Fermo.app <notary-output-dir>
scripts/check-notarytool-log.sh <notary-output-dir>/Fermo-0.1.0-3-notarytool.log
scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app
scripts/check-signed-helper-runtime.sh /Applications/Fermo.app
scripts/collect-signed-runtime-evidence.sh /Applications/Fermo.app <signed-runtime-evidence-dir>
scripts/check-signed-runtime-evidence.sh <signed-runtime-evidence-dir> <output-dir>/Fermo-0.1.0-3-beta-manifest.md
scripts/check-signed-beta-readiness.sh /Applications/Fermo.app <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md docs/toolary-catalog-metadata.json
scripts/archive-beta-release-evidence.sh /Applications/Fermo.app <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md docs/toolary-catalog-metadata.json <evidence-dir> <notary-output-dir>/Fermo-0.1.0-3-notarytool.log <signed-runtime-evidence-dir>
scripts/check-beta-release-evidence-archive.sh <evidence-dir> <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-0.1.0-3-notarytool.log <signed-runtime-evidence-dir>
scripts/check-final-beta-publication-evidence.sh <evidence-dir> <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-0.1.0-3-notarytool.log <signed-runtime-evidence-dir>
scripts/export-final-beta-publication-packet.sh <evidence-dir> <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-0.1.0-3-notarytool.log <signed-runtime-evidence-dir> <publication-packet-dir>
scripts/check-final-beta-publication-packet.sh <publication-packet-dir> <evidence-dir> <output-dir>/Fermo-0.1.0-3-beta-manifest.md docs/toolary-beta-runtime-matrix.md docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-0.1.0-3-notarytool.log <signed-runtime-evidence-dir>
```

The signed readiness wrapper intentionally requires `/Applications/Fermo.app`, verifies the manifest `App path`, `Version`, and `Build` match it, reruns release copy validation, reruns signed runtime approvals, and then runs the candidate, beta-release, and metadata gates; do not run the final beta gate from DerivedData or another path.
The signed build environment check is intentionally not part of unsigned local readiness because it depends on the signing Mac's Developer ID and notarytool setup. When using `--team-id`, the value must be a real 10-character Apple team ID; placeholders and malformed IDs are rejected before signing identity lookup.
The signed install script and exported operator packet require a real signed app bundle source, not DerivedData/Build Products, a symlink, or anything that physically resolves inside `/Applications/Fermo.app`; the installer validates `FERMO_REPLACE_APPLICATIONS_APP` as `0` or `1` and requires `FERMO_REPLACE_APPLICATIONS_APP=1` before replacing an existing `/Applications/Fermo.app`, including an existing symlink.
The signed notarization script requires `FERMO_NOTARYTOOL_PROFILE` to be a real keychain profile name, rejects angle-bracket placeholders, and requires an empty, non-symlink notary output directory that does not physically resolve inside `/Applications/Fermo.app`. It submits the installed `/Applications/Fermo.app`, writes `Fermo-<Version>-<Build>-notarytool.log` plus `Fermo-<Version>-<Build>-notary-request-id.txt`, staples the accepted ticket, runs `spctl`, and reruns signed candidate preflight. The notarytool log checker requires `status: Accepted` and a UUID request ID in the notarytool `id` field before that log can be used as release evidence.
The signed runtime approval check now covers Network Extension approval, App Guard approval, and the running Login Item helper; `scripts/check-signed-helper-runtime.sh` can also be run directly when debugging `FermoHelper` registration.
The signed runtime evidence collector writes `signed-runtime-evidence.md`, `signed-runtime-evidence.sha256`, plus raw signed preflight, `spctl`, `systemextensionsctl`, helper, `launchctl`, and process outputs for the release record; it requires an empty, non-symlink output directory that does not physically resolve inside `/Applications/Fermo.app`. `scripts/check-signed-runtime-evidence.sh` validates that exact directory before archiving, requires `signed-runtime-evidence.sha256` to list every captured file except itself, rejects a symlinked evidence directory plus unexpected files/directories/symlinks/special files inside it, and, when passed a manifest, checks the collected app version/build against the artifact manifest.
The evidence archive script requires an empty, non-symlink evidence directory that does not physically resolve inside `/Applications/Fermo.app`, reruns signed readiness, then writes `release-evidence.md` with the manifest, completed matrix, metadata, checksum file, optional notarytool log, notarization request ID, notary log SHA-256, signed runtime evidence directory, the SHA-256 of `signed-runtime-evidence.sha256`, ZIP path, and SHA-256 used by the passing gate. The archive checker confirms those archived copies still match the source release files, requires source basenames to be unique and not collide with reserved archive entries, requires the archived checksum copy to contain exactly one ZIP entry for the generated ZIP basename, rejects a symlinked archive directory plus unexpected stale files, directories, symlinks, and special files inside it, and checks that the matrix `Notarization request ID` matches the UUID from the notarytool log. The final publication evidence checker requires the notarytool log, signed runtime evidence directory, and Toolary metadata status `beta` before public beta upload; the publication packet exporter then copies the ZIP, `.sha256`, manifest, completed matrix, metadata, release evidence, notary log, signed runtime evidence, and `publication-packet.sha256` into one empty, non-symlink upload-ready directory that does not physically resolve inside `/Applications/Fermo.app`. The packet checker requires publication source basenames to be unique and not collide with reserved packet entries, requires `publication-packet.sha256` to list every packet file except itself, and rejects a symlinked packet directory plus unexpected stale files, directories, symlinks, and special files inside it.

The structured Toolary catalog draft lives in `docs/toolary-catalog-metadata.json` and must stay at `status: comingSoon` until the metadata gate passes for a signed beta artifact. After changing it to `beta`, run `scripts/check-signed-beta-readiness.sh` as the final local publication gate.
`scripts/check-beta-blocker-audit.sh` is the local honesty check for the current state: it passes only while the hard blockers are documented and Toolary metadata remains `comingSoon`.

## Product Memory

The durable project hub lives in the wiki:

`/Users/jakubchojnacki/Documents/Wiki/wiki/maps/fermo-project-hub.md`
