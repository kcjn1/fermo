# Fermo `/goal` Prompt

Use this when running a long implementation pass in Claude Code or another goal-driven agent.

```text
/goal Build Fermo through the next verified milestone using this repo as the source of truth.

Read first:
- AGENTS.md
- docs/prd.md
- docs/roadmap.md
- docs/technical-spike.md
- docs/design-brief.md
- README.md

Product direction:
- Fermo is a task-first macOS focus contract app, not a generic blocker clone.
- V1 has no paid AI dependency. Use local deterministic presets.
- The differentiators are Focus Contract, Focus Room Mode, Soft/Locked/Emergency rigor, proof capture, and local Markdown evidence logs.
- Keep the app local-first and honest about macOS permissions.
- Do not claim beta readiness until Network Extension, app interruption, helper persistence, and lifecycle/browser-matrix checks pass signed-build validation.

Implementation target:
1. Preserve the existing Swift Package structure.
2. Expand the dogfood UI around the focus contract flow:
   - task and intended outcome;
   - local preset picker;
   - Blocklist Mode vs Focus Room Mode;
   - Soft/Locked/Emergency rigor;
   - active contract state;
   - proof capture;
   - evidence log rendering.
3. Keep macOS system integrations behind FermoSystem adapters.
4. Keep the real Network Extension work as a signed Xcode spike unless entitlements/signing and macOS approvals are available in this environment.
5. Add or update tests for every FermoCore behavior.

Verification:
- Run `swift test`.
- Run `swift build`.
- Report exactly what is implemented, what remains a signed-build spike, and any UI/design gaps.

Stop conditions:
- Stop if the repo no longer builds.
- Stop before adding paid AI, cloud sync, gamification, or fake beta release metadata.
- Stop before making unverified claims about impossible-to-bypass blocking.
```
