# Fermo Toolary Beta Plan

## Summary

Dowozić Fermo do Toolary beta jako lokalny, natywny macOS focus firewall oparty o Focus Contract. Strategia bety: direct-distribution, signed/notarized app, user-space app interruption, bez Endpoint Security, bez płatnego AI, bez cloud sync i bez claimów "impossible to bypass".

Kolejność prac: najpierw zamknąć signed-runtime matrix, potem brakujące product slices, potem dopiero pełniejszy design polish i release packaging.

## Key Changes

- Runtime Validation Gate
  - Utworzyć jedną checklistę signed-build validation dla Safari, Chrome, Firefox, private/incognito, sleep/wake, Wi-Fi change, reboot/login restore, main-app quit, helper restore, stop/cleanup, update/uninstall.
  - Przed każdą betą budować przez `xcodebuild`, instalować `/Applications/Fermo.app`, sprawdzać `codesign`, `systemextensionsctl`, helper/login item i realne blokowanie reddit/youtube oraz dozwolonych domen.
  - Każdy bug w cleanup/helper/filter ma pierwszeństwo przed UI polish.

- Product Completeness
  - Dodać realny Rooms/Blocklist editor: domeny, app bundle IDs, Focus Room allowlist, guarded mutations przez `LockedModeGuard`, persistence przez istniejący `FermoStore`/runtime.
  - Dodać schedule editor: start later + recurring weekly sessions, zapis w `FermoSnapshot.schedules`, restore przez helper po relaunch/login.
  - Dodać Markdown evidence export: lokalny wybór ścieżki, domyślne miejsce w Preferences, export pojedynczej sesji i całego ledger.
  - Rozbudować Preferences/onboarding: permission health, helper controls, default preset/rigor/duration, evidence path, diagnostics copy.
  - Zachować app interruption jako beta feature z uczciwym degraded-state copy, bez Endpoint Security w V1.

- Architecture
  - `FermoCore`: dodać testowalne policy-editing i schedule-use-case API zamiast mutacji rozsypanych po UI.
  - `FermoSystem`: trzymać wszystkie macOS adapters i runtime coordination; rozszerzyć obecny runtime tylko tam, gdzie dotyczy helper/schedule/cleanup.
  - `FermoApp`: po stabilizacji zachowań rozbić duży `FermoApp.swift` na view model, reusable SwiftUI components i screen files.
  - `FermoFilterExtension` zostaje minimalny i snapshot-driven; reguły nadal pochodzą z `FermoCore`.

- Design & UX
  - Implementować zaakceptowany Claude Design jako natywny SwiftUI, nie web runtime.
  - Priorytet ekranów: Today, Active Session, Start Contract, Rooms editor, Evidence export, System Health, Preferences.
  - Ikona już istnieje w `AppIcon.appiconset`; przed betą tylko refinement, nie blocker techniczny.
  - Copy ma być spokojne i precyzyjne: "protected session", "break glass", "degraded", "requires approval"; bez gamifikacji i bez wstydu.

- Beta Release
  - Przygotować signed + notarized `.app`, ZIP, SHA-256, release notes i privacy copy w EN/PL/DE.
  - Toolary metadata pozostaje `comingSoon` aż artifact jest podpisany, notarized, sprawdzony i ma checksum.
  - Beta może iść publicznie dopiero po pełnym manual matrix pass; w przeciwnym razie status zostaje dogfood/dev.

## Test Plan

- `swift test` dla każdego core/system slice.
- `swift build` po każdej większej zmianie SwiftPM.
- `xcodebuild -project Fermo.xcodeproj -scheme Fermo -destination 'platform=macOS' build` przed signed runtime checks.
- Core tests: policy editing, locked mutation rejection, Focus Room allow/block behavior, schedules, evidence export.
- System tests: runtime cleanup, helper restore decisions, website snapshot refresh, app interruption target selection.
- Manual beta matrix: Safari, Chrome, Firefox, private/incognito, sleep/wake, Wi-Fi change, reboot/login, main-app quit, stop cleanup, uninstall/update behavior.

## Assumptions

- Target release is Toolary beta, not only personal dogfood and not full paid V1.
- Beta accepts user-space process interruption for app blocking; Endpoint Security is deferred.
- Distribution is direct macOS app distribution, likely non-sandboxed containing app, with sandboxed Network Extension target.
- No paid AI, cloud sync, mobile apps, teams, streaks, gamification, or impossible-enforcement claims in V1.
- Firefox must be installed or tested on a Mac with Firefox before any beta claim.
