#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/path/to/output-dir]\n' "$0"
  printf '\n'
  printf 'Exports and validates the signed beta operator packet plus final signed\n'
  printf 'readiness wrapper wiring. Uses a temporary output directory when omitted.\n'
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
scripts_dir="$repo_root/scripts"
output_dir="${1:-$(mktemp -d /tmp/fermo-signed-operator-packet.XXXXXX)}"

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
  path="$1"
  label="$2"
  expected="$3"

  if ! grep -F -- "$expected" "$path" >/dev/null; then
    fail "$label missing required text: $expected"
  fi
}

require_same_file() {
  expected_path="$1"
  actual_path="$2"
  label="$3"

  if ! cmp -s "$expected_path" "$actual_path"; then
    fail "$label does not match repository source file"
  fi
}

"$scripts_dir/export-signed-beta-operator-packet.sh" "$output_dir" >/dev/null

packet_path="$output_dir/PACKET.md"
commands_path="$output_dir/SIGNED_RELEASE_COMMANDS.md"
runbook_path="$output_dir/toolary-beta-release-runbook.md"
matrix_template_path="$output_dir/toolary-beta-runtime-matrix.md"
release_notes_path="$output_dir/release-notes.md"
toolary_copy_path="$output_dir/toolary-beta-copy.md"
metadata_path="$output_dir/toolary-catalog-metadata.json"

require_file "$packet_path" "signed beta operator packet summary"
require_file "$commands_path" "signed release commands"
require_file "$runbook_path" "exported beta release runbook"
require_file "$matrix_template_path" "exported runtime matrix template"
require_file "$release_notes_path" "exported release notes"
require_file "$toolary_copy_path" "exported Toolary beta copy"
require_file "$metadata_path" "exported Toolary metadata"

require_same_file "$repo_root/docs/toolary-beta-release-runbook.md" "$runbook_path" "exported beta release runbook"
require_same_file "$repo_root/docs/toolary-beta-runtime-matrix.md" "$matrix_template_path" "exported runtime matrix template"
require_same_file "$repo_root/docs/release-notes.md" "$release_notes_path" "exported release notes"
require_same_file "$repo_root/docs/toolary-beta-copy.md" "$toolary_copy_path" "exported Toolary beta copy"
require_same_file "$repo_root/docs/toolary-catalog-metadata.json" "$metadata_path" "exported Toolary metadata"

for expected in \
  'scripts/check-local-release-readiness.sh' \
  'scripts/check-signed-build-environment.sh' \
  'FERMO_SIGNED_EXPORT_APP must be a real signed app bundle, not DerivedData/Build Products, a symlink, or physically inside /Applications/Fermo.app.' \
  'scripts/install-signed-beta-app.sh "$FERMO_SIGNED_EXPORT_APP"' \
  'FERMO_NOTARY_OUTPUT_DIR must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before notarization.' \
  'FERMO_NOTARYTOOL_PROFILE="$FERMO_NOTARYTOOL_PROFILE" scripts/notarize-signed-beta-app.sh /Applications/Fermo.app "$FERMO_NOTARY_OUTPUT_DIR"' \
  'scripts/check-notarytool-log.sh "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log' \
  'scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app' \
  'FERMO_RUNTIME_EVIDENCE_DIR must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before collection.' \
  'scripts/collect-signed-runtime-evidence.sh /Applications/Fermo.app "$FERMO_RUNTIME_EVIDENCE_DIR"' \
  'FERMO_RELEASE_OUTPUT_DIR must be empty, not a symlink, and not physically resolve inside the app bundle before packaging.' \
  'FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh /Applications/Fermo.app "$FERMO_RELEASE_OUTPUT_DIR"' \
  'FERMO_NOTARIZATION_REQUEST_ID="$(cat "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notary-request-id.txt)"' \
  'scripts/check-signed-beta-readiness.sh /Applications/Fermo.app' \
  'scripts/check-signed-runtime-evidence.sh "$FERMO_RUNTIME_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md' \
  'FERMO_EVIDENCE_DIR and FERMO_PUBLICATION_PACKET_DIR must be empty, not symlinks, and not physically resolve inside /Applications/Fermo.app.' \
  'scripts/archive-beta-release-evidence.sh /Applications/Fermo.app' \
  'scripts/archive-beta-release-evidence.sh /Applications/Fermo.app "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_EVIDENCE_DIR" "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"' \
  'scripts/check-beta-release-evidence-archive.sh "$FERMO_EVIDENCE_DIR"' \
  'scripts/check-beta-release-evidence-archive.sh "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"' \
  'scripts/check-final-beta-publication-evidence.sh "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"' \
  'scripts/export-final-beta-publication-packet.sh "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR" "$FERMO_PUBLICATION_PACKET_DIR"' \
  'scripts/check-final-beta-publication-packet.sh "$FERMO_PUBLICATION_PACKET_DIR" "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"'; do
  require_text "$commands_path" "signed release commands" "$expected"
done

for expected in \
  'Metadata status at export: `comingSoon`' \
  'Endpoint Security entitlement: `com.apple.developer.endpoint-security.client`' \
  'Signed export source must be a real app bundle, not DerivedData/Build Products, a symlink, or physically inside /Applications/Fermo.app.' \
  'Output directory was empty before export.' \
  'Output path was not a symlink.' \
  'Copied runbook, runtime matrix, release notes, Toolary copy, and metadata match repository source files at export time.' \
  'Final evidence archive records the notarization request ID plus `Notary log SHA-256`.' \
  'Notary output directory must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before notarization.' \
  'FERMO_NOTARYTOOL_PROFILE must be replaced with a real keychain profile name before notarization.' \
  'Candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging.' \
  'Candidate checksum file must contain exactly one ZIP entry for the generated ZIP basename.' \
  'Signed runtime evidence output directory must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before collection.' \
  'Signed runtime evidence checksum manifest must list every captured file except itself.' \
  'Release evidence and publication packet output directories must be empty, not symlinks, and not physically resolve inside /Applications/Fermo.app.' \
  'Publication evidence gate: `scripts/check-final-beta-publication-evidence.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notarytool.log> <signed-runtime-evidence-dir>`' \
  'Publication packet export: `scripts/export-final-beta-publication-packet.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notarytool.log> <signed-runtime-evidence-dir> <publication-packet-dir>`' \
  'Publication packet checksum manifest must list every packet file except itself.' \
  'scripts/check-beta-release-runbook.sh' \
  'scripts/check-runtime-matrix-template.sh' \
  'scripts/check-release-copy.sh' \
  'scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json' \
  'scripts/check-endpoint-security-request.sh' \
  'scripts/check-xcode-entitlements.sh'; do
  require_text "$packet_path" "signed beta operator packet summary" "$expected"
done

require_text \
  "$scripts_dir/check-signed-beta-readiness.sh" \
  "final signed readiness wrapper" \
  '"$scripts_dir/check-signed-runtime-approvals.sh" "$app_path"'

printf 'Signed beta operator packet gate passed\n'
printf 'Packet: %s\n' "$packet_path"
