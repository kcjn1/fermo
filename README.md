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
- `FermoApp`: first SwiftUI/menu-bar dogfood shell for starting contracts, seeing system health, and recording evidence.
- `FermoHelper`: background helper executable used by the helper-persistence spike.
- `Fermo.xcodeproj`: signed macOS app + Network Extension + embedded Login Item helper handoff.
- `FermoFilterExtension`: macOS Network Extension `filter-data` provider target source.
- `docs/`: PRD, roadmap, technical spike, design brief, goal prompt, and release notes.

## Network Extension Spike

The first signed-build spike is scoped to blocking `reddit.com` and `youtube.com`. Manual signing, entitlement, and macOS approval steps are documented in `docs/macos-network-extension-signing.md`.

Local signed build `0.1.0/3` reaches `activated enabled` and blocks reddit/YouTube while allowing other domains. Firefox, private/incognito windows, Wi-Fi changes, sleep/wake, and reboot restore remain manual checks before any beta claim.

If macOS does not show an approval prompt, that usually means the System Extension approval already exists. Approval prompts are first-run or replacement events, not something to expect on every launch. Verify with `systemextensionsctl list`; when `com.toolary.fermo.filter` is `[activated enabled]`, start the website spike and check provider logs instead of waiting for another prompt.

## App Interruption Spike

The second signed-build spike interrupts a selected running app by bundle identifier during an active focus session. The local safe target is Calculator. Findings and the sandbox/non-sandbox decision are documented in `docs/macos-app-interruption-spike.md`.

## Helper Persistence Spike

The third signed-build spike packages `FermoHelper.app` under `Fermo.app/Contents/Library/LoginItems` and registers it with `SMAppService.loginItem(identifier:)`. The first helper policy is intentionally scoped to reddit, YouTube, and Calculator. Manual signing and Login Items approval steps are documented in `docs/macos-helper-persistence-spike.md`.

Local signed build `0.1.0/3` keeps `FermoHelper` running after the main app quits, interrupts Calculator, and keeps the already-enabled content filter effective. Sleep/wake and reboot/login restore remain unverified.

## Dogfood UI

The native app can now start a real focus contract from local presets instead of only launching spike samples. The flow writes a `FermoCore` policy, activates the content filter path, starts app interruption, and records proof/break-glass entries into the local evidence log. Focus Room app interruption now uses the active policy allowlist with explicit exclusions for Fermo and critical macOS shell apps.

Active Session is now the dogfood control surface: timer, runtime health, rule boundary, Soft stop with reason, Locked/Emergency break-glass, proof-due state, and `LockedModeGuard`-backed rule edit locking.

## Run Checks

```sh
swift test
swift build
```

## Product Memory

The durable project hub lives in the wiki:

`/Users/jakubchojnacki/Documents/Wiki/wiki/maps/fermo-project-hub.md`
