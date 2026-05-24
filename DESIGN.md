# Fermo Design System

## Current Design Source

The accepted Claude Design bundle is stored at `docs/design/claude-design-2026-05-23/Fermo.html`.

Implementation handoff and sequencing live in `docs/design-implementation-plan.md`. Treat the bundle as visual direction for native SwiftUI, not as code to embed directly.

## Product Feel

Fermo should feel like a quiet macOS control room for one serious task. It is not a marketing site, a game, a parental-control product, or a shame machine. The user should feel that they are entering a protected work session, signing a small local contract, and leaving with an honest record of what happened.

The design priority is clarity under pressure: when a session is active, the app must make the current task, rules, remaining time, permission health, and exit options obvious.

## Design Principles

- Native macOS first: compact, precise, restrained, menu-bar friendly.
- One task is the center of the UI.
- Permissions and degraded states are explicit.
- Evidence is factual, not gamified.
- Use system metaphors: room, contract, proof, lock, shield, door.
- Avoid punishment metaphors: chains, alarms, cages, red panic UI, mascots, streaks, scores, confetti.

## Information Architecture

Fermo has six primary surfaces:

1. **Today**: current state, next suggested session, recent evidence.
2. **Start Contract**: task, intended outcome, preset, mode, rigor, duration.
3. **Rooms**: Focus Room allowlists and Blocklist presets.
4. **Active Session**: task, time, protected rules, permission health, break-glass path.
5. **Evidence**: completed sessions, proof, not-done reasons, Markdown export.
6. **System Health**: Network Extension, app interruption monitor, helper persistence, signing/permission state.

The first screen should be usable immediately. Do not use a landing hero, large explanatory cards, or product-tour copy as the main experience.

## Layout Direction

Use a native macOS window with a compact sidebar or segmented top navigation. The primary content should be task/session oriented, not analytics oriented.

Recommended dashboard shape:

- Top strip: current protection state and one primary action.
- Main area: active or next focus contract.
- Side or lower panel: room rules, permission health, recent evidence.
- Menu bar popover: quick start, active timer, stop/break-glass, last session.

Cards are allowed only for repeated items, modals, and contained tools. Avoid cards inside cards.

## Visual Language

- Base: dark graphite macOS chrome.
- Accent: restrained green/teal for protected/healthy states.
- Warning: amber for degraded permissions.
- Critical: red only for failed system protection or destructive break-glass confirmation.
- Surfaces: subtle contrast, thin separators, native controls.
- Typography: system font, compact macOS scale, no oversized marketing type.
- Icons: SF Symbols where possible, especially `lock.shield`, `door.left.hand.closed`, `doc.text`, `checkmark.seal`, `target`, `network`, and `exclamationmark.triangle`.

## App Icon Direction

Generate an app icon as part of the design pass. It should read clearly in the macOS Dock and menu-bar-adjacent contexts.

Preferred icon concept:

- rounded macOS app icon form;
- dark graphite or deep ink background;
- simple protected-room mark: a door or room outline combined with a shield/lock;
- one restrained accent color, preferably green/teal;
- no mascot, chains, alarm clock, cage, lightning bolt, or generic productivity checkmark.

Alternate concept:

- a signed contract page with a small shield seal, still dark and native.

The icon handoff should eventually include a production `AppIcon.appiconset` for the Xcode app target, but the first pass can be a high-resolution concept image.

## Motion

Use motion sparingly:

- session start can tighten the UI into an active protected state;
- permission health can update with subtle status changes;
- break-glass confirmation should feel deliberate, not dramatic.

No celebratory animations.

## Copy

Use direct adult language.

- Prefer: "This session is protected."
- Prefer: "Record what happened."
- Prefer: "System protection needs approval."
- Avoid: "You cannot fail."
- Avoid: "Crush distractions."
- Avoid: "Win your streak."

## Claude Design Prompt

Design a native macOS app called Fermo for Toolary. Fermo is a focus contract app, not a generic website blocker. It helps a user choose one task, define the intended outcome, choose a local preset, enter Blocklist Mode or Focus Room Mode, set a rigor level, then finish with proof and a Markdown evidence log.

Create a polished macOS dark-mode design with these screens: menu bar popover, Today dashboard, start contract flow, preset picker, Focus Room builder, blocklist editor, active session screen, break-glass dialog, proof capture, evidence log/history, system health/permissions, preferences, empty states, and error states.

The first screen should be the usable app, not a landing page. Use a compact native macOS layout with a sidebar or segmented navigation, a clear primary action, visible permission health, and restrained Toolary dark chrome. The UI should feel like a quiet control room for entering a protected work session.

Also create an app icon concept. Use a rounded macOS icon shape with a dark graphite/deep ink background and a simple protected-room mark: a door or room outline combined with a shield or lock. Use one restrained green/teal accent. Avoid mascots, chains, alarms, cages, confetti, streaks, scores, and generic productivity-checkmark imagery.

Style constraints: native macOS, calm, compact, precise controls, no marketing hero, no gamification, no paid AI, no cute mascot, no shame language. Use SF Symbols-style iconography for tools and states. The design should make technical permission states honest and understandable.
