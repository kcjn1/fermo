# Fermo Agent Instructions

## Product Truth

- Fermo is a native macOS focus blocker for personal dogfooding and later Toolary distribution.
- Public positioning is "macOS focus blocker" or "focus firewall"; do not describe it publicly as a Freedom clone.
- V1 is macOS-only. Do not add iOS, Windows, Android, teams, cloud sync, focus sounds, streaks, or gamification unless the product plan changes.
- Technical validation comes before visual design. Do not claim beta readiness until website blocking, app interruption, and helper persistence have passed real macOS testing.

## Architecture

- Keep product memory in `/Users/jakubchojnacki/Documents/Wiki`.
- Keep app code in this repo.
- `FermoCore` owns domain rules, blocklists, sessions, schedules, locked-mode policy, and persistence types.
- `FermoSystem` owns macOS-facing integration adapters.
- `FermoApp` owns SwiftUI/menu-bar UI.
- `FermoHelper` is the future background/helper entrypoint.
- `FermoFilterExtension` is the Xcode app-extension handoff folder. The real Network Extension target must be validated with signing and entitlements.

## Quality Bar

- Add unit tests for every core rule or scheduling change.
- Do not make system-level enforcement claims unless verified on a signed build.
- Locked Mode means "normal early exit is blocked/frictioned", not "impossible to bypass".
- Keep copy calm and explicit about permissions.
- Toolary release metadata must be EN/PL/DE localized before beta publication.

## Commands

```sh
swift test
swift build
```
