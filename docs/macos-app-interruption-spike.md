# macOS App Interruption Spike

This spike validates the second Milestone 1 feasibility gate from the wiki:

- detect running apps with `NSWorkspace.shared.runningApplications`;
- match selected bundle identifiers;
- try to interrupt them during an active focus session;
- record whether normal user-space handling is enough or whether stronger macOS integration is needed.

## What Is Wired

- Adapter: `Sources/FermoSystem/AppInterruptionController.swift`.
- Dogfood trigger: `Start App Spike` / `Stop Apps`.
- Autostart env: `FERMO_AUTOSTART_APP_SPIKE=1`.
- Local safe target: `com.apple.calculator` / Calculator.
- The monitor runs while the app spike is active and repeats every few seconds, so apps launched during the session are interrupted too.
- The adapter records:
  - matched bundle identifier;
  - display name;
  - PID;
  - whether interruption was requested;
  - whether the app resisted graceful or signal handling.

## Signed Runtime Result

Sandboxed containing app:

- `NSRunningApplication.terminate()` was blocked by macOS sandbox policy.
- `NSRunningApplication.forceTerminate()` did not interrupt Calculator.
- POSIX `SIGTERM` did not interrupt Calculator.
- Logs showed `Sandbox: Fermo deny(1) appleevent-send com.apple.calculator`.
- Adding `com.apple.security.automation.apple-events` and `NSAppleEventsUsageDescription` did not make arbitrary app interruption work from the sandbox.

Non-sandboxed containing app:

- The same Apple Development signed app build can run without `com.apple.security.app-sandbox` on the containing app.
- The Network Extension system extension remains signed and sandboxed.
- Calculator running before the app spike was terminated.
- Calculator relaunched during the active app spike was terminated again.
- Logs showed `Requested termination for Kalkulator pid ...`.
- A regression check confirmed the website spike still starts, enables `Fermo Focus Filter`, blocks reddit/youtube, and allows `example.com`.

## Current Decision

The app-blocking POC passes for a Developer ID-style, non-sandboxed containing app. It does not pass from the sandboxed containing app.

Toolary beta no longer treats user-space interruption as sufficient app enforcement. The current decision is:

- keep user-space interruption as startup cleanup/fallback for apps that were already running when a session starts;
- enforce new app launch and relaunch denial through `FermoAppGuardExtension`, the embedded Endpoint Security System Extension;
- share app allow/deny semantics through `FermoSystem.AppEnforcementPolicy` so fallback interruption and Endpoint Security evaluate Blocklist and Focus Room rules consistently;
- block Toolary beta until Apple grants `com.apple.developer.endpoint-security.client`, provisioning profiles are regenerated, macOS approval passes, and the signed runtime matrix validates app launch denial.

Do not claim impossible-to-bypass enforcement. This spike proves practical process interruption under normal user behavior for a non-sandboxed app, not tamper-proof enforcement.

## Follow-Up Validation

- Use `docs/macos-endpoint-security-signing.md` for the App Guard signing, approval, and launch-deny checklist.
- Use `docs/toolary-beta-runtime-matrix.md` for the final signed Toolary beta browser, lifecycle, app-launch, product-slice, update, and uninstall rows.
- Test apps launched before session start as fallback cleanup and apps launched/relaunched during active sessions as Endpoint Security denial.
- Test apps with unsaved state or quit confirmation prompts as degraded fallback behavior, not as the beta app-enforcement gate.
- Keep Finder, Dock, System Settings, Fermo, and FermoHelper on the always-allowed recovery path.
