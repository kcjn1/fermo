#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /Applications/Fermo.app /path/to/beta-manifest.md /path/to/completed-runtime-matrix.md /path/to/toolary-catalog-metadata.json\n' "$0"
  printf '\n'
  printf 'Runs the final signed beta readiness gate: signed/notarized app preflight,\n'
  printf 'signed runtime approvals, beta release artifact gate, and Toolary beta\n'
  printf 'metadata gate.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 4 ]; then
  usage >&2
  exit 64
fi

app_path="$1"
manifest_path="$2"
matrix_path="$3"
metadata_path="$4"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

case "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" in
  0|1)
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '${FERMO_SKIP_SIGNATURE_CHECKS:-0}'"
    ;;
esac

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

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
}

if [ "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" = "1" ]; then
  fail "signed beta readiness cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1"
fi

if [ "$app_path" != "/Applications/Fermo.app" ]; then
  fail "signed beta readiness must use /Applications/Fermo.app, got '$app_path'"
fi

manifest_app_path="$(manifest_value "App path")"
if [ "$manifest_app_path" != "$app_path" ]; then
  fail "manifest App path must match signed app path '$app_path', got '$manifest_app_path'"
fi

if [ ! -x /usr/bin/ruby ]; then
  fail "ruby is required to validate Toolary metadata status"
fi

metadata_status="$(json_value status)"
if [ "$metadata_status" != "beta" ]; then
  fail "Toolary metadata status must be beta for signed readiness, got '$metadata_status'"
fi

FERMO_TOOLARY_METADATA_PATH="$metadata_path" "$scripts_dir/check-release-copy.sh" >/dev/null
"$scripts_dir/check-candidate-manifest-app.sh" "$app_path" "$manifest_path" >/dev/null
"$scripts_dir/check-signed-runtime-approvals.sh" "$app_path"

printf 'Fermo signed beta readiness\n'
printf 'App: %s\n' "$app_path"
printf 'Manifest: %s\n' "$manifest_path"
printf 'Matrix: %s\n' "$matrix_path"
printf 'Metadata: %s\n' "$metadata_path"

"$scripts_dir/verify-beta-candidate.sh" "$app_path"
"$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"
"$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_path" "$manifest_path" "$matrix_path"

printf 'Signed beta readiness passed\n'
