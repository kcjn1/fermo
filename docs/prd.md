# Fermo PRD

## Summary

Fermo is a native macOS focus blocker built around task-specific focus contracts. Instead of only asking which distractions to block, Fermo asks what work should be done, what result will prove it, which tools belong in the room, and how strict the commitment should be.

## Audience

- Primary: the founder/user, dogfooding on a daily Mac.
- Secondary: Toolary paid-beta users who want a local-first focus blocker.

## Problem

Willpower is unreliable when high-friction work and low-friction distractions share the same machine. Existing blockers prove the category, but Fermo should become a Toolary-native option with a calm Mac utility feel, transparent permissions, and no gamified attention loops.

## Product Difference

Fermo should not compete by being "Freedom but stricter." Its wedge is the focus contract:

- choose one task;
- write the intended outcome;
- choose a local offline preset such as Writing, Coding, Admin, or Deep Planning;
- choose Blocklist Mode or Focus Room Mode;
- choose rigor: Soft, Locked, or Emergency;
- finish with proof or a reason it did not ship;
- export the session as a local Markdown evidence log.

## MVP Scope

- Create and edit blocklists containing domains and macOS apps.
- Create a focus contract before each session: task, intended outcome, mode, rigor, and allowed tools.
- Use local task presets without paid AI calls.
- Support Focus Room Mode, where everything is blocked except allowed websites/apps.
- Start one-time focus sessions.
- Schedule sessions for later.
- Create weekly recurring schedules.
- Support three commitment levels: Soft, Locked, and Emergency.
- Require lightweight proof/result capture at session end.
- Export session evidence logs as Markdown.
- Block websites and interrupt selected apps during active sessions after the macOS spike passes.
- Show permission and degraded-state UI when system integrations are unavailable.
- Keep data local by default.

## Non-Goals

- No cross-device sync in V1.
- No iOS, Windows, Android, or browser-extension-only product in V1.
- No team/family controls.
- No focus sounds, streaks, leaderboards, points, or social rewards.
- No paid AI dependency in V1. Lightweight local models can be reconsidered later, but V1 should work through deterministic local presets.
- No claims that enforcement is impossible to bypass.

## Success Criteria

- Core rules and schedules are covered by unit tests.
- A signed macOS build blocks target domains across Safari, Chrome, and Firefox.
- App interruption works for selected bundle identifiers during active sessions.
- Helper persistence survives main-app quit and sleep/wake.
- Locked Mode blocks normal early termination of active locked sessions.
- Focus Room Mode blocks unapproved domains/apps while allowing the selected room tools.
- Session completion captures proof or a not-done reason.
- Evidence logs render as local Markdown.
- Toolary catalog metadata remains `comingSoon` until a signed, notarized, checksummed beta artifact exists.
