#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/Applications/Fermo.app]\n' "$0"
  printf '\n'
  printf 'Checks signed runtime approval prerequisites before the manual Toolary beta\n'
  printf 'matrix: signed candidate preflight, notarization assessment, and activated\n'
  printf 'Network Extension plus Endpoint Security App Guard system extensions, and\n'
  printf 'the running Login Item helper.\n'
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
app_path="${1:-/Applications/Fermo.app}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "$command_name is required"
  fi
}

require_activated_enabled_extension() {
  output_path="$1"
  bundle_id="$2"
  label="$3"

  line="$(grep -F "$bundle_id" "$output_path" | tail -n 1 || true)"
  if [ -z "$line" ]; then
    fail "$label is missing from systemextensionsctl list: $bundle_id"
  fi

  if ! printf '%s\n' "$line" | grep -F "activated enabled" >/dev/null; then
    fail "$label is not activated enabled: $line"
  fi
}

if [ "$app_path" != "/Applications/Fermo.app" ]; then
  fail "signed runtime approval check must use /Applications/Fermo.app, got '$app_path'"
fi

case "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" in
  0)
    ;;
  1)
    fail "signed runtime approval check cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1"
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '${FERMO_SKIP_SIGNATURE_CHECKS:-0}'"
    ;;
esac

require_command systemextensionsctl
require_command spctl

tmp_dir="$(mktemp -d /tmp/fermo-runtime-approvals.XXXXXX)"
systemextensions_output="$tmp_dir/systemextensionsctl-list.txt"

printf 'Fermo signed runtime approvals\n'
printf 'App: %s\n' "$app_path"

"$scripts_dir/verify-beta-candidate.sh" "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"
systemextensionsctl list > "$systemextensions_output"

require_activated_enabled_extension "$systemextensions_output" "com.toolary.fermo.filter" "Network Extension"
require_activated_enabled_extension "$systemextensions_output" "com.toolary.fermo.appguard" "Endpoint Security App Guard"
"$scripts_dir/check-signed-helper-runtime.sh" "$app_path"

printf 'System extensions:\n'
grep -F "com.toolary.fermo." "$systemextensions_output" || true
printf 'Signed runtime approval checks passed\n'
