# Fermo Design Implementation Plan

Source design: `docs/design/claude-design-2026-05-23/Fermo.html`.

## Decision

Use the Claude Design bundle as the product UI direction. It matches Fermo's wiki plan and current technical spike status, with the corrections documented in the bundle README.

This design pass is not a beta-readiness signal. It is the input for the first native SwiftUI dogfood UI.

## Implementation Order

1. **Foundation**
   - Add Fermo design tokens in SwiftUI: graphite surfaces, teal health accent, amber degraded state, red only for real failures.
   - Add reusable components: status badge, health row, permission alert, section header, metric/chip row.
   - Keep SF Symbols and native controls.

2. **Shell**
   - Replace the placeholder window with a native `NavigationSplitView`.
   - Keep `MenuBarExtra` as the compact daily-use surface.
   - Primary sections: Today, Start Contract, Rooms, Evidence, System Health, Preferences.

3. **First Useful Screens**
   - Implement Today and System Health first because they expose the real signed-spike state.
   - Wire them to existing `FermoViewModel` fields: website filter status, helper status, app interruption status, active policy/session.
   - Show unverified manual checks honestly.

4. **Contract Flow**
   - Done for the first dogfood pass: Start Contract builds a real `FocusContractDraft`, persists the active policy when possible, activates the filter path, starts app interruption, and asks for helper persistence.
   - Current native flow also supports custom Focus Room allowlists, Blocklist domain/app rules, one-off start-later sessions, and recurring weekly schedules.
   - Remaining before beta: signed runtime validation of the final `/Applications/Fermo.app` control paths.

5. **Rooms**
   - Done for dogfood/dev: Rooms supports create, edit, enable, disable, delete, blocklist/focus-room rules, and persistence.
   - Locked/Emergency weakening rules are guarded by `LockedModeGuard`.

6. **Active Session and Proof**
   - Done for the first dogfood pass: Active Session has a live timer, rule boundary, runtime health, Soft stop, Locked/Emergency break-glass, and proof-due state.
   - Remaining: visual refinement, denser active-session layout, and manual signed-runtime validation of each control path.

7. **Evidence and Preferences**
   - Done for dogfood/dev: Evidence shows the real local ledger and latest Markdown preview, exports the latest entry and full ledger, avoids overwrites, and uses the configured folder.
   - Preferences include defaults, helper/login item controls, diagnostics, evidence storage, App Guard approval entry points, and the shared protection checklist.
   - Remaining before beta: signed runtime validation of evidence export and diagnostics rows.

8. **Icon**
   - Done in the first native pass: the protected-room/contract-seal concept now has a source SVG and `AppIcon.appiconset`.
   - Future work here is visual refinement only, not a blocker for the technical spike.

## Non-Negotiables

- No paid AI.
- No beta-ready copy.
- No marketing hero.
- No gamification or productivity scoring.
- No impossible-to-bypass claims.
- No hiding system permission complexity.
- No custom web UI runtime inside the macOS app.

## Manual Checks Still Blocking Beta

- Apple Endpoint Security entitlement and regenerated profiles;
- signed/notarized `/Applications/Fermo.app`;
- Network Extension, Endpoint Security App Guard, and Login Item approvals;
- sleep/wake restore;
- reboot/login restore;
- Wi-Fi change;
- Firefox validation;
- Safari private and Chrome incognito validation.

## Next Product Slices

- Signed Toolary beta runtime matrix on `/Applications/Fermo.app`.
- Visual refinement after runtime behavior is proven.
- Release packaging only after `scripts/check-signed-beta-readiness.sh` and the release evidence archive pass.

## Native UI Completion Backlog (post-spike design pass)

These accepted-design affordances are intentionally deferred until after signed-runtime
validation. The dogfood UI is functionally complete without them; they are design-completion
work, not blockers. Tracked here so "Done" above is not read as "every design element shipped":

- **Today / menu bar Quick Start**: launch a saved preset in one action (the design's 4-up
  preset cards / `⌘1–⌘4` menu-bar rows). Today and the menu bar currently route to Start Contract.
- **Menu bar state layouts**: the four state-driven popovers (Idle / Protected countdown /
  Needs-approval / Degraded). The menu bar currently shows a flat diagnostics list.
- **Break Glass modal**: hold-to-confirm + reason character-minimum + time-used summary. The
  core `EvidenceRecorder` now rejects break-glass on non-active/soft sessions, but the
  deliberate-friction modal UI is still an inline panel.
- **Evidence toolbar**: outcome/rigor/date filter pills, session-summary stats, and a
  Reveal-in-Finder / Copy-as-Markdown footer.
- **Proof Capture**: live Markdown draft preview pane and structured outcome cards.
- **Start Contract**: proof-requirement chooser plus Save-as-preset / Save-draft (needs a
  persisted presets/drafts store and a `requiredProof` field on `FocusContract`).
- **First-run empty states**: dedicated StateCards for no-rooms / no-session / empty-evidence.
- **Focus Room schedules**: `WeeklySchedule` / `WeeklyScheduleEditorDraft` now carry
  `mode` + `allowedDomains` + `allowedApps`, and occurrences materialize a Focus Room
  `FocusContract` (covered by tests). The schedule editor UI still only creates Blocklist
  schedules; exposing a mode picker + allowlist fields is part of this design pass.
