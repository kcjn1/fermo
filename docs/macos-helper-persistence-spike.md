# macOS Helper Persistence Spike

This spike validates the third Milestone 1 feasibility gate from the wiki:

- package a real background helper inside the signed macOS app;
- register it with `SMAppService`;
- keep active session state in the shared app group;
- restore website blocking and app interruption without relying on the main app window staying open.

This is still a proof of concept, not beta readiness.

## What Is Wired

- Helper target: `FermoHelper`.
- Helper bundle identifier: `com.toolary.fermo.helper`.
- Embedded location: `Fermo.app/Contents/Library/LoginItems/FermoHelper.app`.
- Registrar: `Sources/FermoSystem/HelperRegistrar.swift`.
- Helper entrypoint: `Sources/FermoHelper/main.swift`.
- Shared state file: `FermoSnapshot.json` in the configured app group container.
- Dogfood trigger: `Start Helper Spike` / `Unregister` / `Open Login Items`.
- Autostart env: `FERMO_AUTOSTART_HELPER_SPIKE=1`.
- Cleanup env: `FERMO_AUTOSTOP_HELPER_SPIKE=1`.

The helper is a background-only macOS app target, not only a SwiftPM executable. The Swift package executable remains for local builds, but the signed proof relies on the Xcode app bundle embedded under `Contents/Library/LoginItems`.

## Helper Behavior

`Start Helper Spike` creates a one-hour reversible diagnostic policy that blocks:

- `reddit.com`
- `youtube.com`
- `com.apple.calculator`

The diagnostic policy uses Soft rigor so the spike can always be stopped while debugging. Real Locked contracts still use `LockedModeGuard` and require break-glass for early exit.

The app saves that policy to the app group as `FermoSnapshot.json`, activates the website filter, starts the app interruption monitor, and registers the embedded helper with:

```swift
SMAppService.loginItem(identifier: "com.toolary.fermo.helper")
```

If the helper is already enabled, `Start Helper Spike` re-registers it so the currently embedded helper binary is the one running during the spike.

Once running, the helper loops every 10 seconds:

- loads `FermoSnapshot.json`;
- checks active sessions;
- refreshes the content-filter rule snapshot for active sessions;
- interrupts blocked apps for active sessions;
- clears the rule snapshot after the persisted session expires.

The helper does not save `NEFilterManager` preferences. The containing app owns the Network Extension configuration; the helper only keeps the shared rule snapshot current so the already-enabled provider can continue reading the active rules.

## Manual Apple Developer Steps

These cannot be completed by the repo alone.

1. Create or update the App ID `com.toolary.fermo.helper`.
2. Assign it to the same Team as `com.toolary.fermo` and `com.toolary.fermo.filter`.
3. Enable the same App Group as the app and filter. For the current local team this is `MP3AWS77U3.com.toolary.fermo`.
4. Network Extensions are not required for the current helper design because the containing app owns `NEFilterManager`; only enable them for the helper if a future iteration moves filter-preference writes into the helper.
5. Keep the helper non-sandboxed while validating app interruption from the background helper.
6. Create a macOS Development provisioning profile for `com.toolary.fermo.helper`.
7. If the real Toolary team or bundle IDs differ, update `PRODUCT_BUNDLE_IDENTIFIER`, `FERMO_APP_GROUP_IDENTIFIER`, and all entitlements together.

## Manual Xcode Steps

1. Open `Fermo.xcodeproj`.
2. Select `Fermo`, `FermoFilterExtension`, and `FermoHelper`, and set the same Team on all three targets.
3. Confirm the app embeds `Contents/Library/LoginItems/FermoHelper.app`.
4. Confirm all three targets share the same app group.
5. Build and run the signed `Fermo` scheme.
6. Click `Start Helper Spike`.
7. If macOS requires approval, open Login Items & Extensions and allow Fermo/FermoHelper.
8. Quit the main Fermo app and verify `FermoHelper` continues running.

## Validation Checklist

Run from a signed build installed in `/Applications`:

- `Start Helper Spike` registers the helper without a signing error.
- System Settings shows the helper as allowed, or the app reports `requiresApproval` honestly.
- `FermoHelper` remains running after the main app quits.
- `reddit.com` and `youtube.com` remain blocked after the main app quits.
- Calculator is interrupted while the helper is running.
- The helper can reload the active session after the main app relaunches.
- The helper still sees the active session after sleep/wake.
- After reboot/login, the approved helper starts again and reloads active session state if it has not expired.
- `FermoSystem.HelperRestorePass` has unit coverage for materializing due weekly sessions, activating due one-off sessions, refreshing content-filter snapshots when active rules change, and clearing snapshots after sessions expire.
- After the session expires or the spike is stopped, website blocking is cleared.
- The diagnostic spike can be stopped even while active; a real Locked contract should still require break-glass.

## Stopped State Diagnostics

After stopping the helper spike, macOS may still show the Fermo system extension as `[activated enabled]`. That is the installed/approved extension state, not proof that rules are still being enforced.

Expected stopped state:

- `FermoContentFilterRules.json` in the app group is empty or expired.
- `reddit.com` and `youtube.com` load again.
- `FermoSnapshot.json` has no active sessions.
- The helper may remain approved in Login Items unless it was explicitly unregistered; if it is running with no active session, it should keep the rule snapshot empty.

Useful local commands:

```sh
swift build
swift test
xcodebuild -project Fermo.xcodeproj -scheme Fermo -destination 'platform=macOS' -derivedDataPath /tmp/FermoDerivedData-helper build
rm -rf /Applications/Fermo.app
ditto /tmp/FermoDerivedData-helper/Build/Products/Debug/Fermo.app /Applications/Fermo.app
codesign --verify --deep --strict --verbose=2 /Applications/Fermo.app
find /Applications/Fermo.app/Contents/Library/LoginItems -maxdepth 2 -print
sfltool dumpbtm | rg -i 'fermo|toolary'
pgrep -af FermoHelper
launchctl print gui/$(id -u)/com.toolary.fermo.helper
log stream --style compact --predicate 'process == "Fermo" OR process == "FermoHelper" OR subsystem == "com.toolary.fermo" OR subsystem CONTAINS "backgroundtaskmanagement"'
```

## Current Limits

- Signed local runtime validation passed on 2026-05-17 for main-app quit: `FermoHelper` remained running after `Fermo` quit, interrupted Calculator, and the already-enabled Network Extension continued blocking reddit/youtube while allowing `example.com`.
- The helper diagnostic policy is intentionally reversible. Use the real Start Contract flow to validate Locked contract break-glass semantics.
- The validated local build was `0.1.0/3`; `launchctl` reported `parent bundle version = 3` for `com.toolary.fermo.helper`.
- `swift test` validates the seams and persisted state; it cannot approve or prove macOS Login Items behavior.
- A Login Item starts after user login, not before login.
- This helper is not a privileged daemon and does not prove tamper-proof enforcement.
- The helper refreshes the shared rule snapshot; the containing app must enable the Network Extension first with signing, app groups, Network Extension entitlements, and macOS approvals correct.
- The helper intentionally follows the current non-sandboxed direct-distribution app-blocking path.
- Sleep/wake and reboot/login restore remain signed runtime checks, even though the helper restore pass is now covered by unit tests.
- After replacing a system extension build, `systemextensionsctl list` may show the previous build as `terminated waiting to uninstall on reboot`; this is expected until macOS restarts.

## Common Failure Modes

- `notFound`: the helper is not embedded at `Contents/Library/LoginItems/FermoHelper.app`, the bundle identifier is wrong, or the app was launched from a stale build.
- `requiresApproval`: macOS has registered the helper, but the user must allow it in Login Items & Extensions.
- `helper registration failed: invalid signature`: the app or helper was not signed with a valid provisioning profile.
- `missing app group container unconfigured`: the app was not launched from the signed Xcode app target with `FermoAppGroupIdentifier`.
- Helper runs but website blocking is not active: confirm the containing app enabled the Network Extension first, the active system extension build is current, and the helper can write the shared app group snapshot.
- Helper runs but does not interrupt apps: confirm the helper is not sandboxed and inspect logs for Apple Events or signal denials.
