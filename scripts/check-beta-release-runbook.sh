#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/path/to/toolary-beta-release-runbook.md]\n' "$0"
  printf '\n'
  printf 'Validates that the Toolary beta release runbook still documents the\n'
  printf 'external blockers, signed artifact flow, runtime evidence, and final gates.\n'
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
runbook_path="${1:-$repo_root/docs/toolary-beta-release-runbook.md}"

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

  if ! grep -F -- "$expected" "$runbook_path" >/dev/null; then
    fail "beta release runbook missing $label: $expected"
  fi
}

reject_text() {
  label="$1"
  rejected="$2"

  if grep -F -- "$rejected" "$runbook_path" >/dev/null; then
    fail "beta release runbook contains forbidden $label: $rejected"
  fi
}

require_file "$runbook_path" "beta release runbook"

for section in \
  "## Hard Blockers" \
  "## 1. Local Source Readiness" \
  "## 2. Apple Entitlement And Profiles" \
  "## 3. Signed Candidate Build" \
  "## 4. Runtime Matrix" \
  "## 5. Artifact Gates Before Metadata Flip" \
  "## 6. Metadata Flip And Final Gate" \
  "## Rollback Rule"; do
  require_text "$section section" "$section"
done

for expected in \
  'com.apple.developer.endpoint-security.client' \
  'com.toolary.fermo.appguard' \
  '/Applications/Fermo.app' \
  'Network Extension, Endpoint Security App Guard, and Login Item' \
  'Toolary metadata remains `comingSoon` until the artifact gates pass' \
  'scripts/check-local-release-readiness.sh' \
  'scripts/export-endpoint-security-request-packet.sh <output-dir>' \
  'Endpoint Security request packet output directory must be empty and not a symlink before export' \
  'copied request/checklist/entitlement files must match repository source files' \
  'scripts/check-endpoint-security-request-packet.sh' \
  'scripts/export-signed-beta-operator-packet.sh <output-dir>' \
  'signed beta operator packet output directory must be empty and not a symlink before export' \
  'copied runbook/matrix/release copy/metadata files must match repository source files' \
  'scripts/check-signed-beta-operator-packet.sh' \
  'scripts/check-beta-blocker-audit.sh' \
  'scripts/check-endpoint-security-request.sh' \
  'scripts/check-xcode-entitlements.sh' \
  'scripts/check-signed-build-environment.sh' \
  'real 10-character Apple team ID' \
  'placeholder or malformed team IDs are rejected before signing identity lookup' \
  'scripts/install-signed-beta-app.sh <signed-export>/Fermo.app' \
  'not DerivedData/Build Products, a symlink, or anything that physically resolves inside `/Applications/Fermo.app`' \
  'validates `FERMO_REPLACE_APPLICATIONS_APP` as `0` or `1`' \
  'existing `/Applications/Fermo.app` symlink as an explicit replacement case' \
  'FERMO_NOTARYTOOL_PROFILE=<profile> scripts/notarize-signed-beta-app.sh /Applications/Fermo.app <notary-output-dir>' \
  'the notary output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before notarization' \
  'FERMO_NOTARYTOOL_PROFILE` must be replaced with a real keychain profile name' \
  'angle-bracket placeholders are rejected before notarization starts' \
  'scripts/check-notarytool-log.sh <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log' \
  'UUID request ID in the notarytool `id` field' \
  'scripts/verify-beta-candidate.sh /Applications/Fermo.app' \
  'scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app' \
  'scripts/check-signed-helper-runtime.sh /Applications/Fermo.app' \
  'scripts/collect-signed-runtime-evidence.sh /Applications/Fermo.app <signed-runtime-evidence-dir>' \
  'scripts/check-signed-runtime-evidence.sh <signed-runtime-evidence-dir>' \
  'the output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` before collection' \
  'requires `signed-runtime-evidence.sha256` to list every captured file except itself' \
  'rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it' \
  'systemextensionsctl list' \
  'spctl --assess --type execute --verbose=4 /Applications/Fermo.app' \
  'FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh /Applications/Fermo.app' \
  'candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging' \
  'scripts/prepare-beta-runtime-matrix.sh' \
  'runtime matrix output must not already exist' \
  'runtime matrix output must not already exist or physically resolve inside the app bundle' \
  'contentFilterSnapshotState: ready' \
  'appGuardSnapshotState: ready' \
  'appGuardSnapshotProtectedApps' \
  'Safari, Chrome, and Firefox normal plus private/incognito checks pass' \
  'blocked app launch and relaunch are denied by App Guard' \
  'FermoHelper process is running' \
  'signed-runtime-evidence.md' \
  'Do not replace real runtime evidence with local unit tests or unsigned dogfood/dev output' \
  'scripts/check-beta-release-gate.sh <manifest> <completed-runtime-matrix>' \
  'scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json <manifest> <completed-runtime-matrix>' \
  'YYYY-MM-DDTHH:MM:SSZ' \
  'Git tree is `clean`' \
  'checksum file contains exactly one ZIP entry' \
  'scripts/check-signed-beta-readiness.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json' \
  'final signed readiness reruns signed runtime approvals' \
  'scripts/archive-beta-release-evidence.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <evidence-dir>' \
  'scripts/check-beta-release-evidence-archive.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json' \
  'the evidence directory must be empty and not a symlink before archiving' \
  'requires source basenames to be unique and not collide with reserved archive entries' \
  'archived checksum copy still contains exactly one ZIP entry for the generated ZIP basename' \
  'release evidence archive checker rejects a symlinked evidence directory plus unexpected files, directories, symlinks, and special files inside it' \
  'scripts/check-final-beta-publication-evidence.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>' \
  'scripts/export-final-beta-publication-packet.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir> <publication-packet-dir>' \
  'scripts/check-final-beta-publication-packet.sh <publication-packet-dir> <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>' \
  'signed runtime evidence' \
  'Toolary metadata status `beta`' \
  'publication-packet.sha256' \
  'publication-packet.sha256` must list every packet file except itself' \
  'requires source basenames to be unique and not collide with reserved packet entries' \
  'the output directory must be empty, not a symlink, and not physically resolve inside `/Applications/Fermo.app` so stale files cannot be uploaded accidentally' \
  'rejects a symlinked packet directory plus unexpected files, directories, symlinks, and special files inside it' \
  'Publish only from the passing publication packet.' \
  'release-evidence.md' \
  'notary-request-id.txt' \
  'leave metadata at `comingSoon`'; do
  require_text "required release runbook text" "$expected"
done

reject_text "overclaim" "cannot be bypassed"
reject_text "overclaim" "can't be bypassed"
reject_text "overclaim" "can’t be bypassed"
reject_text "overclaim" "bypass-proof"

printf 'Beta release runbook gate passed\n'
