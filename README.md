# Fermo

Fermo is a native macOS focus blocker planned for personal dogfooding and later Toolary distribution.

The first milestone is intentionally engineering-first: prove the focus-blocking model, schedule logic, locked-mode invariants, and macOS integration feasibility before investing in the final Claude Design pass.

## Current Shape

- `FermoCore`: blocklists, domain/app rules, sessions, schedules, locked-mode policy, and local persistence.
- `FermoSystem`: macOS integration adapters and stubs for Network Extension, app interruption, and helper registration.
- `FermoApp`: minimal SwiftUI/menu-bar shell for dogfooding.
- `FermoHelper`: placeholder helper executable.
- `FermoFilterExtension`: handoff notes for the real Network Extension target.
- `docs/`: PRD, roadmap, technical spike, and release notes.

## Run Checks

```sh
swift test
swift build
```

## Product Memory

The durable project hub lives in the wiki:

`/Users/jakubchojnacki/Documents/Wiki/wiki/maps/fermo-project-hub.md`
