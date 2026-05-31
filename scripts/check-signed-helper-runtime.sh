#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/Applications/Fermo.app]\n' "$0"
  printf '\n'
  printf 'Checks the signed Fermo Login Item helper runtime before the manual beta\n'
  printf 'matrix: installed app path, signed candidate preflight, launchctl service,\n'
  printf 'and a running FermoHelper process.\n'
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
helper_bundle_id="com.toolary.fermo.helper"
helper_app_path="$app_path/Contents/Library/LoginItems/FermoHelper.app"

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

case "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" in
  0)
    ;;
  1)
    fail "signed helper runtime check cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1"
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '${FERMO_SKIP_SIGNATURE_CHECKS:-0}'"
    ;;
esac

if [ "$app_path" != "/Applications/Fermo.app" ]; then
  fail "signed helper runtime check must use /Applications/Fermo.app, got '$app_path'"
fi

require_command launchctl
require_command pgrep
require_command id

if [ ! -d "$helper_app_path" ]; then
  fail "FermoHelper login item missing at $helper_app_path"
fi

tmp_dir="$(mktemp -d /tmp/fermo-helper-runtime.XXXXXX)"
launchctl_output="$tmp_dir/launchctl-helper.txt"
pgrep_output="$tmp_dir/pgrep-helper.txt"
uid="$(id -u)"

printf 'Fermo signed helper runtime\n'
printf 'App: %s\n' "$app_path"
printf 'Helper: %s\n' "$helper_app_path"

"$scripts_dir/verify-beta-candidate.sh" "$app_path" >/dev/null

if ! launchctl print "gui/$uid/$helper_bundle_id" > "$launchctl_output" 2>&1; then
  cat "$launchctl_output" >&2
  fail "launchctl cannot find running Login Item service $helper_bundle_id; register and allow FermoHelper in Login Items"
fi

if ! pgrep -x FermoHelper > "$pgrep_output" 2>&1; then
  fail "FermoHelper process is not running; register and allow the Login Item before the beta runtime matrix"
fi

printf 'FermoHelper launchctl service: gui/%s/%s\n' "$uid" "$helper_bundle_id"
printf 'FermoHelper pids: %s\n' "$(paste -sd ',' "$pgrep_output")"
printf 'Signed helper runtime checks passed\n'
