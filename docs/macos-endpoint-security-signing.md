# macOS Endpoint Security Signing Checklist

Fermo App Guard is a macOS System Extension that uses Endpoint Security to deny app launches during active protected sessions. This is the beta gate for app launch enforcement; the user-space interruption fallback is not enough for beta-grade protection.

## Targets

- Containing app bundle ID: `com.toolary.fermo`
- App Guard bundle ID: `com.toolary.fermo.appguard`
- Embedded product: `com.toolary.fermo.appguard.systemextension`
- Shared app group: `MP3AWS77U3.com.toolary.fermo` for the current development team, or `<TEAM_ID>.com.toolary.fermo` for another team
- Entitlements file: `FermoAppGuardExtension/FermoAppGuardExtension.entitlements`

## Apple Developer Portal

These steps cannot be completed from the repo.
Use `docs/apple-endpoint-security-entitlement-request.md` as the prepared request packet for Apple.
To export a self-contained local packet for Apple review, run:

```sh
scripts/export-endpoint-security-request-packet.sh <output-dir>
```

1. Request or confirm access to `com.apple.developer.endpoint-security.client`.
2. Create or update the App ID `com.toolary.fermo.appguard`.
3. Enable Endpoint Security for `com.toolary.fermo.appguard`.
4. Enable the shared app group used by the containing app and Network Extension.
5. Create macOS Development and direct-distribution provisioning profiles for `com.toolary.fermo.appguard`.
6. Confirm the containing app profile still allows System Extension and the same app group.
7. Regenerate profiles after every entitlement or App Group change; stale profiles commonly produce `ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED`.

## Xcode

1. Open `Fermo.xcodeproj`.
2. Select the `FermoAppGuardExtension` target.
3. Set the same Team as the `Fermo` and `FermoFilterExtension` targets.
4. Confirm `Signing & Capabilities` includes Endpoint Security and App Groups.
5. Confirm the `Fermo` target embeds `FermoAppGuardExtension.systemextension` in `Contents/Library/SystemExtensions`.
6. Build the `Fermo` scheme, not only the extension target, before validating packaging.

Before the signed beta build, run:

```sh
scripts/check-signed-build-environment.sh
```

## Local Packaging Check

```sh
xcodebuild -project Fermo.xcodeproj -scheme Fermo -destination 'platform=macOS' -derivedDataPath /tmp/FermoDerivedData-beta CODE_SIGNING_ALLOWED=NO build
find /tmp/FermoDerivedData-beta/Build/Products/Debug/Fermo.app/Contents/Library/SystemExtensions -maxdepth 1 -name '*.systemextension' -print
FERMO_SKIP_SIGNATURE_CHECKS=1 scripts/verify-beta-candidate.sh /tmp/FermoDerivedData-beta/Build/Products/Debug/Fermo.app
```

Expected result:

- `com.toolary.fermo.filter.systemextension`
- `com.toolary.fermo.appguard.systemextension`

## Signed Approval Smoke Test

Run this only with a signed build installed from the candidate artifact in `/Applications`.

```sh
scripts/verify-beta-candidate.sh /Applications/Fermo.app
scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app
scripts/check-signed-helper-runtime.sh /Applications/Fermo.app
systemextensionsctl list
log stream --predicate 'subsystem == "com.toolary.fermo.appguard" OR eventMessage CONTAINS "com.toolary.fermo.appguard" OR eventMessage CONTAINS "Endpoint Security"' --style compact
```

Expected result:

- Signature checks pass for the app, Network Extension, App Guard extension, and login item helper.
- `spctl` accepts the app through the preflight script.
- `systemextensionsctl list` shows `com.toolary.fermo.appguard` as activated and enabled after approval.
- `scripts/check-signed-runtime-approvals.sh` exits 0 before starting the manual runtime matrix.
- `scripts/check-signed-helper-runtime.sh` exits 0 and shows the running `com.toolary.fermo.helper` Login Item service.
- Fermo System Health shows App Guard approval status.
- Diagnostics include `appGuardApproval` and `appGuardApprovalDetail`.
- Diagnostics include `contentFilterSnapshotState: ready` and `appGuardSnapshotState: ready` during an active signed runtime validation session.

After the full runtime matrix passes, package the beta candidate:

```sh
FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh /Applications/Fermo.app <output-dir>
scripts/prepare-beta-runtime-matrix.sh <manifest> docs/toolary-beta-runtime-matrix.md <output-runtime-matrix>
```

Keep the generated ZIP, `.sha256`, manifest, and completed runtime matrix together.
Before updating Toolary metadata, run:

```sh
scripts/check-beta-release-gate.sh <manifest> <completed-runtime-matrix>
scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json <manifest> <completed-runtime-matrix>
```

After changing Toolary metadata from `comingSoon` to `beta`, run the final signed readiness wrapper:

```sh
scripts/check-signed-beta-readiness.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json
```

The final signed readiness wrapper reruns signed runtime approvals, including Network Extension, App Guard, and Login Item helper state.

## App Launch Deny Validation

Use a real protected Blocklist or Focus Room session. The diagnostic website spike is not enough for this check.

1. Start a session with one blocked app rule.
2. Quit the blocked app if it is already running.
3. Copy the Fermo diagnostics report and confirm `contentFilterSnapshotState: ready`, `appGuardSnapshotState: ready`, `appGuardSnapshotActiveSessions` is greater than zero, and the expected bundle identifier appears in `appGuardSnapshotProtectedApps`.
4. Launch the blocked app.
5. Confirm the launch is denied or immediately prevented by `FermoAppGuardExtension`.
6. Launch an allowed Focus Room app and confirm it opens normally.
7. Confirm Finder, Dock, System Settings, Fermo, and FermoHelper remain usable.
8. End the session and confirm the previously blocked app can launch again.

Fermo's Endpoint Security responses are intentionally not cached. Launch allow/deny depends on the active local policy snapshot, so a decision made during a protected session must not survive after the session ends or after rules change.

## Common Failure Modes

- `ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED`: Endpoint Security entitlement is missing from the signed extension or provisioning profile.
- `ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED`: macOS approval is still pending in System Settings.
- `ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED`: the system extension is not running with the privileges Endpoint Security requires.
- `systemextensionsctl list` does not show `com.toolary.fermo.appguard`: run the signed containing app and request App Guard approval from System Health, Preferences, or the menu bar.
- App launch still succeeds after approval: confirm the active policy snapshot exists in the app group and stream `com.toolary.fermo.appguard` logs while relaunching the app.
- Diagnostics show `appGuardSnapshotState: missingSnapshot` or `unreadableSnapshot`: the containing app did not persist a readable App Group snapshot for the system extension.
