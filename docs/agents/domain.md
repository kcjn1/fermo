# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before Exploring

Read these first when they exist:

- `AGENTS.md`
- `docs/prd.md`
- `docs/roadmap.md`
- `docs/technical-spike.md`
- `docs/goal.md`
- `CONTEXT.md` at the repo root
- `docs/adr/`

If `CONTEXT.md` or `docs/adr/` do not exist yet, proceed silently. They can be created later when the project needs a formal glossary or decision record.

## Layout

Fermo is a single-context repo:

- `FermoCore` owns focus contracts, rules, sessions, schedules, rigor, evidence, and persistence types.
- `FermoSystem` owns macOS integration adapters and runtime coordination.
- `FermoApp` owns SwiftUI/menu bar UI.
- `FermoHelper` owns the background/login-item runtime.
- `FermoFilterExtension` owns the Network Extension provider handoff.

Use the product vocabulary from `AGENTS.md` and `docs/prd.md`: Focus Contract, Focus Room, Blocklist Mode, Soft/Locked/Emergency rigor, proof, evidence log, helper persistence, and Network Extension content filter.

## ADR Conflicts

If future output contradicts an ADR, surface it explicitly rather than silently overriding it.
