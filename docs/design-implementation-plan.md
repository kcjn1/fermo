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
   - Remaining: stronger validation affordances and a more compact final visual treatment.

5. **Rooms**
   - Implement Rooms master-detail and blocklist/focus-room editors.
   - Prevent weakening rules while a Locked/Emergency session is active.

6. **Active Session and Proof**
   - Done for the first dogfood pass: Active Session has a live timer, rule boundary, runtime health, Soft stop, Locked/Emergency break-glass, and proof-due state.
   - Remaining: visual refinement, denser active-session layout, and manual signed-runtime validation of each control path.

7. **Evidence and Preferences**
   - Partially done: Evidence shows the real local ledger and latest Markdown preview.
   - Remaining: explicit Markdown file export path and evidence storage preferences.
   - Add preferences for defaults, helper/login item, diagnostics, evidence storage.

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

- sleep/wake restore;
- reboot/login restore;
- Wi-Fi change;
- Firefox validation;
- Safari private and Chrome incognito validation.

## Next Product Slices

- Editable Room/Blocklist builder with guarded mutations.
- Schedule editor.
- Markdown evidence export to disk.
- Preferences for evidence storage and default preset/rigor.
