# Fermo Claude Design Handoff 2026-05-23

This folder stores the Claude Design bundle used as the implementation reference for the native macOS UI pass.

Open locally:

```sh
cd docs/design/claude-design-2026-05-23
python3 -m http.server 8797 --bind 127.0.0.1
open http://127.0.0.1:8797/Fermo.html
```

## Verdict

Accepted as the direction for Fermo's app UI.

The bundle matches the product plan:

- native macOS dark utility, not a marketing page;
- menu bar popover plus full window;
- Today, Start Contract, Rooms, Active Session, Evidence, System Health, Preferences;
- explicit permission/degraded/unverified states;
- honest copy around macOS enforcement;
- no paid AI, no gamification, no beta-readiness claims;
- app icon concept based on protected room + contract seal.

## Corrections Applied

Before storing the bundle in the repo, the following fixes were made:

- added missing local icons for `copy`, `download`, and `trash`;
- removed negative letter spacing from the design source so SwiftUI implementation should keep letter spacing at `0`;
- changed reboot copy from "will reload on reboot" to an unverified/manual-check claim;
- replaced placeholder team/build copy with the current local spike values: Team ID `MP3AWS77U3`, build `0.1.0/3`;
- changed the SwiftUI persistence handoff from "use SwiftData" to "start from the existing FermoCore JSON/app-group stores";
- added `.design-canvas.state.json` so the preview loads without a 404.

The only browser console warning left in preview is the expected Babel-in-browser warning from this static design artifact.

## App Icon

The protected-room/contract-seal concept has been converted into the native macOS app icon asset at `Xcode/Fermo/Assets.xcassets/AppIcon.appiconset/`.

The source vector lives at `docs/design/fermo-app-icon.svg`. Re-render PNG sizes with:

```sh
for size in 16 32 64 128 256 512 1024; do
  /opt/homebrew/bin/rsvg-convert -w "$size" -h "$size" docs/design/fermo-app-icon.svg \
    -o "Xcode/Fermo/Assets.xcassets/AppIcon.appiconset/app-icon-${size}.png"
done
```

## Implementation Rule

Do not copy the JSX/CSS directly into the macOS app. Treat it as a visual and structural reference. Implement with native SwiftUI/AppKit controls, SF Symbols, `MenuBarExtra`, and the existing `FermoCore`/`FermoSystem` boundaries.

Keep these constraints during implementation:

- no beta-ready copy;
- no claims that blocking is impossible to bypass;
- manual checks remain visible: sleep/wake, reboot/login, Wi-Fi changes, Firefox, private/incognito;
- no paid AI;
- no gamification;
- no card-in-card layouts.
