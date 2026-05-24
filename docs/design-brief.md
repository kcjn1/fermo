# Fermo Design Brief

## Current Design Source

The 2026-05-23 Claude Design bundle is accepted as the UI direction and stored in `docs/design/claude-design-2026-05-23/`.

Implementation sequencing lives in `docs/design-implementation-plan.md`.

## Design Thesis

Fermo is not a generic blocker dashboard. It is a calm macOS utility for entering a work room, signing a small contract with yourself, and leaving with proof.

## First-Run Impression

The first screen should communicate:

- one task at a time;
- local-first;
- no gamification;
- no paid AI dependency;
- system permissions are explicit and understandable;
- Fermo records evidence, not points.

## Core Flow

1. Choose task type preset: Writing, Coding, Admin, Deep Planning.
2. Write task and intended outcome.
3. Choose mode:
   - Blocklist Mode: block selected distractions.
   - Focus Room Mode: allow only selected tools.
4. Choose rigor:
   - Soft: delay/friction.
   - Locked: no normal early exit.
   - Emergency: break-glass only, reason required.
5. Start session.
6. During session: show task, time remaining, room rules, and blocked/allowed state.
7. End session: capture proof or not-done reason.
8. Export local Markdown evidence log.

## Screens

- Menu bar popover.
- Today dashboard.
- Start Contract flow.
- Preset picker.
- Focus Room builder.
- Blocklist editor.
- Active session screen.
- Break-glass dialog.
- Proof capture.
- Evidence log/history.
- Permissions/onboarding.
- Preferences.
- Empty, disabled-permission, and system-error states.

## Product Shape

- The first screen is the usable app, not a marketing hero.
- Primary navigation should be compact and native: Today, Start Contract, Rooms, Evidence, System Health, Preferences.
- The dashboard should center the current or next focus contract, with permission health and recent evidence nearby.
- The menu bar popover should support quick start, active timer, stop/break-glass, and last-session status.
- System Health is a first-class screen because Network Extension, app interruption, helper persistence, and macOS approvals are part of the product truth.

## Visual Direction

- Native macOS utility, not a marketing app.
- Toolary dark chrome: calm, compact, precise.
- The main visual metaphor is a room/contract, not chains, punishment, or parental control.
- Avoid gamification, streaks, confetti, leaderboards, productivity scores, and cute mascots.
- Use familiar SF Symbols where possible: `lock.shield`, `target`, `door.left.hand.closed`, `checkmark.seal`, `doc.text`, `exclamationmark.triangle`.

## App Icon Direction

- Generate an app icon concept during the design pass.
- Use a rounded macOS app icon form.
- Prefer a dark graphite or deep ink background with one restrained green/teal accent.
- Primary concept: a protected room mark, combining a door/room outline with a shield or lock.
- Alternate concept: a signed contract page with a small shield seal.
- Avoid chains, cages, alarms, lightning bolts, mascots, streak marks, confetti, and generic productivity checkmarks.
- The implementation handoff should eventually include a production `AppIcon.appiconset`; the first pass can be a high-resolution concept image.

## Copy Tone

- Direct and adult.
- Avoid shame.
- Avoid impossible enforcement claims.
- Prefer "This session is protected" over "You cannot fail."
- Prefer "Record what happened" over "Did you win?"

## Claude Design Prompt

Design a native macOS app called Fermo for Toolary. Fermo is a focus contract app, not a generic website blocker. It helps a user choose one task, define the intended outcome, choose a local preset, enter Blocklist Mode or Focus Room Mode, set a rigor level, then finish with proof and a Markdown evidence log.

Create a polished macOS dark-mode design with these screens: menu bar popover, Today dashboard, start contract flow, preset picker, Focus Room builder, blocklist editor, active session screen, break-glass dialog, proof capture, evidence log/history, System Health/permissions, preferences, empty states, and error states.

Style: native macOS, calm Toolary dark chrome, compact utility layout, precise controls, no marketing hero, no gamification, no streaks, no confetti, no cute mascots. Use icons for tools and states. The first screen should feel usable, not explanatory.

Also create an app icon concept. Use a rounded macOS icon shape with a dark graphite/deep ink background and a simple protected-room mark: a door or room outline combined with a shield or lock. Use one restrained green/teal accent. Avoid mascots, chains, alarms, cages, confetti, streaks, scores, and generic productivity-checkmark imagery.
