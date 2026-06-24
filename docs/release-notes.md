# Fermo Release Notes

## 0.1.0 beta candidate draft

Status: not published. Use only after the signed Toolary beta runtime matrix passes and `scripts/package-beta-candidate.sh` produces a notarized ZIP, SHA-256 checksum, and manifest.

### EN

Fermo 0.1.0 introduces protected focus contracts for macOS. Choose a task, define the outcome, enter a Focus Room or Blocklist session, and leave with local Markdown evidence.

Included in this candidate:

- Native macOS app with menu bar and window UI.
- Website blocking through a macOS Network Extension.
- App launch policy scaffold through an Endpoint Security system extension.
- Helper restore for active sessions after the main app quits or relaunches.
- Focus Room and Blocklist rules with editable rooms.
- One-off start-later sessions and recurring weekly schedules.
- Local evidence log and Markdown export.
- System Health and diagnostics report for permissions and runtime state.

Known beta constraints:

- Requires macOS permission approval for system extensions and network filtering.
- App launch denial requires Apple Endpoint Security entitlement and signed approval.
- No cloud sync, paid AI, mobile app, teams, streaks, or impossible-to-bypass claims.

### PL

Fermo 0.1.0 wprowadza chronione kontrakty skupienia dla macOS. Wybierz zadanie, określ wynik, wejdź do Focus Room albo sesji Blocklist i zakończ pracę lokalnym dowodem w Markdown.

W tej wersji kandydującej:

- Natywna aplikacja macOS z menu bar i oknem.
- Blokowanie stron przez macOS Network Extension.
- Szkielet polityki blokowania uruchamiania aplikacji przez Endpoint Security system extension.
- Helper przywracający aktywne sesje po zamknięciu lub ponownym uruchomieniu głównej aplikacji.
- Focus Room i Blocklist z edytowalnymi pokojami.
- Jednorazowe sesje start-later i cykliczne tygodniowe harmonogramy.
- Lokalny dziennik dowodów i eksport Markdown.
- System Health oraz raport diagnostyczny dla uprawnień i stanu runtime.

Ograniczenia bety:

- Wymaga zgód macOS dla system extensions i filtrowania sieci.
- Blokowanie uruchamiania aplikacji wymaga Apple Endpoint Security entitlement oraz podpisanego approval flow.
- Bez cloud sync, płatnego AI, aplikacji mobilnej, zespołów, streaków i obietnic "nie do obejścia".

### DE

Fermo 0.1.0 fuehrt geschuetzte Fokusvertraege fuer macOS ein. Waehle eine Aufgabe, beschreibe das Ziel, starte einen Focus Room oder eine Blocklist-Sitzung und beende die Arbeit mit einem lokalen Markdown-Nachweis.

In diesem Release Candidate enthalten:

- Native macOS App mit Menueleiste und Fenster-UI.
- Website-Blocking ueber eine macOS Network Extension.
- App-Launch-Policy als Scaffold ueber eine Endpoint-Security-Systemerweiterung.
- Helper zur Wiederherstellung aktiver Sitzungen nach dem Beenden oder Neustart der Haupt-App.
- Focus Room und Blocklist Regeln mit editierbaren Raeumen.
- Einmalige Start-later-Sitzungen und wiederkehrende Wochenplaene.
- Lokales Evidence Log und Markdown Export.
- System Health und Diagnosebericht fuer Berechtigungen und Runtime-Zustand.

Bekannte Beta-Einschraenkungen:

- Benoetigt macOS-Freigaben fuer Systemerweiterungen und Netzwerkfilterung.
- App-Launch-Denial benoetigt Apples Endpoint-Security-Entitlement und einen signierten Approval Flow.
- Kein Cloud Sync, keine bezahlte KI, keine Mobile App, keine Teams, keine Streaks und keine "unmoeglich zu umgehen" Versprechen.

## 0.1.0-dev

- Created initial Swift package scaffold.
- Added core domain model for blocklists, rules, sessions, schedules, policy, and Locked Mode.
- Added task-first focus contracts, Focus Room mode, local presets, rigor levels, and Markdown evidence-log rendering.
- Added minimal SwiftUI/menu-bar shell.
- Added macOS integration adapter stubs for the technical spike.

This is not a beta release. It is a development scaffold.
