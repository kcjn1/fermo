#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/evidence-dir /path/to/beta-manifest.md /path/to/completed-runtime-matrix.md /path/to/toolary-catalog-metadata.json /path/to/notarytool.log /path/to/signed-runtime-evidence-dir\n' "$0"
  printf '\n'
  printf 'Validates the final public beta evidence bundle. Unlike the lower-level\n'
  printf 'archive checker, this gate requires the notarytool log, signed runtime\n'
  printf 'evidence directory, and Toolary metadata status beta.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 6 ]; then
  usage >&2
  exit 64
fi

evidence_dir="$1"
manifest_path="$2"
matrix_path="$3"
metadata_path="$4"
notary_log_path="$5"
runtime_evidence_dir="$6"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"

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

json_value() {
  key_path="$1"

  /usr/bin/ruby -rjson -e '
    key_path = ARGV.fetch(0)
    metadata_path = ARGV.fetch(1)
    data = JSON.parse(File.read(metadata_path))
    value = key_path.split(".").reduce(data) do |current, key|
      current.is_a?(Hash) ? current[key] : nil
    end
    puts value unless value.nil?
  ' "$key_path" "$metadata_path" 2>/dev/null || true
}

require_file "$notary_log_path" "notarytool log"

if [ ! -d "$runtime_evidence_dir" ]; then
  fail "signed runtime evidence directory missing at $runtime_evidence_dir"
fi

"$scripts_dir/check-beta-release-evidence-archive.sh" \
  "$evidence_dir" \
  "$manifest_path" \
  "$matrix_path" \
  "$metadata_path" \
  "$notary_log_path" \
  "$runtime_evidence_dir" >/dev/null

"$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_path" "$manifest_path" "$matrix_path" >/dev/null

metadata_status="$(json_value status)"
if [ "$metadata_status" != "beta" ]; then
  fail "final publication evidence requires Toolary metadata status beta, got '$metadata_status'"
fi

evidence_path="$evidence_dir/release-evidence.md"
require_file "$evidence_path" "release evidence summary"
require_text "$evidence_path" "release evidence summary" "- Notarization request ID:"
require_text "$evidence_path" "release evidence summary" "- Notary log:"
require_text "$evidence_path" "release evidence summary" "- Notary log SHA-256:"
require_text "$evidence_path" "release evidence summary" "- Signed runtime evidence: signed-runtime-evidence"
require_text "$evidence_path" "release evidence summary" "- Signed runtime evidence checksum file: signed-runtime-evidence/signed-runtime-evidence.sha256"
require_text "$evidence_path" "release evidence summary" "- Signed runtime evidence checksum SHA-256:"
require_text "$evidence_path" "release evidence summary" "scripts/check-signed-beta-readiness.sh /Applications/Fermo.app"

printf 'Final beta publication evidence gate passed\n'
printf 'Evidence: %s\n' "$evidence_dir"
printf 'Manifest: %s\n' "$manifest_path"
printf 'Matrix: %s\n' "$matrix_path"
printf 'Metadata: %s\n' "$metadata_path"
