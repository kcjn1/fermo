# macOS Network Extension Signing Spike

This repo now has a real Xcode handoff for the website-blocking spike:

- `Fermo.xcodeproj` contains a macOS app target named `Fermo`.
- `FermoFilterExtension` is embedded as a macOS System Extension.
- `FermoHelper` is embedded as a macOS Login Item for the helper-persistence spike.
- The provider class is `FermoFilterDataProvider`.
- The provider reads `FermoCore.ContentFilterRuleSnapshot` JSON from the shared app group.
- The initial spike snapshot blocks only `reddit.com` and `youtube.com`.

## What Is Already Wired

- App bundle identifier: `com.toolary.fermo`.
- Filter bundle identifier: `com.toolary.fermo.filter`.
- Helper bundle identifier: `com.toolary.fermo.helper`.
- Local macOS development app group: `MP3AWS77U3.com.toolary.fermo`.
- `FERMO_APP_GROUP_IDENTIFIER` expands into the app `Info.plist` as `FermoAppGroupIdentifier`.
- The filter extension `NEMachServiceName` is `$(FERMO_APP_GROUP_IDENTIFIER).filter`.
- Entitlements files:
  - `Xcode/Fermo/Fermo.entitlements`
  - `FermoFilterExtension/FermoFilterExtension.entitlements`
- The containing app is intentionally not sandboxed in the current local spike because signed app interruption failed from the sandbox. The Network Extension system extension remains sandboxed.
- The app-side adapter can write rule snapshots through `NetworkExtensionWebsiteBlockingController` once an app group is configured.
- The adapter configures `NEFilterManager` with `filterSockets = true`, the filter provider bundle identifier, and optional app-group snapshot metadata.
- The dogfood action submits an `OSSystemExtensionRequest` for `com.toolary.fermo.filter` before enabling the Network Extension configuration.
- The provider applies `NEFilterSettings(defaultAction: .filterData)` at startup so socket flows are delivered to `FermoFilterDataProvider`.
- The provider reloads the shared app-group snapshot when the file modification time changes, allowing helper refreshes to take effect while the filter is already enabled.
- The app-side adapter now fails activation if the configured app group container is unavailable instead of silently allowing all traffic.
- The embedded system extension product is named `com.toolary.fermo.filter.systemextension`.

## Manual Apple Developer Steps

These cannot be completed by the repo alone.

1. In Apple Developer, confirm the team has Network Extension access for `content-filter-provider`.
2. Create or update the App ID `com.toolary.fermo`.
3. Enable App Groups, Network Extensions, and System Extension for the app App ID. App Sandbox is intentionally off for the current direct-distribution app-blocking spike.
4. Create or update the App ID `com.toolary.fermo.filter`.
5. Enable App Groups, Network Extensions, and App Sandbox for the filter App ID.
6. Create or update the App ID `com.toolary.fermo.helper`.
7. Enable the same App Group for the helper, and enable Network Extensions if the helper will restore the content filter.
8. Create a macOS-compatible app group and assign it to all three App IDs. For the current local development team this is `MP3AWS77U3.com.toolary.fermo`; for another team use `<TEAM_ID>.com.toolary.fermo`.
9. Create macOS Development provisioning profiles for the app, filter, and helper.
10. If the real Toolary bundle IDs or team differ, update `FERMO_APP_GROUP_IDENTIFIER`, all entitlements files, and the filter `NEMachServiceName` together.

The `NEMachServiceName` rule is strict: Network Extension rejects the system extension unless the value starts with one of the app groups present in the extension's `com.apple.security.application-groups` entitlement.

## Manual Xcode Steps

1. Open `Fermo.xcodeproj`.
2. Select the `Fermo` target and set `Signing & Capabilities > Team`.
3. Select the `FermoFilterExtension` target and set the same team.
4. Select the `FermoHelper` target and set the same team.
5. Confirm `Fermo` has App Groups, Network Extensions, and System Extension capabilities. Keep App Sandbox off while validating app interruption from the containing app.
6. Confirm `FermoFilterExtension` has App Sandbox, App Groups, and Network Extensions capabilities.
7. Confirm `FermoHelper` has the same App Group and the entitlements needed for helper restore.
8. Confirm all targets use the same app group value.
9. Build and run the `Fermo` scheme from Xcode.
10. Approve the system extension in System Settings when macOS asks. This is normally a first-run or replacement event, not something macOS asks on every launch.
11. Approve the Network Extension/content filter prompt when macOS asks. Once the configuration is already approved, repeat starts should be silent.
12. If System Settings shows the extension as blocked or waiting for user approval, allow it under Login Items & Extensions / Network Extensions or Privacy & Security, then rerun `Start Website Spike`.

## Running The Website Spike

1. Run the signed `Fermo` scheme from Xcode.
2. Open the menu bar popover or the main Fermo window.
3. Click `Start Website Spike`.
4. If Fermo says system extension approval is needed, approve it in System Settings, then click `Start Website Spike` again.
5. If macOS asks for Network Extension/content-filter approval, approve it. If no prompt appears and `systemextensionsctl list` shows `[activated enabled]`, continue with validation; approval likely already exists.
6. Test the validation checklist below.
7. Click `Stop` to disable the filter configuration after testing.

The `Start Website Spike` action creates a fresh one-hour policy snapshot and writes it to the shared app group. That snapshot is intentionally scoped to `reddit.com` and `youtube.com`.
The website spike is a reversible diagnostic policy, not a real Locked contract. `Stop` must clear it while active so developers can always recover during signing and permission work. Real Locked contracts still go through the Start Contract flow and require break-glass for early exit.

## Validation Checklist

Run the signed build, start the spike policy, then verify:

- `reddit.com` fails closed.
- `youtube.com` fails closed.
- Other domains still load.
- Safari, Chrome, and Firefox are checked separately.
- Private/incognito windows are checked separately.
- Rules still apply after Wi-Fi changes.
- Rules still apply after sleep/wake.
- Rules still apply after reboot if an active session is restored.
- Rules clear after deactivation or session expiry.
- The diagnostic spike can be stopped while active without using break-glass.

## Stopped State Diagnostics

After `Stop`, `systemextensionsctl list` can still show `com.toolary.fermo.filter` as `[activated enabled]`. That means macOS still has the system extension installed and approved; it does not by itself mean Fermo is currently blocking websites.

Expected stopped state:

- `FermoContentFilterRules.json` in the app group has no active session IDs and no blocked domains, or has an `expiresAt` timestamp at or before now.
- `curl -I https://www.reddit.com` and `curl -I https://www.youtube.com` return normally.
- The helper may still be registered or running, but it should be idle unless an active persisted session exists.
- Starting the spike again may not show any macOS prompt if the system extension and content filter were already approved.

Useful local inspection commands:

```sh
systemextensionsctl list
log stream --predicate 'subsystem == "com.toolary.fermo" OR subsystem == "com.toolary.fermo.filter" OR subsystem CONTAINS "com.apple.networkextension" OR eventMessage CONTAINS "com.toolary.fermo.filter"' --style compact
```

If macOS does not show an approval prompt, first check whether approval already happened:

```sh
systemextensionsctl list
```

If the output shows `com.toolary.fermo.filter` as `[activated enabled]`, there is no extra System Extension approval to accept. In that state the next thing to verify is whether the Network Extension filter configuration is enabled and the provider is receiving flows. A signed app can trigger the website spike without UI clicks:

```sh
osascript -e 'tell application "Fermo" to quit' >/dev/null 2>&1 || true
launchctl setenv FERMO_AUTOSTART_WEBSITE_SPIKE 1
open -n /Applications/Fermo.app
sleep 8
launchctl unsetenv FERMO_AUTOSTART_WEBSITE_SPIKE
curl -I --max-time 8 https://www.reddit.com
curl -I --max-time 8 https://www.youtube.com
curl -I --max-time 8 https://example.com
log show --last 3m --info --style compact --predicate 'subsystem == "com.toolary.fermo.filter" OR eventMessage CONTAINS[c] "Dropping flow" OR eventMessage CONTAINS[c] "Started content filter"'
```

Expected local spike result: reddit and YouTube fail to connect, `example.com` still returns normally, and logs include `Started content filter with 2 blocked domains` plus `Dropping flow` entries for blocked hosts.

Useful local rebuild/install loop:

```sh
swift build
swift test
xcodebuild -project Fermo.xcodeproj -scheme Fermo -destination 'platform=macOS' -derivedDataPath /tmp/FermoDerivedData-appgroup build
rm -rf /Applications/Fermo.app
ditto /tmp/FermoDerivedData-appgroup/Build/Products/Debug/Fermo.app /Applications/Fermo.app
codesign --verify --deep --strict --verbose=2 /Applications/Fermo.app
launchctl setenv FERMO_AUTOSTART_WEBSITE_SPIKE 1
open -n /Applications/Fermo.app
launchctl unsetenv FERMO_AUTOSTART_WEBSITE_SPIKE
```

## Current Limits

- This is not beta readiness.
- A local Apple Development signed build can be produced and installed in `/Applications`.
- On the local development machine, the system extension has reached `activated enabled`.
- On the local development machine, `Fermo Focus Filter` reaches Network Extension `connected` state.
- `curl`, Safari, and Chrome trigger provider drops for `www.reddit.com` and `www.youtube.com`; Firefox is not installed locally.
- The local `0.1.0/3` system extension replaced `0.1.0/2` and `0.1.0/1`; previous builds remain `terminated waiting to uninstall on reboot` until macOS restarts.
- The first website-blocking spike is intentionally scoped to `reddit.com` and `youtube.com`.
- Sleep/wake, Wi-Fi changes, reboot restore, and Firefox validation remain follow-up checks.
- App interruption and helper persistence have local signed proof-of-concept coverage, but they are still not beta-readiness claims.

## Common Failure Modes

- `missing app group container ...`: the app is not signed with the configured App Group, or the App Group was not assigned to both App IDs.
- `invalid NEMachServiceName`: set `NEMachServiceName` to a value prefixed by the extension's App Group, for example `MP3AWS77U3.com.toolary.fermo.filter`.
- `permission denied` from Network Extension preferences: the Team/App ID does not have the content-filter entitlement, provisioning is stale, or macOS approval has not been granted.
- `systemextensionsctl list` does not show `com.toolary.fermo.filter`: run the signed app and click `Start Website Spike` so the app submits the activation request, then approve it in System Settings.
- System extension appears under Privacy & Security but is blocked: approve it, quit Fermo, rebuild/rerun from Xcode, and start the spike again.
- No approval prompt appears: this usually means approval already exists. Confirm `systemextensionsctl list` shows `com.toolary.fermo.filter` as `[activated enabled]`, then use the autostart verification commands above.
- `reddit.com` and `youtube.com` still load after approval: check `systemextensionsctl list`, stream Network Extension logs, then confirm the built app contains `Contents/Library/SystemExtensions/com.toolary.fermo.filter.systemextension`.
- New provider code does not appear to run after rebuilding: bump the system extension `CFBundleVersion`, reinstall the signed app, rerun the activation request, and approve any macOS replacement prompt.
