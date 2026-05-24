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

This means Fermo has two viable product paths:

- keep the main app non-sandboxed for the first direct-distribution beta and continue validating process interruption with more real apps;
- or keep the main app sandboxed and move app enforcement into a stronger helper, Endpoint Security path, or another privileged/system component.

Do not claim impossible-to-bypass enforcement. This spike proves practical process interruption under normal user behavior for a non-sandboxed app, not tamper-proof enforcement.

## Follow-Up Validation

- Test apps that relaunch themselves.
- Test apps with unsaved state or quit confirmation prompts.
- Test apps launched before session start and during Locked Mode.
- Test Slack, Discord, browsers, and terminal apps by bundle identifier.
- Decide whether direct-distribution beta accepts non-sandboxed app interruption or requires Endpoint Security/helper work before beta.
