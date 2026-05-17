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

## Milestone 3: Contract Hardening

- Persist active locked sessions across app quit, relaunch, sleep/wake, and reboot.
- Block edits that weaken an active Locked or Emergency session.
- Add clear copy for what Soft, Locked, and Emergency do and do not guarantee.
- Add break-glass flow for Emergency sessions that records the reason in the evidence log.

## Milestone 4: Claude Design Pass

- Use Claude Design after the technical spike passes.
- Cover menu bar popover, dashboard, focus contract start flow, Focus Room builder, blocklist editor, proof capture, evidence log, schedule editor, active locked state, onboarding, preferences, empty states, and errors.
- Match Toolary dark native chrome.

## Milestone 5: Toolary Beta

- Sign and notarize `Fermo.app`.
- Package a ZIP with one `.app`.
- Generate SHA-256.
- Add localized EN/PL/DE release notes and privacy copy.
- Promote Toolary catalog status from `comingSoon` to `beta`.
