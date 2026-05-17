# Fermo PRD

## Summary

Fermo is a native macOS focus blocker for people who need environmental friction against distracting websites and apps during planned work sessions. It starts as a personal tool and can later ship through Toolary as a paid-beta Mac utility.

## Audience

- Primary: the founder/user, dogfooding on a daily Mac.
- Secondary: Toolary paid-beta users who want a local-first focus blocker.

## Problem

Willpower is unreliable when high-friction work and low-friction distractions share the same machine. Existing blockers prove the category, but Fermo should become a Toolary-native option with a calm Mac utility feel, transparent permissions, and no gamified attention loops.

## MVP Scope

- Create and edit blocklists containing domains and macOS apps.
- Start one-time focus sessions.
- Schedule sessions for later.
- Create weekly recurring schedules.
- Enable Locked Mode for sessions that should not be ended early through normal UI.
- Block websites and interrupt selected apps during active sessions after the macOS spike passes.
- Show permission and degraded-state UI when system integrations are unavailable.
- Keep data local by default.

## Non-Goals

- No cross-device sync in V1.
- No iOS, Windows, Android, or browser-extension-only product in V1.
- No team/family controls.
- No focus sounds, streaks, leaderboards, points, or social rewards.
- No claims that enforcement is impossible to bypass.

## Success Criteria

- Core rules and schedules are covered by unit tests.
- A signed macOS build blocks target domains across Safari, Chrome, and Firefox.
- App interruption works for selected bundle identifiers during active sessions.
- Helper persistence survives main-app quit and sleep/wake.
- Locked Mode blocks normal early termination of active locked sessions.
- Toolary catalog metadata remains `comingSoon` until a signed, notarized, checksummed beta artifact exists.
