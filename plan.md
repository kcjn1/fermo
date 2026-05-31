# Fermo Toolary Beta Plan

## Summary

Dowozić Fermo do Toolary beta jako lokalny, natywny macOS focus firewall oparty o Focus Contract. Strategia bety: direct-distribution, signed/notarized app, Network Extension dla webu, Endpoint Security dla blokowania uruchamiania aplikacji, bez płatnego AI, bez cloud sync i bez claimów "impossible to bypass".

Kolejność prac: najpierw uzyskać i zwalidować Endpoint Security entitlement oraz app-guard system extension, potem zamknąć signed-runtime matrix, potem brakujące product slices, potem dopiero pełniejszy design polish i release packaging.

## Key Changes

- Runtime Validation Gate
  - Beta jest zablokowana do czasu uzyskania Apple Endpoint Security entitlement `com.apple.developer.endpoint-security.client`.
  - Draft requestu do Apple żyje w `docs/apple-endpoint-security-entitlement-request.md`.
  - `FermoAppGuardExtension` jest dodany jako macOS System Extension, czyta aktywną politykę z app group, używa wspólnego `AppEnforcementPolicy` do decyzji allow/deny i jest embedowany w `Fermo.app` razem z Network Extension.
  - UI ma App Guard approval request w System Health, Preferences i menu bar, a diagnostics raportuje status Endpoint Security approval.
  - App Guard signing/approval checklist żyje w `docs/macos-endpoint-security-signing.md`.
  - Endpoint Security ma blokować nowe launch/relaunch aplikacji naruszających aktywny kontrakt; istniejący `AppInterruptionController` zostaje do jednorazowego cleanupu aplikacji już uruchomionych na starcie sesji.
  - Signed-build validation matrix żyje w `docs/toolary-beta-runtime-matrix.md` i obejmuje Safari, Chrome, Firefox, private/incognito, sleep/wake, Wi-Fi change, reboot/login restore, main-app quit, helper restore, stop/cleanup, update/uninstall.
  - Przed każdą betą budować przez `xcodebuild`, instalować `/Applications/Fermo.app`, sprawdzać `codesign`, `systemextensionsctl`, helper/login item, Endpoint Security approval, realne blokowanie reddit/youtube oraz deny launch dla aplikacji spoza kontraktu.
  - Każdy bug w cleanup/helper/filter ma pierwszeństwo przed UI polish.

- Product Completeness
  - Rooms/Blocklist editor: podstawowy edytor domen i app bundle IDs jest podpięty przez `PolicyEditor`, `LockedModeGuard` i istniejący runtime persistence.
  - Start Contract pozwala teraz edytować własne Focus Room allowlist i Blocklist rules poza presetami; `FocusContractRuleDraft` waliduje i deduplikuje domeny oraz app bundle IDs przed uruchomieniem sesji.
  - Schedule editor: recurring weekly sessions są zapisywane w `FermoSnapshot.schedules`, można je tworzyć/edytować/wyłączać/usuwać, a helper oraz główna aplikacja materializują due sessions po relaunch/login. Start Contract ma też jednorazowy start-later flow oparty o przyszłe sesje `scheduled` i `DueSessionActivator`.
  - Markdown evidence export: pojedynczy wpis i cały ledger zapisują się do lokalnego folderu; Preferences przechowują domyślną ścieżkę eksportu w `FermoSnapshot.preferences`.
  - Preferences/System Health mają wspólną approval checklistę, helper controls, evidence storage, default preset/rigor/duration oraz kopiowalny diagnostics report dla signed-runtime matrix. Diagnostics raportuje osobno Content Filter rule snapshot i App Guard policy snapshot.
  - Zachować user-space app interruption jako cleanup/fallback z uczciwym degraded-state copy; beta-grade blokowanie app launch wymaga Endpoint Security.

- Architecture
  - `FermoCore`: testowalne policy-editing, schedule restore, due-session activation i evidence-export API są wydzielone poza UI.
  - `FermoSystem`: trzymać wszystkie macOS adapters i runtime coordination; wspólna decyzja app enforcement żyje w `AppEnforcementPolicy`, używana zarówno przez Endpoint Security, jak i fallback interruption. `LaunchRestorePass` i `HelperRestorePass` współdzielą aktywację due sessions, żeby app launch i helper restore nie rozjeżdżały się semantycznie.
  - `FermoApp`: po stabilizacji zachowań rozbić duży `FermoApp.swift` na view model, reusable SwiftUI components i screen files.
  - `FermoFilterExtension` zostaje minimalny i snapshot-driven; reguły nadal pochodzą z `FermoCore`.

- Design & UX
  - Implementować zaakceptowany Claude Design jako natywny SwiftUI, nie web runtime.
  - Priorytet ekranów: Today, Active Session, Start Contract, Rooms editor, Evidence export, System Health, Preferences.
  - Ikona już istnieje w `AppIcon.appiconset`; przed betą tylko refinement, nie blocker techniczny.
  - Copy ma być spokojne i precyzyjne: "protected session", "break glass", "degraded", "requires approval"; bez gamifikacji i bez wstydu.

- Beta Release
  - Release notes i privacy/catalog copy w EN/PL/DE są przygotowane jako drafty w `docs/release-notes.md` i `docs/toolary-beta-copy.md`; do publikacji nadal potrzeba signed + notarized `.app`, ZIP i SHA-256.
  - `scripts/check-release-copy.sh` pilnuje, żeby release notes i Toolary copy miały wymagane sekcje EN/PL/DE, wersję oraz lokalizowane title/shortDescription zgodne z Toolary metadata, privacy/permissions, beta constraints i nie zawierały mocnych claimów o odporności na obejście.
  - `scripts/check-endpoint-security-request.sh` pilnuje spójności Apple Endpoint Security request packet z bundle IDs, App Group, entitlement source, minimalnym `AUTH_EXEC` scope, privacy boundaries i signing checklistą.
  - `scripts/export-endpoint-security-request-packet.sh` wymaga pustego output dir i eksportuje gotowy katalog requestu do Apple z draftem requestu, signing checklistą, App Guard entitlements, Xcode/App Guard source summary i `PACKET.md`, po przejściu `scripts/check-endpoint-security-request.sh`.
  - `scripts/check-endpoint-security-request-packet.sh` eksportuje i waliduje Apple request packet, żeby wysyłany do Apple katalog zawierał request, checklistę, entitlements i Xcode/App Guard source summary zgodne z aktualnym repo, a skopiowane pliki request/checklist/entitlements były dokładnie tymi samymi plikami co źródła w repo.
  - `scripts/export-signed-beta-operator-packet.sh` wymaga pustego output dir i eksportuje katalog dla signing Maca: release runbook, runtime matrix template, release notes, Toolary copy, metadata draft i `SIGNED_RELEASE_COMMANDS.md` z kolejnością signed release komend.
  - `scripts/check-signed-beta-operator-packet.sh` eksportuje i waliduje signed beta operator packet, porównuje skopiowany runbook/matrix/release copy/metadata z plikami źródłowymi repo oraz pilnuje, żeby finalny signed readiness wrapper nadal odpalał signed runtime approvals.
  - `docs/toolary-beta-release-runbook.md` spina operacyjny release path: local readiness, Apple entitlement/profiles, signed `/Applications/Fermo.app`, runtime matrix, artifact gates, Toolary metadata flip i rollback rule; `scripts/check-beta-release-runbook.sh` pilnuje, żeby ten runbook nie zgubił krytycznych blockerów ani finalnych komend.
  - `scripts/check-beta-blocker-audit.sh` pilnuje, żeby obecny stan nadal uczciwie blokował publikację: metadata ma zostać `comingSoon`, a runbook/matrix/roadmap muszą wymieniać Apple entitlement, signed/notarized app, macOS approvals i completed signed runtime matrix jako brakujące dowody.
  - `scripts/package-beta-candidate.sh` wymaga pustego candidate output dir, który nie jest symlinkiem ani fizycznie nie rozwiązuje się wewnątrz app bundle, tworzy candidate ZIP, SHA-256 i manifest; odrzuca nieznane `FERMO_RELEASE_CHANNEL`, `FERMO_RUNTIME_MATRIX_STATUS` i `FERMO_SKIP_SIGNATURE_CHECKS`, a kanał `beta` jest blokowany, jeśli app path nie jest dokładnie `/Applications/Fermo.app`, podpis/notary są pominięte, runtime matrix nie ma statusu `passed`, nie ma prawdziwego numerycznego Version/Build z `Info.plist` lub env, wersja/build to placeholder `0.0.0/0`, manifest nie może być przypięty do prawdziwego git SHA albo git tree nie jest clean.
  - `scripts/prepare-beta-runtime-matrix.sh` wypełnia pola Candidate Build w runtime matrixie z manifestu artefaktu, żeby ZIP/SHA/version/build nie były przepisywane ręcznie, odrzuca niepełne albo checksum-mismatched manifesty i nie zapisuje runtime matrix outputu, który już istnieje albo fizycznie rozwiązuje się wewnątrz app bundle.
  - `scripts/check-runtime-matrix-template.sh` pilnuje, żeby template signed-runtime matrix nadal zawierał wymagane sekcje i wiersze dla preflight, approval, browserów, Content Filter/App Guard diagnostic snapshots, lifecycle, product slices, update/uninstall i release gate.
  - `scripts/check-release-guardrails.sh` testuje negatywne ścieżki publikacji: beta packaging odrzuca skip podpisu, pending matrix, path inny niż `/Applications/Fermo.app`, brak version/build i placeholder `0.0.0/0`, final signed readiness i signed runtime approvals odrzucają skip podpisu oraz path inny niż `/Applications/Fermo.app`, Endpoint Security request packet odrzuca złą liczbę argumentów i waliduje eksport, candidate preflight odrzuca nadmiarowe argumenty i rozjazdy embedded bundle identifiers, signed preflight jawnie weryfikuje top-level app plus każdy osadzony extension/helper bundle, release gate odrzuca brakujący lub niekanoniczny manifestowy App path, niekanoniczny ZIP basename, placeholdery manifestu, nieprzechodzące statusy, brakujące wiersze/evidence diagnostyczne Content Filter i App Guard, rozjazdy Channel/Date/Git/Version/Build/App path/ZIP/SHA/Toolary publishable/checksum między manifestem, matrixem i artefaktem, checksum file wskazujący inną nazwę ZIP-a albo więcej niż jeden ZIP entry oraz puste signed-build audit fields, Toolary `beta` metadata wymaga manifestu, completed matrix, zgodności wersji z artefaktem i nieosłabionych pól `releaseGate`, release notes muszą pasować do metadata version, a Xcode target versions i bundle IDs muszą pozostać spójne.
  - `scripts/check-dogfood-package-flow.sh` lokalnie pakuje unsigned dogfood/dev artifact, sprawdza spójność ZIP/SHA/manifest, przygotowuje runtime matrix draft i potwierdza, że Toolary metadata pozostaje niepublikowalne.
  - `scripts/check-xcode-entitlements.sh` statycznie sprawdza źródłowe entitlements, oczekiwane bundle IDs, Xcode build settings dla app group, Network Extension, System Extension i Endpoint Security oraz spójne `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` przed signed buildem.
  - `scripts/check-signed-build-environment.sh` opcjonalnie sprawdza signing Mac: Developer ID Application identity dla teamu, `notarytool`, Xcode team/app-group/bundle ID settings i notary profile hint, odrzucając placeholder `FERMO_NOTARYTOOL_PROFILE` oraz placeholder/malformed `--team-id`, bez blokowania unsigned local readiness.
  - `scripts/install-signed-beta-app.sh` instaluje podpisany kandydacki `Fermo.app` dokładnie do `/Applications/Fermo.app`, a installer i signed operator packet wymagają prawdziwego signed app bundle jako źródła, nie DerivedData/Build Products, symlinka ani niczego, co fizycznie rozwiązuje się wewnątrz `/Applications/Fermo.app`. Installer blokuje skipped signature checks, waliduje `FERMO_REPLACE_APPLICATIONS_APP=0|1` i wymaga jawnego `FERMO_REPLACE_APPLICATIONS_APP=1` przy nadpisaniu istniejącej aplikacji albo istniejącego symlinka.
  - `scripts/notarize-signed-beta-app.sh` wymaga prawdziwego `FERMO_NOTARYTOOL_PROFILE`, odrzuca angle-bracket placeholdery i pusty notary output dir, który nie jest symlinkiem ani fizycznie nie rozwiązuje się wewnątrz `/Applications/Fermo.app`, tworzy ZIP submitu z zainstalowanego `/Applications/Fermo.app`, odpala `notarytool submit --wait`, sprawdza log przez `scripts/check-notarytool-log.sh`, który wymaga `status: Accepted` oraz UUID w polu notarytool `id`, zapisuje `notary-request-id.txt`, stapluje ticket, uruchamia `spctl` i ponownie sprawdza signed candidate preflight.
  - `scripts/check-signed-helper-runtime.sh` sprawdza signed `/Applications/Fermo.app`, obecność login item, `launchctl print gui/<uid>/com.toolary.fermo.helper` i działający proces `FermoHelper`; `scripts/check-signed-runtime-approvals.sh` odpala go razem ze sprawdzeniem Network Extension i App Guard approval.
  - `scripts/collect-signed-runtime-evidence.sh` zbiera dla podpisanego `/Applications/Fermo.app` `signed-runtime-evidence.md`, `signed-runtime-evidence.sha256` oraz raw outputy signed preflight, `spctl`, `systemextensionsctl`, helper runtime, `launchctl` i `pgrep` do pustego katalogu, który nie jest symlinkiem ani fizycznie nie rozwiązuje się wewnątrz `/Applications/Fermo.app`, a `scripts/check-signed-runtime-evidence.sh` waliduje dokładny zestaw plików przed archiwizacją, wymaga żeby `signed-runtime-evidence.sha256` listował każdy captured file poza samym sobą, odrzuca symlinkowany katalog dowodów oraz nieoczekiwane pliki/katalogi/symlinki/pliki specjalne w środku i z manifestem sprawdza zgodność Version/Build, żeby manual matrix miał jeden audytowalny katalog dowodów przypięty do właściwego artefaktu.
  - `scripts/check-app-copy-guardrails.sh` pilnuje, żeby aplikacja nie wróciła do zbyt mocnych beta-readiness claimów ani user-facing spike copy oraz żeby copyable diagnostics nadal zawierały Content Filter i App Guard snapshot fields.
  - `scripts/check-local-release-readiness.sh` agreguje lokalne dogfood/dev checks: składnię skryptów, release copy gate, Endpoint Security request gate i packet export gate, beta release runbook gate, runtime matrix template gate, app copy guardrails, release guardrails, source entitlements gate, Toolary metadata gate, `swift test`, `swift build`, unsigned `xcodebuild`, unsigned candidate preflight i dogfood/dev package flow.
  - `scripts/check-beta-release-gate.sh` blokuje publikację, jeśli manifest nie jest `beta`, manifestowy App path nie jest dokładnie `/Applications/Fermo.app`, checksum nie pasuje, ZIP nie istnieje, Created/Date nie są timestampami UTC `YYYY-MM-DDTHH:MM:SSZ`, Version/Build są nienumeryczne albo placeholderami `0.0.0/0`, Date/Git/Version/Build/ZIP/SHA w matrixie nie zgadzają się z manifestem, brakuje wierszy App Guard/Content Filter diagnostic snapshot albo `appGuardSnapshotState: ready` / `contentFilterSnapshotState: ready`, signed-build audit fields są puste, runtime matrix nadal zawiera case-insensitive `Pending`/`TODO`/`TBD` albo jakikolwiek status tabeli nie jest `Passed`/`passed`.
  - `scripts/check-candidate-manifest-app.sh` sprawdza, czy manifestowy `App path`, `Version` i `Build` opisują faktyczny bundle `.app`.
  - `scripts/check-signed-beta-readiness.sh` spina finalny signed release pass, wymusza dokładnie `/Applications/Fermo.app` i sprawdza zgodność manifestowego `App path`/`Version`/`Build`: release copy gate, signed runtime approvals, signed/notarized app, beta manifest + completed matrix i Toolary metadata ustawione na `beta`.
  - `scripts/archive-beta-release-evidence.sh` wymaga pustego evidence dir, który nie jest symlinkiem ani fizycznie nie rozwiązuje się wewnątrz `/Applications/Fermo.app`, i po przejściu finalnego signed readiness zapisuje `release-evidence.md` oraz kopie manifestu, completed matrix, metadata, checksum file, opcjonalnego notarytool log, SHA-256 notarytool logu, signed runtime evidence i SHA-256 jego manifestu `signed-runtime-evidence.sha256`, żeby publikowany ZIP/SHA miał jeden audytowalny pakiet dowodowy; `scripts/check-beta-release-evidence-archive.sh` sprawdza później, że kopie nadal pasują do źródłowych release files i manifestowego ZIP/SHA, że source basenames są unikalne i nie kolidują z zarezerwowanymi wpisami archive, że archived checksum copy zawiera dokładnie jeden ZIP entry dla wygenerowanego ZIP basename, że signed runtime evidence copy pasuje do źródła, że archive nie jest symlinkowany i nie zawiera nieoczekiwanych plików/katalogów/symlinków/special files oraz że `Notarization request ID` w matrixie zgadza się z UUID z notarytool logu.
  - `scripts/check-final-beta-publication-evidence.sh` jest ostatnim evidence gate przed publiczną betą: wymaga kompletnego archiwum, notarytool logu, signed runtime evidence dir i Toolary metadata ze statusem `beta`, żeby archive checker nie został uruchomiony w zbyt miękkim trybie opcjonalnych dowodów.
  - `scripts/export-final-beta-publication-packet.sh` eksportuje finalny upload-ready katalog z ZIP, `.sha256`, manifestem, completed matrix, metadata, `release-evidence.md`, notarytool logiem, signed runtime evidence, `PUBLICATION_PACKET.md` i `publication-packet.sha256`; wymaga pustego katalogu wyjściowego, który nie jest symlinkiem ani fizycznie nie rozwiązuje się wewnątrz `/Applications/Fermo.app`, a `scripts/check-final-beta-publication-packet.sh` sprawdza, że katalog nadal pasuje do źródłowych artefaktów/evidence, source basenames są unikalne i nie kolidują z zarezerwowanymi wpisami packet, `publication-packet.sha256` listuje każdy plik pakietu poza samym sobą, katalog nie jest symlinkowany i nie zawiera nieoczekiwanych plików, katalogów, symlinków ani plików specjalnych.
  - Toolary metadata draft żyje w `docs/toolary-catalog-metadata.json`; `scripts/check-toolary-metadata-gate.sh` pozwala bezpiecznie trzymać `comingSoon`, wymusza `releaseChannel: beta`, `distribution: direct-macos` i wymagane pola `releaseGate`, waliduje manifest + runtime matrix nawet przed zmianą statusu z `comingSoon` na `beta`, oraz blokuje status `beta`, jeśli artifact gate nie przejdzie albo metadata `version` nie zgadza się z manifestowym `Version`.
  - Toolary metadata pozostaje `comingSoon` aż artifact jest podpisany, notarized, sprawdzony i ma checksum.
  - Beta może iść publicznie dopiero po pełnym manual matrix pass; w przeciwnym razie status zostaje dogfood/dev.

## Test Plan

- `swift test` dla każdego core/system slice.
- `swift build` po każdej większej zmianie SwiftPM.
- `xcodebuild -project Fermo.xcodeproj -scheme Fermo -destination 'platform=macOS' build` przed signed runtime checks.
- Core tests: policy editing, locked mutation rejection, Focus Room allow/block behavior, schedules, evidence export.
- System tests: runtime cleanup, helper restore decisions, website snapshot refresh, Endpoint Security allow/deny decision logic, app interruption fallback target selection.
- Manual beta matrix: Safari, Chrome, Firefox, private/incognito, Endpoint Security app launch/relaunch deny, sleep/wake, Wi-Fi change, reboot/login, main-app quit, stop cleanup, uninstall/update behavior.

## Review Hardening (2026-05-31)

Code-side correctness fixes applied after an adversarial review, all covered by tests and the
local readiness gate:

- App Guard Endpoint Security now resolves the launching process's real `CFBundleIdentifier`
  from its executable's enclosing `.app` (falling back to `signing_id`), so launch decisions
  match the bundle identifiers Fermo policy is authored against; unidentifiable launches are
  denied inside an active Focus Room. (`AppBundleIdentifierResolver`, `AppEnforcementPolicy`.)
- `scripts/check-beta-release-gate.sh` no longer false-fails a correctly completed runtime
  matrix: the `Pending/TODO/TBD` scan exempts the leading instructional prose, scans from the
  first table row onward (still catching `| Pending |` cells and operator-appended notes), and
  matches only standalone words so "appending"/"spending" do not trip it.
- `scripts/check-notarytool-log.sh` reads the final anchored `status:` line, so a
  `notarytool submit --wait` log that streams `Current status: In Progress` before `Accepted`
  is no longer misread as `In`.
- `EvidenceRecorder` rejects break-glass on soft or already-ended sessions (it only applies to
  an active Locked/Emergency session), preventing a silent downgrade to `cancelled`.
- Domain dedup is unified on normalized patterns across `FocusContractRuleDraft`,
  `PolicyEditor`, and `ContentFilterRuleSnapshot`; `AppRule` identity and enforcement matching
  are case-insensitive on the bundle identifier.
- `WeeklySchedule` can express Focus Room mode (migration-safe `mode`/`allowedDomains`/
  `allowedApps`); occurrences materialize a Focus Room contract. Editor-UI exposure is tracked
  in `docs/design-implementation-plan.md`.
- `Xcode/Configs/DevelopmentTeam.xcconfig.example` app-group value aligned to the team-prefixed
  macOS format; the ledger export collision loop is bounded with a unique fallback.

## Assumptions

- Target release is Toolary beta, not only personal dogfood and not full paid V1.
- Beta waits for Endpoint Security entitlement and signed runtime validation; user-space process interruption alone is not beta-ready app enforcement.
- Distribution is direct macOS app distribution, likely non-sandboxed containing app, with sandboxed Network Extension target.
- No paid AI, cloud sync, mobile apps, teams, streaks, gamification, or impossible-enforcement claims in V1.
- Firefox must be installed or tested on a Mac with Firefox before any beta claim.
