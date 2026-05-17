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
- `FermoSystem`: macOS integration adapters and stubs for Network Extension, app interruption, and helper registration.
- `FermoApp`: minimal SwiftUI/menu-bar shell for dogfooding.
- `FermoHelper`: placeholder helper executable.
- `FermoFilterExtension`: handoff notes for the real Network Extension target.
- `docs/`: PRD, roadmap, technical spike, design brief, goal prompt, and release notes.

## Run Checks

```sh
swift test
swift build
```

## Product Memory

The durable project hub lives in the wiki:

`/Users/jakubchojnacki/Documents/Wiki/wiki/maps/fermo-project-hub.md`
