#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/path/to/toolary-beta-runtime-matrix.md]\n' "$0"
  printf '\n'
  printf 'Validates that the Toolary beta runtime matrix template still covers\n'
  printf 'the required signed-build, browser, App Guard, lifecycle, product, and release rows.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 64
fi

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
matrix_path="${1:-$repo_root/docs/toolary-beta-runtime-matrix.md}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_file() {
  path="$1"
  label="$2"

  if [ ! -s "$path" ]; then
    fail "$label missing or empty at $path"
  fi
}

require_text() {
  label="$1"
  expected="$2"

  if ! grep -F -- "$expected" "$matrix_path" >/dev/null; then
    fail "runtime matrix template missing $label: $expected"
  fi
}

require_file "$matrix_path" "runtime matrix template"

for section in \
  "## Candidate Build" \
  "## Preflight" \
  "## macOS Approval" \
  "## Website Blocking" \
  "## App Launch Blocking" \
  "## Lifecycle" \
  "## Product Slices" \
  "## Update / Uninstall" \
  "## Release Gate"; do
  require_text "$section section" "$section"
done

for field in \
  "- Date:" \
  "- Channel:" \
  "- Version:" \
  "- Build:" \
  "- Git commit:" \
  "- Git tree:" \
  "- App path:" \
  "- Signing identity:" \
  "- Team ID:" \
  "- Notarization request ID:" \
  "- ZIP path:" \
  "- SHA-256:" \
  "- Toolary publishable:" \
  "- Tester Mac:" \
  "- macOS version:"; do
  require_text "$field candidate field" "$field"
done

require_text "installed app preflight" "| App installed from candidate artifact |"
require_text "signed install command" "scripts/install-signed-beta-app.sh <signed-export>/Fermo.app"
require_text "signed build environment preflight" "scripts/check-signed-build-environment.sh"
require_text "signed build environment team id guardrail" "real 10-character Apple team ID"
require_text "signed build environment team id placeholder rejection" "placeholder or malformed team IDs are rejected before signing identity lookup"
require_text "signed notarization command" "scripts/notarize-signed-beta-app.sh /Applications/Fermo.app <notary-output-dir>"
require_text "notary output empty directory" 'notary output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before notarization'
require_text "notary profile placeholder rejection" "angle-bracket placeholders are rejected before notarization starts"
require_text "notarytool log gate command" "scripts/check-notarytool-log.sh <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log"
require_text "notarytool id field gate" 'UUID request ID in the notarytool `id` field'
require_text "notary request ID file" "notary-request-id.txt"
require_text "signature preflight" "| App signature |"
require_text "notarization preflight" "| App notarization |"
require_text "system extension preflight" "com.toolary.fermo.appguard.systemextension"
require_text "helper preflight" "| Login item helper embedded |"
require_text "Toolary metadata preflight" "| Toolary metadata |"

require_text "Network Extension approval" "| Network Extension approval |"
require_text "Endpoint Security approval" "| Endpoint Security approval |"
require_text "signed runtime approvals command" "scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app"
require_text "signed helper runtime command" "scripts/check-signed-helper-runtime.sh /Applications/Fermo.app"
require_text "signed runtime evidence empty output directory" 'signed runtime evidence output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before collection'
require_text "signed runtime evidence checksum manifest coverage" 'signed-runtime-evidence.sha256` must list every captured file except itself'
require_text "signed runtime evidence rejects root symlink" "rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it"
require_text "App Guard approval UI" "| App Guard approval UI |"
require_text "App Guard diagnostics snapshot" "| App Guard policy snapshot |"
require_text "App Guard diagnostics field" "appGuardSnapshotState: ready"
require_text "Content Filter diagnostics snapshot" "| Content Filter rule snapshot |"
require_text "Content Filter diagnostics field" "contentFilterSnapshotState: ready"
require_text "runtime onboarding checklist" "| Runtime onboarding checklist |"
require_text "helper registration" "| Helper registration |"
require_text "helper running process" "FermoHelper process is running"

require_text "private/incognito browser column" "Private / Incognito"
require_text "Safari browser row" "| Safari |"
require_text "Chrome browser row" "| Chrome |"
require_text "Firefox browser row" "| Firefox |"
require_text "blocked website URLs" "https://www.reddit.com"
require_text "allowed website URL" "https://example.com"

require_text "blocked app launch" "| Launch blocked app while session is active |"
require_text "blocked app relaunch" "| Relaunch blocked app after fallback interruption |"
require_text "allowed Focus Room app launch" "| Launch allowed Focus Room app |"
require_text "critical macOS shell apps" "| Launch critical macOS shell apps |"
require_text "Fermo self-allow" "| Launch Fermo and FermoHelper |"
require_text "Endpoint Security stale cache cleanup" "no stale Endpoint Security cache"
require_text "Locked/Emergency break glass" "| Break glass on Locked/Emergency session |"

require_text "main app quit lifecycle" "| Main app quit during active session |"
require_text "main app relaunch lifecycle" "| Main app relaunch during active session |"
require_text "sleep wake lifecycle" "| Sleep / wake during active session |"
require_text "Wi-Fi change lifecycle" "| Wi-Fi network change during active session |"
require_text "reboot login active session" "| Reboot / login during active session |"
require_text "reboot login weekly schedule" "| Reboot / login before due weekly schedule |"
require_text "missed one-off schedule" "| Missed one-off scheduled session |"
require_text "stop cleanup lifecycle" "| Stop cleanup |"

require_text "Rooms editor product slice" "| Rooms editor |"
require_text "custom rules product slice" "| Start Contract custom rules |"
require_text "schedule editor product slice" "| Schedule editor |"
require_text "evidence export product slice" "| Evidence export |"
require_text "evidence diagnostics product slice" "| Evidence diagnostics |"
require_text "diagnostics report product slice" "| Diagnostics report |"
require_text "diagnostics report filter snapshot scope" "filter snapshot, App Guard snapshot"

require_text "update install row" "| Install newer build over current build |"
require_text "update stop row" "| Stop session before update |"
require_text "delete app uninstall row" "| Delete app after stopping sessions |"
require_text "reinstall row" "| Reinstall after deletion |"

require_text "beta package command" "FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh"
require_text "runtime matrix prepare command" "scripts/prepare-beta-runtime-matrix.sh"
require_text "release gate command" "scripts/check-beta-release-gate.sh"
require_text "metadata gate command" "scripts/check-toolary-metadata-gate.sh"
require_text "release evidence archive command" "scripts/archive-beta-release-evidence.sh"
require_text "release evidence archive gate command" "scripts/check-beta-release-evidence-archive.sh"
require_text "release evidence archive empty output directory" 'evidence directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before archiving'
require_text "release evidence archive unique basenames" "requires source basenames to be unique and not collide with reserved archive entries"
require_text "release evidence archive checksum single entry" "archive checker requires the archived checksum copy to contain exactly one ZIP entry"
require_text "release evidence archive rejects root symlink" "rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it"
require_text "final publication evidence gate command" "scripts/check-final-beta-publication-evidence.sh"
require_text "final publication evidence beta metadata requirement" 'Toolary metadata status `beta`'
require_text "publication packet export command" "scripts/export-final-beta-publication-packet.sh"
require_text "publication packet check command" "scripts/check-final-beta-publication-packet.sh"
require_text "publication packet checksum manifest" "publication-packet.sha256"
require_text "publication packet checksum manifest coverage" 'publication-packet.sha256` must list every packet file except itself'
require_text "publication packet empty output directory" 'export directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before export'
require_text "publication packet unique basenames" "source basenames must be unique and not collide with reserved packet entries"
require_text "publication packet rejects root symlink" "packet checker rejects a symlinked packet directory plus unexpected files, directories, symlinks, and special files inside it"
require_text "UTC timestamp release gate" 'Created/Date are UTC `YYYY-MM-DDTHH:MM:SSZ` timestamps'
require_text "clean git tree release gate" 'Git tree is `clean`'
require_text "matrix app path release gate" "matrix Channel, Date, Version, Build, Git commit, Git tree, App path, ZIP path, SHA-256, and Toolary publishable fields match"
require_text "all status cells passing requirement" 'every table status value is `Passed` or `passed`'
require_text "candidate output empty directory" "candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging"
require_text "candidate checksum single entry" "checksum file must contain exactly one ZIP entry"
require_text "runtime matrix output no overwrite" "runtime matrix output must not already exist"
require_text "runtime matrix output outside app bundle" "runtime matrix output must not already exist or physically resolve inside the app bundle"

printf 'Runtime matrix template gate passed\n'
