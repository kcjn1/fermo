# Toolary Beta Release Runbook

Use this runbook when turning a local dogfood/dev Fermo build into a public Toolary beta candidate. It intentionally keeps Toolary metadata at `comingSoon` until the signed artifact, runtime matrix, and checksum gates pass.

## Hard Blockers

Do not publish Toolary beta until all of these are true:

- Apple has granted `com.apple.developer.endpoint-security.client` for `com.toolary.fermo.appguard`.
- Fresh provisioning profiles include Endpoint Security and the shared app group.
- The candidate app is signed, notarized, and installed exactly at `/Applications/Fermo.app`.
- macOS approvals are complete for Network Extension, Endpoint Security App Guard, and Login Item.
- `docs/toolary-beta-runtime-matrix.md` has passed on the signed, notarized app.
- Toolary metadata remains `comingSoon` until the artifact gates pass.

## 1. Local Source Readiness

Run this before touching signing profiles or release metadata:

```sh
scripts/check-local-release-readiness.sh
scripts/check-beta-blocker-audit.sh
scripts/export-signed-beta-operator-packet.sh <output-dir>
scripts/check-signed-beta-operator-packet.sh <output-dir>
scripts/check-endpoint-security-request-packet.sh <output-dir>
```

Expected evidence:

- script syntax gates pass;
- release copy, Endpoint Security request, runtime matrix template, app copy, release guardrails, Xcode entitlements, and Toolary metadata gates pass;
- `swift test`, `swift build`, and unsigned `xcodebuild` pass;
- unsigned candidate preflight and dogfood/dev package flow pass.
- signed beta operator packet is exported with the exact command order for the signing Mac.
- Endpoint Security request packet is exported and validated before sending anything to Apple.
- Endpoint Security request packet output directory must be empty and not a symlink before export, and copied request/checklist/entitlement files must match repository source files.
- signed beta operator packet output directory must be empty and not a symlink before export, and copied runbook/matrix/release copy/metadata files must match repository source files.
- blocker audit confirms Toolary metadata remains `comingSoon` until Apple/signing/runtime evidence exists.

If this fails, fix local source first. Do not continue to signed release work.

## 2. Apple Entitlement And Profiles

Use `docs/apple-endpoint-security-entitlement-request.md` as the request packet. After Apple approves the entitlement:

```sh
scripts/export-endpoint-security-request-packet.sh <output-dir>
scripts/check-endpoint-security-request-packet.sh <output-dir>
```

Endpoint Security request packet output directory must be empty and not a symlink before export, and copied request/checklist/entitlement files must match repository source files.

1. Enable Endpoint Security for App ID `com.toolary.fermo.appguard`.
2. Confirm App Groups remain enabled for `com.toolary.fermo`, `com.toolary.fermo.filter`, `com.toolary.fermo.helper`, and `com.toolary.fermo.appguard`.
3. Regenerate macOS Development and direct-distribution profiles.
4. Confirm Xcode uses the same Team ID and app group for app, helper, Network Extension, and App Guard.
5. Run:

```sh
scripts/check-endpoint-security-request.sh
scripts/check-xcode-entitlements.sh
```

Expected evidence:

- App Guard entitlements include `com.apple.developer.endpoint-security.client`;
- Xcode target settings still use `com.toolary.fermo.appguard`;
- `FERMO_APP_GROUP_IDENTIFIER` is consistent across targets.

## 3. Signed Candidate Build

Build and export the release candidate with signing enabled, then install the exact candidate artifact at `/Applications/Fermo.app`.
Before building, check local signing inputs:

```sh
scripts/check-signed-build-environment.sh
```

Use `scripts/check-signed-build-environment.sh --team-id <TEAM_ID>` only after replacing `<TEAM_ID>` with the real 10-character Apple team ID; placeholder or malformed team IDs are rejected before signing identity lookup.

Run:

```sh
scripts/install-signed-beta-app.sh <signed-export>/Fermo.app
FERMO_NOTARYTOOL_PROFILE=<profile> scripts/notarize-signed-beta-app.sh /Applications/Fermo.app <notary-output-dir>
scripts/check-notarytool-log.sh <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log
scripts/verify-beta-candidate.sh /Applications/Fermo.app
scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app
scripts/check-signed-helper-runtime.sh /Applications/Fermo.app
scripts/collect-signed-runtime-evidence.sh /Applications/Fermo.app <signed-runtime-evidence-dir>
scripts/check-signed-runtime-evidence.sh <signed-runtime-evidence-dir>
systemextensionsctl list
spctl --assess --type execute --verbose=4 /Applications/Fermo.app
```

Expected evidence:

- top-level app signature passes;
- embedded Network Extension, App Guard extension, and `FermoHelper.app` signatures pass;
- notarization submission is accepted, stapling succeeds, and notarization assessment is accepted;
- `scripts/install-signed-beta-app.sh` installs the candidate exactly at `/Applications/Fermo.app`, and both the installer and exported operator packet require a real signed app bundle source, not DerivedData/Build Products, a symlink, or anything that physically resolves inside `/Applications/Fermo.app`. The installer validates `FERMO_REPLACE_APPLICATIONS_APP` as `0` or `1` and treats an existing `/Applications/Fermo.app` symlink as an explicit replacement case.
- `scripts/notarize-signed-beta-app.sh` requires that the notary output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before notarization, submits the installed app with `notarytool`, writes the submission ZIP/log plus `notary-request-id.txt`, staples `/Applications/Fermo.app`, and reruns signed candidate preflight.
- `FERMO_NOTARYTOOL_PROFILE` must be replaced with a real keychain profile name; `<profile>` and other angle-bracket placeholders are rejected before notarization starts.
- `scripts/check-notarytool-log.sh` confirms the notarytool log has `status: Accepted` and a UUID request ID in the notarytool `id` field.
- `systemextensionsctl list` can show the Network Extension and App Guard after approval.
- `scripts/check-signed-runtime-approvals.sh` exits 0 before the manual runtime matrix starts.
- `scripts/check-signed-helper-runtime.sh` exits 0 and confirms the `com.toolary.fermo.helper` Login Item service plus a running `FermoHelper` process.
- `scripts/collect-signed-runtime-evidence.sh` writes `signed-runtime-evidence.md`, `signed-runtime-evidence.sha256`, plus raw preflight, `spctl`, `systemextensionsctl`, helper, `launchctl`, and process outputs for the signed runtime record; the output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before collection.
- `scripts/check-signed-runtime-evidence.sh` validates that signed runtime evidence directory before it is archived, requires `signed-runtime-evidence.sha256` to list every captured file except itself, rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it, and when passed the beta manifest also verifies the collected app `Version` and `Build` match the artifact being published.

Do not use DerivedData paths for beta packaging or final readiness.

## 4. Runtime Matrix

Prepare a matrix draft only after a signed artifact exists:

```sh
FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh /Applications/Fermo.app <output-dir>
scripts/prepare-beta-runtime-matrix.sh <output-dir>/Fermo-<Version>-<Build>-beta-manifest.md docs/toolary-beta-runtime-matrix.md <output-dir>/Fermo-<Version>-<Build>-beta-runtime-matrix.md
```

Then manually execute every row in the generated runtime matrix against the signed, notarized `/Applications/Fermo.app`.
The candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging so stale artifacts cannot be mixed with the signed beta ZIP, checksum, and manifest or copied back into the submitted app.
The runtime matrix output must not already exist or physically resolve inside the app bundle; `scripts/prepare-beta-runtime-matrix.sh` refuses to overwrite a manual matrix or mutate the signed app.
Use `<notary-output-dir>/Fermo-<Version>-<Build>-notary-request-id.txt` for the matrix `Notarization request ID`.

Required runtime evidence includes:

- `signed-runtime-evidence.md` from `scripts/collect-signed-runtime-evidence.sh`;
- `contentFilterSnapshotState: ready` during an active website-protected session;
- `appGuardSnapshotState: ready` during an active app-protected session;
- `appGuardSnapshotProtectedApps` contains the blocked app bundle identifier;
- Safari, Chrome, and Firefox normal plus private/incognito checks pass;
- blocked app launch and relaunch are denied by App Guard;
- Finder, Dock, System Settings, Fermo, and FermoHelper remain usable;
- FermoHelper process is running before main-app quit, sleep/wake, and reboot/login rows;
- main-app quit, sleep/wake, Wi-Fi change, reboot/login restore, update, and uninstall rows pass.

Do not replace real runtime evidence with local unit tests or unsigned dogfood/dev output.

## 5. Artifact Gates Before Metadata Flip

Keep `docs/toolary-catalog-metadata.json` at `status: comingSoon` and run:

```sh
scripts/check-beta-release-gate.sh <manifest> <completed-runtime-matrix>
scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json <manifest> <completed-runtime-matrix>
```

Expected evidence:

- manifest `Channel` is `beta`;
- manifest `App path` is exactly `/Applications/Fermo.app`;
- ZIP basename is canonical: `Fermo-<Version>-<Build>-beta.zip`;
- ZIP checksum and `.sha256` contents match, and the checksum file contains exactly one ZIP entry;
- manifest `Created` and matrix `Date` are UTC `YYYY-MM-DDTHH:MM:SSZ` timestamps;
- manifest and matrix agree on Channel, Date, Git commit, Git tree, Version, Build, App path, ZIP path, SHA-256, and Toolary publishable;
- Git tree is `clean`;
- every matrix table status is `Passed` or `passed`;
- signed-build audit fields are filled.

## 6. Metadata Flip And Final Gate

Only after the artifact gates pass, update `docs/toolary-catalog-metadata.json` from `comingSoon` to `beta`.

Run the final local publication gate:

```sh
scripts/check-signed-beta-readiness.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json
scripts/check-signed-runtime-evidence.sh <signed-runtime-evidence-dir> <manifest>
scripts/archive-beta-release-evidence.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <evidence-dir> <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>
scripts/check-beta-release-evidence-archive.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>
scripts/check-final-beta-publication-evidence.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>
scripts/export-final-beta-publication-packet.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir> <publication-packet-dir>
scripts/check-final-beta-publication-packet.sh <publication-packet-dir> <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>
```

Expected evidence:

- release copy is aligned with the exact metadata version;
- signed candidate preflight passes with signature checks enabled;
- final signed readiness reruns signed runtime approvals for Network Extension, App Guard, and Login Item helper state;
- beta release gate passes;
- Toolary metadata gate passes with `status: beta`.
- the evidence directory must be empty and not a symlink before archiving so stale files cannot be carried into release evidence;
- `release-evidence.md` is written with the ZIP path, SHA-256, manifest, completed matrix, metadata, checksum file, notarytool log, notarization request ID, notary log SHA-256, signed runtime evidence directory, and the SHA-256 of `signed-runtime-evidence.sha256`.
- `scripts/check-beta-release-evidence-archive.sh` verifies the archived checksum copy still contains exactly one ZIP entry for the generated ZIP basename.
- `scripts/check-beta-release-evidence-archive.sh` confirms the archived manifest, completed matrix, metadata, checksum, notarytool log, and signed runtime evidence copies match the source files, requires source basenames to be unique and not collide with reserved archive entries, checks that the matrix `Notarization request ID` matches the UUID in the notarytool log, and the release evidence archive checker rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it.
- `scripts/check-final-beta-publication-evidence.sh` is the last publication evidence gate; it requires the notarytool log, signed runtime evidence directory, and Toolary metadata status `beta`.
- `scripts/export-final-beta-publication-packet.sh` creates the upload-ready packet with the ZIP, `.sha256`, manifest, completed runtime matrix, Toolary metadata, release evidence, notarytool log, signed runtime evidence directory, `PUBLICATION_PACKET.md`, and `publication-packet.sha256`; the output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` so stale files cannot be uploaded accidentally and release packaging cannot mutate the signed app. `publication-packet.sha256` must list every packet file except itself. `scripts/check-final-beta-publication-packet.sh` verifies the packet still matches the passing source files, requires source basenames to be unique and not collide with reserved packet entries, and rejects a symlinked packet directory plus unexpected files, directories, symlinks, and special files inside it.

Publish only from the passing publication packet.

## Rollback Rule

If any signed runtime row fails, leave metadata at `comingSoon`, keep the artifact as dogfood/dev evidence only, file the failure against the relevant runtime slice, and rerun this runbook from local source readiness after the fix.
