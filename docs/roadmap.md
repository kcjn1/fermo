# Fermo Roadmap

## Milestone 0: Scaffold

- Create Swift package structure.
- Add repo-local agent instructions and docs.
- Implement testable core model.
- Add minimal SwiftUI/menu-bar shell.

## Milestone 1: Technical Spike

- Validate Network Extension website blocking in a signed Xcode app.
- Validate app process interruption for selected bundle identifiers.
- Validate helper/background service registration with `SMAppService`.
- Document permission prompts, entitlements, and failure modes.

## Milestone 2: Dogfood UI

- Replace placeholder shell with the first usable native UI.
- Add focus contract start flow: task, intended outcome, local preset, mode, rigor, duration.
- Add blocklist editor, Focus Room allowlist editor, session creator, schedule editor, active-session screen, and preferences.
- Add proof/result capture and Markdown evidence-log export.
- Add permission/onboarding states.
- Keep UI native and compact.

Current status as of 2026-05-30:

- First native shell is in place with Today, Start Contract, Rooms, Evidence, System Health, and Preferences.
- Start Contract now builds a real `FocusContractDraft` from local presets and starts an active `FermoCore` policy instead of only triggering spike sample data.
- Evidence capture records completed/partial/not-done/break-glass outcomes into the local policy evidence log and renders a Markdown preview.
- Focus Room app interruption now evaluates the active policy allowlist and excludes Fermo plus critical macOS shell apps.
- Active Session now has a dedicated timer/control surface with rule details, runtime health, Soft stop, Locked/Emergency break-glass, proof-due state, and `LockedModeGuard`-backed rule edit locking.
- Rooms/blocklists, custom Focus Room allowlists, one-off start-later sessions, recurring weekly schedules, main-app/helper due-session restore, Markdown evidence export, richer Preferences, System Health, diagnostics copy, and release guardrails are locally implemented.
- The app target has been split into a small app shell, a view model file, reusable components, screen files, navigation views, and a dedicated system-extension activation adapter.
- Remaining before beta: Apple Endpoint Security entitlement, signed/notarized `/Applications/Fermo.app`, macOS approvals, and the full signed lifecycle/browser/runtime matrix.

## Milestone 3: Contract Hardening

- Persist active locked sessions across app quit, relaunch, sleep/wake, and reboot.
- Block edits that weaken an active Locked or Emergency session.
- Add clear copy for what Soft, Locked, and Emergency do and do not guarantee.
- Add break-glass flow for Emergency sessions that records the reason in the evidence log.

Current status as of 2026-05-30:

- Normal early stop and rule-weakening mutations are routed through `LockedModeGuard`.
- Soft contracts can stop early with a local not-done reason.
- Locked/Emergency contracts expose break-glass recording instead of a normal stop path.
- Rooms visibly lock weakening edits while a protected contract is active.
- App launch enforcement policy is shared between the Endpoint Security App Guard extension and the user-space interruption fallback.

## Milestone 4: Claude Design Pass

- Use Claude Design after the technical spike passes the local signed runtime checks and the remaining manual lifecycle checks are either completed or explicitly scoped out.
- Cover menu bar popover, dashboard, focus contract start flow, Focus Room builder, blocklist editor, proof capture, evidence log, schedule editor, active locked state, onboarding, preferences, empty states, and errors.
- Match Toolary dark native chrome.
- Generate the app icon concept and prepare the later `AppIcon.appiconset` handoff.
- Treat the design pass as direction and production UI input, not as a beta-readiness signal.
- 2026-05-23: Claude Design bundle accepted and stored in `docs/design/claude-design-2026-05-23/`; implementation plan captured in `docs/design-implementation-plan.md`.

Pre-design status as of 2026-05-17:

- Signed build `0.1.0/3` validates website blocking, app interruption, and helper persistence after main-app quit on the local machine.
- Sleep/wake, Wi-Fi change, reboot/login restore, Firefox, and private/incognito browser validation remain manual checks before any beta claim.

## Milestone 5: Toolary Beta

- Sign and notarize `Fermo.app`.
- Package a ZIP with one `.app`.
- Generate SHA-256.
- Add localized EN/PL/DE release notes and privacy copy.
- Promote Toolary catalog status from `comingSoon` to `beta`.
