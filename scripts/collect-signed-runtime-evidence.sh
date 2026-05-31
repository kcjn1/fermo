#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /Applications/Fermo.app /path/to/output-dir\n' "$0"
  printf '\n'
  printf 'Collects signed runtime evidence before the manual Toolary beta matrix:\n'
  printf 'candidate preflight, notarization assessment, system extension approvals,\n'
  printf 'Login Item helper state, and basic Mac/runtime metadata.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 2 ]; then
  usage >&2
  exit 64
fi

app_path="$1"
output_dir="$2"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"
helper_bundle_id="com.toolary.fermo.helper"

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

run_capture() {
  label="$1"
  output_path="$2"
  shift 2

  printf 'Collecting %s\n' "$label"
  if ! "$@" >"$output_path" 2>&1; then
    cat "$output_path" >&2
    fail "$label failed; captured output at $output_path"
  fi
}

physical_containment_path() {
  path="$1"
  suffix=""

  while [ "$path" != "/" ] && [ "${path%/}" != "$path" ]; do
    path="${path%/}"
  done

  if [ -z "$path" ]; then
    printf '\n'
    return
  fi

  while [ ! -d "$path" ]; do
    base="$(basename -- "$path")"
    parent="$(dirname -- "$path")"

    if [ "$parent" = "$path" ]; then
      printf '%s\n' "$1"
      return
    fi

    if [ -z "$suffix" ]; then
      suffix="$base"
    else
      suffix="$base/$suffix"
    fi

    path="$parent"
  done

  path="$(CDPATH= cd -P -- "$path" && pwd -P)"
  if [ -n "$suffix" ]; then
    printf '%s/%s\n' "$path" "$suffix"
  else
    printf '%s\n' "$path"
  fi
}

require_output_dir_outside_app() {
  raw_app_dir="${1%/}"

  if [ -z "$raw_app_dir" ]; then
    return
  fi

  app_dir="$(physical_containment_path "$raw_app_dir")"
  path="$(physical_containment_path "$2")"

  if [ "$path" = "$app_dir" ]; then
    fail "signed runtime evidence output directory must not be the app bundle: $path"
  fi

  case "$path" in
    "$app_dir"/*)
      fail "signed runtime evidence output directory must not be inside the app bundle: $path"
      ;;
  esac
}

if [ "$app_path" != "/Applications/Fermo.app" ]; then
  fail "signed runtime evidence collection must use /Applications/Fermo.app, got '$app_path'"
fi

case "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" in
  0)
    ;;
  1)
    fail "signed runtime evidence collection cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1"
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '${FERMO_SKIP_SIGNATURE_CHECKS:-0}'"
    ;;
esac

require_output_dir_outside_app "$app_path" "$output_dir"

if [ -L "$output_dir" ]; then
  fail "signed runtime evidence output path must not be a symlink: $output_dir"
fi

if [ -e "$output_dir" ] && [ ! -d "$output_dir" ]; then
  fail "signed runtime evidence output path exists and is not a directory at $output_dir"
fi

mkdir -p "$output_dir"
if find "$output_dir" -mindepth 1 -print -quit | grep . >/dev/null; then
  fail "signed runtime evidence output directory must be empty: $output_dir"
fi

if [ ! -d "$app_path" ]; then
  fail "signed Fermo app missing at $app_path"
fi

require_command date
require_command hostname
require_command id
require_command launchctl
require_command pgrep
require_command plutil
require_command spctl
require_command systemextensionsctl
require_command uname

created="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
summary_path="$output_dir/signed-runtime-evidence.md"
system_path="$output_dir/system.txt"
info_plist_path="$output_dir/Fermo-Info.plist.txt"
preflight_path="$output_dir/verify-beta-candidate.txt"
spctl_path="$output_dir/spctl-assess.txt"
systemextensions_path="$output_dir/systemextensionsctl-list.txt"
runtime_approvals_path="$output_dir/check-signed-runtime-approvals.txt"
helper_runtime_path="$output_dir/check-signed-helper-runtime.txt"
launchctl_path="$output_dir/launchctl-helper.txt"
pgrep_path="$output_dir/pgrep-helper.txt"
checksum_manifest_path="$output_dir/signed-runtime-evidence.sha256"
uid="$(id -u)"

{
  printf 'created=%s\n' "$created"
  printf 'hostname=%s\n' "$(hostname)"
  printf 'uid=%s\n' "$uid"
  printf 'uname=%s\n' "$(uname -a)"
  if command -v sw_vers >/dev/null 2>&1; then
    sw_vers
  else
    printf 'sw_vers=unavailable\n'
  fi
} > "$system_path"

run_capture "Fermo Info.plist" "$info_plist_path" plutil -p "$app_path/Contents/Info.plist"
run_capture "signed candidate preflight" "$preflight_path" "$scripts_dir/verify-beta-candidate.sh" "$app_path"
run_capture "spctl assessment" "$spctl_path" spctl --assess --type execute --verbose=4 "$app_path"
run_capture "system extension list" "$systemextensions_path" systemextensionsctl list
run_capture "signed runtime approvals" "$runtime_approvals_path" "$scripts_dir/check-signed-runtime-approvals.sh" "$app_path"
run_capture "signed helper runtime" "$helper_runtime_path" "$scripts_dir/check-signed-helper-runtime.sh" "$app_path"
run_capture "launchctl helper service" "$launchctl_path" launchctl print "gui/$uid/$helper_bundle_id"
run_capture "FermoHelper process list" "$pgrep_path" pgrep -x FermoHelper

{
  printf '# Fermo Signed Runtime Evidence\n\n'
  printf -- '- Created: %s\n' "$created"
  printf -- '- App path: %s\n' "$app_path"
  printf -- '- Hostname: %s\n' "$(hostname)"
  printf -- '- User ID: %s\n' "$uid"
  printf -- '- Helper service: `gui/%s/%s`\n' "$uid" "$helper_bundle_id"
  printf -- '- FermoHelper pids: %s\n' "$(paste -sd ',' "$pgrep_path")"
  printf '\n'
  printf '## Captured Files\n\n'
  printf -- '- `system.txt`: host, UID, uname, and macOS version.\n'
  printf -- '- `Fermo-Info.plist.txt`: installed app bundle metadata.\n'
  printf -- '- `verify-beta-candidate.txt`: signed candidate preflight output.\n'
  printf -- '- `spctl-assess.txt`: notarization/Gatekeeper assessment output.\n'
  printf -- '- `systemextensionsctl-list.txt`: raw system extension list.\n'
  printf -- '- `check-signed-runtime-approvals.txt`: Network Extension, App Guard, and helper approval gate output.\n'
  printf -- '- `check-signed-helper-runtime.txt`: Login Item helper gate output.\n'
  printf -- '- `launchctl-helper.txt`: raw Login Item launchctl service state.\n'
  printf -- '- `pgrep-helper.txt`: running FermoHelper process IDs.\n'
  printf -- '- `signed-runtime-evidence.sha256`: SHA-256 manifest for the captured evidence files.\n'
  printf '\n'
  printf '## System Extensions\n\n'
  grep -F 'com.toolary.fermo.' "$systemextensions_path" || true
  printf '\n'
  printf '## Verification\n\n'
  printf 'This evidence directory was written only after the signed preflight, spctl assessment, signed runtime approvals, helper runtime, launchctl service, and FermoHelper process checks exited 0.\n'
} > "$summary_path"

(
  cd "$output_dir"
  shasum -a 256 \
    signed-runtime-evidence.md \
    system.txt \
    Fermo-Info.plist.txt \
    verify-beta-candidate.txt \
    spctl-assess.txt \
    systemextensionsctl-list.txt \
    check-signed-runtime-approvals.txt \
    check-signed-helper-runtime.txt \
    launchctl-helper.txt \
    pgrep-helper.txt
) > "$checksum_manifest_path"

"$scripts_dir/check-signed-runtime-evidence.sh" "$output_dir" >/dev/null

printf 'Collected Fermo signed runtime evidence\n'
printf 'Evidence: %s\n' "$summary_path"
printf 'Output: %s\n' "$output_dir"
