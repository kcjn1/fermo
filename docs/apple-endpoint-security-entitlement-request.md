# Apple Endpoint Security Entitlement Request Draft

Status: draft for Apple Developer request. Do not claim Toolary beta readiness until Apple grants `com.apple.developer.endpoint-security.client`, profiles are regenerated, and the signed runtime matrix passes.

Export a self-contained request packet with:

```sh
scripts/export-endpoint-security-request-packet.sh <output-dir>
```

## Request Summary

Fermo requests the Endpoint Security Client entitlement for its macOS App Guard System Extension:

- Entitlement: `com.apple.developer.endpoint-security.client`
- Containing app bundle ID: `com.toolary.fermo`
- Endpoint Security extension bundle ID: `com.toolary.fermo.appguard`
- Embedded product: `com.toolary.fermo.appguard.systemextension`
- Shared app group: `MP3AWS77U3.com.toolary.fermo` for the current development team, or `<TEAM_ID>.com.toolary.fermo` for production
- Distribution model: direct-distribution macOS app, signed and notarized before beta

## Product Context

Fermo is a local-first macOS focus contract app for Toolary. A user starts or schedules a protected work session with:

- one task and intended outcome;
- a Focus Room allowlist or Blocklist;
- Soft, Locked, or Emergency rigor;
- local Markdown evidence at the end of the session.

The product is not surveillance, device management, employee monitoring, malware inspection, or background analytics. Fermo applies only the focus rules the user starts or schedules on their own Mac.

## Why Endpoint Security Is Required

Fermo must enforce app launch and relaunch boundaries during active protected sessions. The existing user-space interruption path can ask already-running distracting apps to quit, but it cannot reliably deny a new app launch or relaunch while the contract is active.

Endpoint Security is needed specifically for `AUTH_EXEC` decisions:

- deny launching explicitly blocked apps during Blocklist sessions;
- deny launching apps outside the Focus Room allowlist during Focus Room sessions;
- allow critical macOS shell apps and Fermo components so the user can recover;
- allow all launches when no protected session is active;
- clear enforcement after the session ends.

This is the beta gate for app launch enforcement. Fermo will keep the user-space interruption path only as startup cleanup for apps that were already running before a session began.

## Scope And Data Handling

The App Guard extension uses the minimal Endpoint Security event scope needed for launch decisions:

- subscribes to `ES_EVENT_TYPE_AUTH_EXEC`;
- resolves the launching process's `CFBundleIdentifier` from its executable's enclosing app bundle (falling back to the code-signing identifier only when no bundle identifier is available) and matches it against the active local policy's app bundle identifiers;
- responds allow or deny;
- does not inspect file contents, network traffic, keystrokes, screen contents, or browser history;
- does not upload Endpoint Security events or focus history to Toolary servers;
- stores active policy snapshots locally in the configured App Group.

The shared policy snapshot contains local focus rules: active session windows, allowed or blocked domains, allowed or blocked app bundle identifiers, and expiry timestamps. Evidence logs and exports are local Markdown files chosen by the user.

## User Consent And Transparency

Fermo exposes the App Guard state in the product before relying on it:

- System Health shows Endpoint Security App Guard readiness.
- Preferences shows the shared runtime onboarding checklist.
- The menu bar exposes an App Guard approval request.
- Diagnostics include `appGuardApproval` and `appGuardApprovalDetail`.
- Diagnostics include `contentFilterSnapshotState` and `appGuardSnapshotState` so a tester can confirm the website rule snapshot and App Guard policy snapshot are both readable during a signed runtime pass.
- Release notes and catalog copy state that app launch enforcement requires macOS approval.

Fermo does not claim impossible-to-bypass enforcement. Beta copy uses "protected session", "requires approval", and "degraded" language when system permissions are missing.

## Safety Boundaries

The App Guard policy must always allow:

- Finder;
- Dock;
- System Settings;
- Fermo;
- FermoHelper;
- critical macOS shell processes needed for recovery.

Blocked decisions are limited to active protected sessions. Ending a session, expiry, or break-glass clears the active policy so previously blocked apps can launch again.

## Current Implementation Evidence

The repo contains the implementation scaffold and local verification path:

- `FermoAppGuardExtension/main.swift`: Endpoint Security system extension entry point.
- `FermoAppGuardExtension/FermoAppGuardExtension.entitlements`: declares `com.apple.developer.endpoint-security.client`.
- `Sources/FermoSystem/AppEnforcementPolicy.swift`: shared allow/deny policy.
- `Sources/FermoSystem/AppGuardPolicyStore.swift`: reads the local App Group policy snapshot.
- `Sources/FermoSystem/ProtectionOnboardingChecklist.swift`: user-visible approval readiness model.
- `docs/macos-endpoint-security-signing.md`: signing and approval checklist.
- `docs/toolary-beta-runtime-matrix.md`: signed runtime validation matrix.

Local checks before Apple approval:

```sh
swift test
swift build
xcodebuild -project Fermo.xcodeproj -scheme Fermo -destination 'platform=macOS' -derivedDataPath /tmp/FermoPlanDerivedData CODE_SIGNING_ALLOWED=NO build
FERMO_SKIP_SIGNATURE_CHECKS=1 scripts/verify-beta-candidate.sh /tmp/FermoPlanDerivedData/Build/Products/Debug/Fermo.app
```

The Xcode build embeds both:

- `com.toolary.fermo.filter.systemextension`
- `com.toolary.fermo.appguard.systemextension`

## Apple Developer Portal Checklist

After Apple grants the entitlement:

1. Enable Endpoint Security for App ID `com.toolary.fermo.appguard`.
2. Confirm App Groups remain enabled for `com.toolary.fermo`, `com.toolary.fermo.filter`, `com.toolary.fermo.helper`, and `com.toolary.fermo.appguard`.
3. Regenerate provisioning profiles for the app and App Guard extension.
4. Build signed app installed at `/Applications/Fermo.app`.
5. Approve the System Extension and Endpoint Security prompt in System Settings.
6. Run `docs/toolary-beta-runtime-matrix.md` on the signed, notarized artifact.
7. Package with `scripts/package-beta-candidate.sh`.
8. Run `scripts/check-beta-release-gate.sh` and `scripts/check-toolary-metadata-gate.sh` before changing Toolary metadata from `comingSoon` to `beta`.
9. After changing Toolary metadata to `beta`, run `scripts/check-signed-beta-readiness.sh`.

## Draft Request Text

Fermo is a local-first macOS focus contract app for Toolary. Users explicitly start or schedule protected sessions that define one task, allowed tools, blocked distractions, session rigor, and local evidence capture.

We request `com.apple.developer.endpoint-security.client` for `com.toolary.fermo.appguard`, a System Extension embedded in `com.toolary.fermo`. Fermo needs Endpoint Security only to make app launch and relaunch allow/deny decisions during active user-created focus sessions. The extension subscribes to `AUTH_EXEC`, resolves the launching process's `CFBundleIdentifier` from its executable's enclosing app bundle (falling back to the code-signing identifier when none is available), compares it against the active local policy stored in the App Group, and responds allow or deny. It does not inspect file contents, keystrokes, screen contents, browser history, or network traffic, and it does not upload Endpoint Security events or focus history.

Without Endpoint Security, Fermo can only ask already-running distracting apps to quit. It cannot reliably prevent a blocked app from being relaunched during a protected session. Endpoint Security is therefore required for the core user-visible promise of app launch enforcement.

Fermo remains transparent about this permission: System Health, Preferences, menu bar controls, diagnostics, release notes, and catalog copy all state that App Guard requires macOS approval. Fermo always allows Finder, Dock, System Settings, Fermo, FermoHelper, and recovery-critical macOS processes. Enforcement is active only inside user-started or user-scheduled protected sessions and clears when sessions end, expire, or break glass is used.
