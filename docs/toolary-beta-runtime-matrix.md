# Toolary Beta Runtime Matrix

Use this checklist for every candidate Toolary beta build. A build is not beta-ready until every required row passes on a signed, notarized app installed in `/Applications`. The operator release path is `docs/toolary-beta-release-runbook.md`.

## Candidate Build

- Date: `YYYY-MM-DDTHH:MM:SSZ`
- Channel:
- Version:
- Build:
- Git commit:
- Git tree:
- App path:
- Signing identity:
- Team ID:
- Notarization request ID:
- ZIP path:
- SHA-256:
- Toolary publishable:
- Tester Mac:
- macOS version:

## Preflight

You can run `scripts/verify-beta-candidate.sh /Applications/Fermo.app` to cover the signature/notarization, embedded-binary, bundle identifier, and package-type rows below. With signature checks enabled, it verifies the top-level app, Network Extension, App Guard extension, and login item helper as separate signed bundles. For unsigned local packaging checks only, run it with `FERMO_SKIP_SIGNATURE_CHECKS=1` against a DerivedData `.app`.
Before creating a signed beta artifact, run `scripts/check-local-release-readiness.sh` to cover script syntax, release copy, Endpoint Security request packet consistency, runtime matrix template coverage, app copy guardrails, release guardrails, source entitlements, Toolary metadata, Swift tests, Swift build, unsigned Xcode build, unsigned candidate preflight, and dogfood/dev package flow in one local pass.
Before the signed beta build, run `scripts/check-signed-build-environment.sh` on the signing Mac to confirm the Developer ID identity, notarytool availability, and source Xcode signing/app-group settings. If passing `--team-id`, replace `<TEAM_ID>` with the real 10-character Apple team ID; placeholder or malformed team IDs are rejected before signing identity lookup.
After installing the signed export, run `FERMO_NOTARYTOOL_PROFILE=<profile> scripts/notarize-signed-beta-app.sh /Applications/Fermo.app <notary-output-dir>` into an empty directory so the app is submitted, accepted, stapled, assessed, and rechecked before runtime approvals. Replace `<profile>` with a real notarytool keychain profile name; angle-bracket placeholders are rejected before notarization starts. The notary output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before notarization. Then run `scripts/check-notarytool-log.sh <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log`; the checker requires `status: Accepted` and a UUID request ID in the notarytool `id` field. Copy `<notary-output-dir>/Fermo-<Version>-<Build>-notary-request-id.txt` into the matrix `Notarization request ID` field, or pass it as `FERMO_NOTARIZATION_REQUEST_ID` before preparing the matrix.
After signed approvals pass, run `scripts/collect-signed-runtime-evidence.sh /Applications/Fermo.app <signed-runtime-evidence-dir>` into an empty directory and `scripts/check-signed-runtime-evidence.sh <signed-runtime-evidence-dir>` to capture and validate exactly `signed-runtime-evidence.md`, `signed-runtime-evidence.sha256`, plus raw signed preflight, `spctl`, `systemextensionsctl`, helper, `launchctl`, and process outputs before filling the manual rows. The signed runtime evidence output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before collection. `signed-runtime-evidence.sha256` must list every captured file except itself. The checker rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it. After the beta manifest exists, rerun `scripts/check-signed-runtime-evidence.sh <signed-runtime-evidence-dir> <manifest>` so the collected app `Version` and `Build` match the artifact being archived.
Run `scripts/check-release-copy.sh` directly when editing `docs/release-notes.md`, `docs/toolary-beta-copy.md`, or `docs/toolary-catalog-metadata.json`; it protects required EN/PL/DE sections, metadata/release-notes version alignment, privacy/permission copy, beta constraints, and overclaim guardrails.
Run `scripts/check-endpoint-security-request.sh` directly when editing `docs/apple-endpoint-security-entitlement-request.md`, `docs/macos-endpoint-security-signing.md`, or the App Guard target settings.
Run `scripts/check-runtime-matrix-template.sh` directly when editing this file; it protects the required signed-build, browser, App Guard, lifecycle, product, update/uninstall, and release rows from accidental removal.
Run `scripts/check-candidate-manifest-app.sh <Fermo.app> <manifest>` directly when checking that a manifest describes the same app path, version, and build as the candidate bundle.
Run `scripts/check-release-guardrails.sh` directly when changing release scripts or Toolary metadata rules; it verifies that beta packaging refuses skipped signatures, incomplete runtime matrices, non-`/Applications/Fermo.app` paths, missing version/build metadata, placeholder `0.0.0/0` values, and dirty git trees, candidate preflight rejects extra arguments and embedded bundle identifier drift, beta release gate rejects missing or non-`/Applications/Fermo.app` manifest app paths, non-canonical ZIP basenames, placeholder manifest version/build values, non-clean git tree markers, non-passing table statuses, missing Content Filter/App Guard diagnostic rows and ready evidence, manifest/matrix channel, version, date, git, app path, ZIP, SHA, Toolary publishable, or checksum-file mismatches, and missing signed-build audit fields, Toolary `beta` metadata requires artifact gates, matching artifact version, and non-weakened releaseGate metadata, release notes must match metadata version, candidate manifests must match the app bundle they describe, and Xcode target versions plus bundle IDs must stay aligned.

After preflight and runtime validation, use `scripts/package-beta-candidate.sh /Applications/Fermo.app <output-dir>` into an empty candidate output directory to create the ZIP, `.sha256`, and manifest. The candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging. The checksum file must contain exactly one ZIP entry for the generated ZIP basename. The script only accepts `FERMO_RELEASE_CHANNEL=dogfood-dev|beta`, `FERMO_RUNTIME_MATRIX_STATUS=pending|passed`, and `FERMO_SKIP_SIGNATURE_CHECKS=0|1`; it only allows `FERMO_RELEASE_CHANNEL=beta` when the app path is exactly `/Applications/Fermo.app`, signature checks are enabled, `FERMO_RUNTIME_MATRIX_STATUS=passed`, and numeric dot-separated version/build values are present from `Info.plist` or explicit `FERMO_RELEASE_VERSION` / `FERMO_RELEASE_BUILD`; placeholder `0.0.0/0` values are rejected for beta.
Use `scripts/prepare-beta-runtime-matrix.sh <manifest> docs/toolary-beta-runtime-matrix.md <output-matrix>` to prefill Candidate Build fields from the generated manifest before manual runtime validation. The runtime matrix output must not already exist or physically resolve inside the app bundle; the script refuses incomplete manifests, ZIP/SHA/checksum mismatches, overwriting an existing draft or manual matrix, and output paths that would mutate the signed app.
For local unsigned artifact checks, `scripts/check-dogfood-package-flow.sh <DerivedData-Fermo.app>` packages a dogfood/dev ZIP, verifies the checksum/manifest, prepares a matrix draft, and confirms Toolary metadata remains unpublished.

| Check | Command / Evidence | Required Result | Status |
| --- | --- | --- | --- |
| App installed from candidate artifact | `scripts/install-signed-beta-app.sh <signed-export>/Fermo.app` then `/Applications/Fermo.app` | Candidate app is installed exactly at `/Applications/Fermo.app`, not run from DerivedData | Pending |
| App signature | `scripts/verify-beta-candidate.sh /Applications/Fermo.app` | Top-level app and embedded extension/helper signatures exit 0 | Pending |
| App notarization | `FERMO_NOTARYTOOL_PROFILE=<profile> scripts/notarize-signed-beta-app.sh /Applications/Fermo.app <notary-output-dir>` then `scripts/check-notarytool-log.sh <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log` and `spctl --assess --type execute --verbose=4 /Applications/Fermo.app` | Notary submission is accepted, request ID is recorded, ticket is stapled, and assessment is accepted | Pending |
| Embedded system extensions | `find /Applications/Fermo.app/Contents/Library/SystemExtensions -maxdepth 1 -name '*.systemextension' -print` | Includes `com.toolary.fermo.filter.systemextension` and `com.toolary.fermo.appguard.systemextension` | Pending |
| Login item helper embedded | `find /Applications/Fermo.app/Contents/Library/LoginItems -maxdepth 1 -name 'FermoHelper.app' -print` | Includes `FermoHelper.app` | Pending |
| Toolary metadata | `scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json` | Remains `comingSoon` until this matrix passes and checksum exists | Pending |
| Signed runtime evidence | `scripts/collect-signed-runtime-evidence.sh /Applications/Fermo.app <signed-runtime-evidence-dir>` | `signed-runtime-evidence.md`, `signed-runtime-evidence.sha256`, and raw signed preflight/runtime/helper outputs are stored with the release record | Pending |

## macOS Approval

Use `docs/macos-network-extension-signing.md` for website-filter approval context and `docs/macos-endpoint-security-signing.md` for App Guard entitlement/signing context.
Use `docs/apple-endpoint-security-entitlement-request.md` before the first signed App Guard approval attempt if Apple has not granted Endpoint Security yet.

| Check | Command / Evidence | Required Result | Status |
| --- | --- | --- | --- |
| Network Extension approval | `scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app` plus System Settings | `com.toolary.fermo.filter` is activated and enabled | Pending |
| Endpoint Security approval | `scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app` plus System Settings | `com.toolary.fermo.appguard` is activated and enabled | Pending |
| App Guard approval UI | Fermo System Health, Preferences, or menu bar | Request button submits approval for `com.toolary.fermo.appguard` and status is visible in diagnostics | Pending |
| App Guard policy snapshot | Copy Fermo diagnostics report during an active app-protected session | `appGuardSnapshotState: ready`, active sessions > 0, and protected app bundle IDs are listed | Pending |
| Content Filter rule snapshot | Copy Fermo diagnostics report during an active website-protected session | `contentFilterSnapshotState: ready`, active sessions > 0, mode is listed, and blocked/allowed domains match the session | Pending |
| Runtime onboarding checklist | Fermo System Health and Preferences | Website filter, App Guard, and Login Item readiness are shown with concrete next action copy | Pending |
| Filter provider connected | Fermo System Health or macOS Network Extension UI | Fermo Focus Filter is connected during an active protected session | Pending |
| Helper registration | `scripts/check-signed-helper-runtime.sh /Applications/Fermo.app`, Fermo System Health, and Login Items settings | Helper is registered and allowed; FermoHelper process is running | Pending |

## Website Blocking

Start a real protected Blocklist session that blocks `reddit.com` and `youtube.com`. Do not use only a diagnostic spike for final beta validation.

| Browser | Normal Window | Private / Incognito | Required Result | Status |
| --- | --- | --- | --- | --- |
| Safari | `https://www.reddit.com`, `https://www.youtube.com`, `https://example.com` | Same URLs | Reddit/YouTube fail closed; example.com loads | Pending |
| Chrome | `https://www.reddit.com`, `https://www.youtube.com`, `https://example.com` | Same URLs | Reddit/YouTube fail closed; example.com loads | Pending |
| Firefox | `https://www.reddit.com`, `https://www.youtube.com`, `https://example.com` | Same URLs | Reddit/YouTube fail closed; example.com loads | Pending |

## App Launch Blocking

Start a real Focus Room or Blocklist session with explicit app rules. Existing running apps may be cleaned up by user-space interruption, but new launch and relaunch denial must be enforced by Endpoint Security.

| Scenario | Required Result | Status |
| --- | --- | --- |
| Launch blocked app while session is active | App launch is denied or immediately prevented by `FermoAppGuardExtension` | Pending |
| Relaunch blocked app after fallback interruption | Relaunch is denied while session is active | Pending |
| Launch allowed Focus Room app | App launches normally | Pending |
| Launch critical macOS shell apps | Finder, Dock, System Settings remain usable | Pending |
| Launch Fermo and FermoHelper | Fermo components are never blocked by the policy | Pending |
| End session normally | Previously blocked apps can launch again; no stale Endpoint Security cache keeps denying launch | Pending |
| Break glass on Locked/Emergency session | Requires break-glass path and records evidence | Pending |

## Lifecycle

| Scenario | Required Result | Status |
| --- | --- | --- |
| Main app quit during active session | Helper keeps policy active and web/app blocking continues | Pending |
| Main app relaunch during active session | UI reflects existing active session and current runtime state | Pending |
| Sleep / wake during active session | Blocking remains active after wake | Pending |
| Wi-Fi network change during active session | Blocking remains active after network change | Pending |
| Reboot / login during active session | Helper restore pass refreshes content-filter snapshot and App Guard can read the persisted policy without opening the main window | Pending |
| Reboot / login before due weekly schedule | Due schedule materializes once, activates inside its time window, and writes a fresh content-filter snapshot | Pending |
| Missed one-off scheduled session | Missed session is cancelled and not started late | Pending |
| Stop cleanup | Network filter state, app guard policy, helper snapshot, and UI state clear after session ends | Pending |

## Product Slices

| Area | Required Result | Status |
| --- | --- | --- |
| Rooms editor | Create, edit, disable, enable, and delete a room; changes persist after relaunch | Pending |
| Start Contract custom rules | Custom domain/app rules validate, dedupe, persist into active session, and enforce | Pending |
| Schedule editor | Create, edit, disable, enable, and delete weekly schedules; IDs are preserved on edit | Pending |
| Evidence export | Latest entry and full ledger export to the configured folder without overwriting existing files | Pending |
| Evidence diagnostics | Preferences and diagnostics report show export destination readiness | Pending |
| Diagnostics report | Copied report includes filter snapshot, App Guard snapshot, helper, app interruption, sessions, schedules, rooms, evidence, and export destination | Pending |

## Update / Uninstall

| Scenario | Required Result | Status |
| --- | --- | --- |
| Install newer build over current build | System extensions update cleanly or show expected replacement prompt | Pending |
| Stop session before update | No stale blocking remains after update | Pending |
| Delete app after stopping sessions | System extensions and helper do not leave active blocking behind | Pending |
| Reinstall after deletion | User approval and runtime state are understandable and recoverable | Pending |

## Release Gate

Only after all required rows pass:

- Create signed and notarized `.app`.
- Run `FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh /Applications/Fermo.app <output-dir>` into an empty output directory; the candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging.
- Run `scripts/prepare-beta-runtime-matrix.sh <manifest> docs/toolary-beta-runtime-matrix.md <output-matrix>` if the completed matrix has not already been filled from the artifact manifest. The runtime matrix output must not already exist or physically resolve inside the app bundle.
- Store the generated ZIP, `.sha256`, and manifest.
- Run `scripts/check-beta-release-gate.sh <manifest> <completed-runtime-matrix>` and keep the passing output with the release record. The checker verifies that manifest App path is exactly `/Applications/Fermo.app`, Version/Build are numeric dot-separated values, Created/Date are UTC `YYYY-MM-DDTHH:MM:SSZ` timestamps, and Git tree is `clean`; the matrix Channel, Date, Version, Build, Git commit, Git tree, App path, ZIP path, SHA-256, and Toolary publishable fields match the generated manifest and artifact; Signing identity, Team ID, UUID Notarization request ID, Tester Mac, and macOS version are filled; the App Guard and Content Filter diagnostic rows plus `appGuardSnapshotState: ready` / `contentFilterSnapshotState: ready` evidence are present; and every table status value is `Passed` or `passed`.
- Prepare release notes and privacy copy in EN/PL/DE from `docs/release-notes.md` and `docs/toolary-beta-copy.md`.
- Run `scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json <manifest> <completed-runtime-matrix>` while metadata is still `comingSoon`; with artifact arguments, the checker validates the release gate and verifies that metadata `version` matches manifest `Version` before the status flip.
- Update `docs/toolary-catalog-metadata.json` from `comingSoon` to `beta`, then run the metadata gate again before publishing the Toolary catalog change. The checker verifies that the releaseGate requirements still require signed/notarized app, runtime matrix, and artifact checksum.
- Run `scripts/check-signed-beta-readiness.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json` as the final local command before publishing metadata. This final wrapper intentionally rejects app paths other than `/Applications/Fermo.app`, reruns release-copy validation against the supplied metadata, verifies the manifest `App path`, `Version`, and `Build` match the signed app bundle, and reruns signed runtime approvals for Network Extension, App Guard, and Login Item helper state.
- Run `scripts/check-signed-runtime-evidence.sh <signed-runtime-evidence-dir> <manifest>` before archiving evidence so the signed runtime evidence belongs to the same app version/build as the release manifest.
- Run `scripts/archive-beta-release-evidence.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <evidence-dir> <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>` into an empty evidence directory to create `release-evidence.md` plus copies of the manifest, completed matrix, metadata, checksum file, notarytool log, signed runtime evidence directory, and the SHA-256 of `signed-runtime-evidence.sha256` used by the passing final gate. The evidence directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before archiving. The archive checker requires the archived checksum copy to contain exactly one ZIP entry for the generated ZIP basename.
- Run `scripts/check-beta-release-evidence-archive.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>` to confirm the evidence directory still matches the source manifest, matrix, metadata, checksum, notarytool log, signed runtime evidence, ZIP path, SHA-256, and that the matrix `Notarization request ID` matches the UUID from the log. The release evidence archive checker requires source basenames to be unique and not collide with reserved archive entries, and rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it.
- Run `scripts/check-final-beta-publication-evidence.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>` as the final publication evidence gate; it requires the notarytool log, signed runtime evidence directory, and Toolary metadata status `beta`.
- Run `scripts/export-final-beta-publication-packet.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir> <publication-packet-dir>` and then `scripts/check-final-beta-publication-packet.sh <publication-packet-dir> <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>` so the upload-ready directory includes only the ZIP, `.sha256`, manifest, completed matrix, metadata, `release-evidence.md`, notarytool log, signed runtime evidence, `PUBLICATION_PACKET.md`, and `publication-packet.sha256`. `publication-packet.sha256` must list every packet file except itself. The export directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before export, source basenames must be unique and not collide with reserved packet entries, and the packet checker rejects a symlinked packet directory plus unexpected files, directories, symlinks, and special files inside it.
- Store this completed matrix with the passing publication packet.
