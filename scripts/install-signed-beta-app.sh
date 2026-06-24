#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/signed/Fermo.app\n' "$0"
  printf '\n'
  printf 'Installs a signed and notarized Fermo candidate artifact exactly at\n'
  printf '/Applications/Fermo.app, then reruns signed candidate preflight there.\n'
  printf 'Refuses DerivedData/Build Products paths, symlinked source apps,\n'
  printf 'sources inside /Applications/Fermo.app, and skipped signature checks.\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  FERMO_REPLACE_APPLICATIONS_APP=1  Required when /Applications/Fermo.app already exists.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

source_app_path="$1"
install_path="/Applications/Fermo.app"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_source_outside_install_path() {
  source_path="${1%/}"
  target_path="${2%/}"

  if [ "$source_path" = "$target_path" ]; then
    fail "source app is already /Applications/Fermo.app"
  fi

  case "$source_path" in
    "$target_path"/*)
      fail "signed Fermo.app source must not be inside /Applications/Fermo.app: $source_path"
      ;;
  esac
}

physical_path() {
  path="${1%/}"
  dir="$(dirname -- "$path")"
  base="$(basename -- "$path")"

  dir="$(CDPATH= cd -P -- "$dir" && pwd -P)"
  printf '%s/%s\n' "$dir" "$base"
}

case "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" in
  0)
    ;;
  1)
    fail "signed beta install cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1"
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '${FERMO_SKIP_SIGNATURE_CHECKS:-0}'"
    ;;
esac

case "${FERMO_REPLACE_APPLICATIONS_APP:-0}" in
  0|1)
    ;;
  *)
    fail "FERMO_REPLACE_APPLICATIONS_APP must be 0 or 1, got '${FERMO_REPLACE_APPLICATIONS_APP:-0}'"
    ;;
esac

require_source_outside_install_path "$source_app_path" "$install_path"

if [ ! -d "$source_app_path" ]; then
  fail "signed Fermo.app source missing at $source_app_path"
fi

if [ -L "$source_app_path" ]; then
  fail "signed Fermo.app source must not be a symlink: $source_app_path"
fi

source_physical_path="$(physical_path "$source_app_path")"
install_physical_path="$(physical_path "$install_path")"
require_source_outside_install_path "$source_physical_path" "$install_physical_path"

case "$source_app_path" in
  *DerivedData*|*"/Build/Products/"*)
    fail "signed beta install refuses DerivedData or Build Products source paths: $source_app_path"
    ;;
esac

"$scripts_dir/verify-beta-candidate.sh" "$source_app_path"

if [ \( -e "$install_path" \) -o \( -L "$install_path" \) ] && [ "${FERMO_REPLACE_APPLICATIONS_APP:-0}" != "1" ]; then
  fail "$install_path already exists; set FERMO_REPLACE_APPLICATIONS_APP=1 to replace it"
fi

if [ \( -e "$install_path" \) -o \( -L "$install_path" \) ] && [ ! -d "$install_path" ] && [ ! -L "$install_path" ]; then
  fail "$install_path exists but is not an app directory or symlink"
fi

if [ \( -e "$install_path" \) -o \( -L "$install_path" \) ]; then
  rm -rf "$install_path"
fi

ditto "$source_app_path" "$install_path"
"$scripts_dir/verify-beta-candidate.sh" "$install_path"

printf 'Installed signed Fermo beta candidate\n'
printf 'Source: %s\n' "$source_app_path"
printf 'Installed: %s\n' "$install_path"
