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

Implemented 2026-05-31 as native SwiftUI against the accepted design. All build under
`swift build` + `xcodebuild`; behaviour is honest about unverified signed-runtime checks.

- **Today / menu bar Quick Start** — done: `QuickStartPanel` (4-up preset cards) on Today and
  preset rows with `⌘1–⌘4` in the menu bar both call `FermoViewModel.startPreset`.
- **Menu bar state layouts** — done: `FermoMenuView` branches on `FermoViewModel.menuBarState`
  into Idle (quick start + last session), Protected (live countdown + progress + scope chips),
  Needs-approval (permission alert + affected checks), and Degraded (partial-protection banner +
  recheck). Diagnostics moved into a collapsible Developer section.
- **Break Glass modal** — done: `BreakGlassSheet` is a modal with a session/time-used summary, a
  23-character reason minimum, and a 2-second hold-to-confirm. Core `EvidenceRecorder` also
  rejects break-glass on non-active/soft sessions.
- **Evidence toolbar** — done: outcome + rigor filter pills, a session-summary stats line, and a
  footer with Reveal-in-Finder and Copy-as-Markdown (latest / full ledger) plus file exports.
- **Proof Capture** — done: structured outcome cards and a live Markdown draft preview pane
  (`FermoViewModel.proofPreviewMarkdown`); break-glass is handled only by its dedicated modal.
- **Start Contract** — done: proof-requirement chooser, Save-as-preset, Save-draft, and a Today
  "Next contract · saved draft" resume card, backed by `FocusContract.requiredProof`, persisted
  `customPresets`, and a `SavedContractDraft` store.
- **First-run empty states** — done: `FermoEmptyStateCard` for no-rooms, no-session, and
  empty-evidence, with CTAs that route to Start Contract.
- **Focus Room schedules** — done: the schedule editor exposes a mode picker and allowlist fields;
  `WeeklySchedule` carries `mode` + `allowedDomains` + `allowedApps` and materializes a Focus Room
  `FocusContract` (covered by tests).

Remaining for this surface is visual refinement on real signed-build runtime data, not new
functionality.
