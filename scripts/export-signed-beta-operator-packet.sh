#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/output-dir\n' "$0"
  printf '\n'
  printf 'Exports a self-contained signed beta operator packet: release runbook,\n'
  printf 'runtime matrix template, release copy, metadata draft, and generated\n'
  printf 'SIGNED_RELEASE_COMMANDS.md with the exact signed-release command order.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

output_dir="$1"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"
runbook_path="$repo_root/docs/toolary-beta-release-runbook.md"
matrix_template_path="$repo_root/docs/toolary-beta-runtime-matrix.md"
release_notes_path="$repo_root/docs/release-notes.md"
toolary_copy_path="$repo_root/docs/toolary-beta-copy.md"
metadata_path="$repo_root/docs/toolary-catalog-metadata.json"

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

require_empty_output_dir() {
  path="$1"

  if [ -L "$path" ]; then
    fail "signed beta operator packet output path must not be a symlink: $path"
  fi

  if [ -e "$path" ] && [ ! -d "$path" ]; then
    fail "signed beta operator packet output path exists and is not a directory at $path"
  fi

  if [ -d "$path" ] && [ -n "$(find "$path" -mindepth 1 -print -quit)" ]; then
    fail "signed beta operator packet output directory must be empty: $path"
  fi
}

require_file "$runbook_path" "beta release runbook"
require_file "$matrix_template_path" "runtime matrix template"
require_file "$release_notes_path" "release notes"
require_file "$toolary_copy_path" "Toolary beta copy"
require_file "$metadata_path" "Toolary metadata"
require_empty_output_dir "$output_dir"

"$scripts_dir/check-beta-release-runbook.sh" "$runbook_path" >/dev/null
"$scripts_dir/check-runtime-matrix-template.sh" "$matrix_template_path" >/dev/null
"$scripts_dir/check-release-copy.sh" >/dev/null
"$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_path" >/dev/null
"$scripts_dir/check-endpoint-security-request.sh" >/dev/null
"$scripts_dir/check-xcode-entitlements.sh" >/dev/null

mkdir -p "$output_dir"

cp "$runbook_path" "$output_dir/toolary-beta-release-runbook.md"
cp "$matrix_template_path" "$output_dir/toolary-beta-runtime-matrix.md"
cp "$release_notes_path" "$output_dir/release-notes.md"
cp "$toolary_copy_path" "$output_dir/toolary-beta-copy.md"
cp "$metadata_path" "$output_dir/toolary-catalog-metadata.json"

created="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
commands_path="$output_dir/SIGNED_RELEASE_COMMANDS.md"
packet_path="$output_dir/PACKET.md"

{
  printf '# Fermo Signed Beta Operator Commands\n\n'
  printf 'Run these from the repository root after Apple has granted Endpoint Security and profiles have been regenerated.\n\n'
  printf '```sh\n'
  printf 'export FERMO_SIGNED_EXPORT_APP="<signed-export>/Fermo.app"\n'
  printf 'export FERMO_RELEASE_OUTPUT_DIR="<release-output-dir>"\n'
  printf 'export FERMO_NOTARY_OUTPUT_DIR="<notary-output-dir>"\n'
  printf 'export FERMO_RUNTIME_EVIDENCE_DIR="<signed-runtime-evidence-dir>"\n'
  printf 'export FERMO_EVIDENCE_DIR="<evidence-dir>"\n'
  printf 'export FERMO_PUBLICATION_PACKET_DIR="<publication-packet-dir>"\n'
  printf 'export FERMO_NOTARYTOOL_PROFILE="<notarytool-keychain-profile>"\n'
  printf 'export FERMO_REPLACE_APPLICATIONS_APP=1\n'
  printf '\n'
  printf '# FERMO_SIGNED_EXPORT_APP must be a real signed app bundle, not DerivedData/Build Products, a symlink, or physically inside /Applications/Fermo.app.\n'
  printf 'scripts/check-local-release-readiness.sh\n'
  printf 'scripts/check-signed-build-environment.sh\n'
  printf 'scripts/install-signed-beta-app.sh "$FERMO_SIGNED_EXPORT_APP"\n'
  printf '# FERMO_NOTARY_OUTPUT_DIR must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before notarization.\n'
  printf 'FERMO_NOTARYTOOL_PROFILE="$FERMO_NOTARYTOOL_PROFILE" scripts/notarize-signed-beta-app.sh /Applications/Fermo.app "$FERMO_NOTARY_OUTPUT_DIR"\n'
  printf 'scripts/check-notarytool-log.sh "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log\n'
  printf 'scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app\n'
  printf '# FERMO_RUNTIME_EVIDENCE_DIR must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before collection.\n'
  printf 'scripts/collect-signed-runtime-evidence.sh /Applications/Fermo.app "$FERMO_RUNTIME_EVIDENCE_DIR"\n'
  printf '\n'
  printf '# FERMO_RELEASE_OUTPUT_DIR must be empty, not a symlink, and not physically resolve inside the app bundle before packaging.\n'
  printf 'FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh /Applications/Fermo.app "$FERMO_RELEASE_OUTPUT_DIR"\n'
  printf 'FERMO_NOTARIZATION_REQUEST_ID="$(cat "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notary-request-id.txt)" scripts/prepare-beta-runtime-matrix.sh "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md docs/toolary-beta-runtime-matrix.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md\n'
  printf '\n'
  printf '# Manually complete every runtime matrix row, then flip docs/toolary-catalog-metadata.json from comingSoon to beta.\n'
  printf 'scripts/check-signed-beta-readiness.sh /Applications/Fermo.app "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json\n'
  printf 'scripts/check-signed-runtime-evidence.sh "$FERMO_RUNTIME_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md\n'
  printf '# FERMO_EVIDENCE_DIR and FERMO_PUBLICATION_PACKET_DIR must be empty, not symlinks, and not physically resolve inside /Applications/Fermo.app.\n'
  printf 'scripts/archive-beta-release-evidence.sh /Applications/Fermo.app "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_EVIDENCE_DIR" "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"\n'
  printf 'scripts/check-beta-release-evidence-archive.sh "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"\n'
  printf 'scripts/check-final-beta-publication-evidence.sh "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"\n'
  printf 'scripts/export-final-beta-publication-packet.sh "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR" "$FERMO_PUBLICATION_PACKET_DIR"\n'
  printf 'scripts/check-final-beta-publication-packet.sh "$FERMO_PUBLICATION_PACKET_DIR" "$FERMO_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-runtime-matrix.md docs/toolary-catalog-metadata.json "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notarytool.log "$FERMO_RUNTIME_EVIDENCE_DIR"\n'
  printf '```\n\n'
  printf 'Replace `<Version>` and `<Build>` with the values printed by the signed candidate scripts.\n'
} > "$commands_path"

{
  printf '# Fermo Signed Beta Operator Packet\n\n'
  printf -- '- Created: %s\n' "$created"
  printf -- '- App path required by beta gates: `/Applications/Fermo.app`\n'
  printf -- '- Metadata status at export: `comingSoon`\n'
  printf -- '- Endpoint Security entitlement: `com.apple.developer.endpoint-security.client`\n'
  printf -- '- Signed export source must be a real app bundle, not DerivedData/Build Products, a symlink, or physically inside /Applications/Fermo.app.\n'
  printf -- '- Output directory was empty before export.\n'
  printf -- '- Output path was not a symlink.\n'
  printf -- '- Copied runbook, runtime matrix, release notes, Toolary copy, and metadata match repository source files at export time.\n'
  printf -- '- Notary output directory must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before notarization.\n'
  printf -- '- FERMO_NOTARYTOOL_PROFILE must be replaced with a real keychain profile name before notarization.\n'
  printf -- '- Candidate output directory must be empty, not a symlink, and not physically resolve inside the app bundle before packaging.\n'
  printf -- '- Candidate checksum file must contain exactly one ZIP entry for the generated ZIP basename.\n'
  printf -- '- Final gate: `scripts/check-signed-beta-readiness.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json`\n'
  printf -- '- Signed runtime evidence output directory must be empty, not a symlink, and not physically resolve inside /Applications/Fermo.app before collection.\n'
  printf -- '- Signed runtime evidence checksum manifest must list every captured file except itself.\n'
  printf -- '- Release evidence and publication packet output directories must be empty, not symlinks, and not physically resolve inside /Applications/Fermo.app.\n'
  printf -- '- Final evidence archive records the notarization request ID plus `Notary log SHA-256`.\n'
  printf -- '- Publication evidence gate: `scripts/check-final-beta-publication-evidence.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notarytool.log> <signed-runtime-evidence-dir>`\n\n'
  printf -- '- Publication packet export: `scripts/export-final-beta-publication-packet.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notarytool.log> <signed-runtime-evidence-dir> <publication-packet-dir>`\n\n'
  printf -- '- Publication packet checksum manifest must list every packet file except itself.\n\n'
  printf '## Files\n\n'
  printf -- '- `SIGNED_RELEASE_COMMANDS.md`: command sequence for the signing Mac.\n'
  printf -- '- `toolary-beta-release-runbook.md`: operator runbook.\n'
  printf -- '- `toolary-beta-runtime-matrix.md`: runtime matrix template.\n'
  printf -- '- `release-notes.md`: localized release notes draft.\n'
  printf -- '- `toolary-beta-copy.md`: localized Toolary listing copy draft.\n'
  printf -- '- `toolary-catalog-metadata.json`: metadata draft that must stay `comingSoon` until artifact gates pass.\n\n'
  printf '## Export Validation\n\n'
  printf 'This packet was exported only after these gates passed:\n\n'
  printf '```sh\n'
  printf 'scripts/check-beta-release-runbook.sh\n'
  printf 'scripts/check-runtime-matrix-template.sh\n'
  printf 'scripts/check-release-copy.sh\n'
  printf 'scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json\n'
  printf 'scripts/check-endpoint-security-request.sh\n'
  printf 'scripts/check-xcode-entitlements.sh\n'
  printf '```\n'
} > "$packet_path"

printf 'Exported signed beta operator packet\n'
printf 'Packet: %s\n' "$packet_path"
printf 'Commands: %s\n' "$commands_path"
printf 'Output: %s\n' "$output_dir"
