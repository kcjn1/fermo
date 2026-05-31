#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /Applications/Fermo.app <output-dir>\n' "$0"
  printf '\n'
  printf 'Creates a notarization ZIP for the installed signed Fermo beta app,\n'
  printf 'submits it with notarytool, staples the accepted ticket, then reruns\n'
  printf 'signed candidate preflight.\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  FERMO_NOTARYTOOL_PROFILE  Required keychain profile name for notarytool.\n'
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
notary_profile="${FERMO_NOTARYTOOL_PROFILE:-}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_empty_output_dir() {
  path="$1"

  if [ -L "$path" ]; then
    fail "notary output path must not be a symlink: $path"
  fi

  if [ -e "$path" ] && [ ! -d "$path" ]; then
    fail "notary output path exists and is not a directory at $path"
  fi

  if [ -d "$path" ] && [ -n "$(find "$path" -mindepth 1 -print -quit)" ]; then
    fail "notary output directory must be empty: $path"
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
    fail "notary output directory must not be the app bundle: $path"
  fi

  case "$path" in
    "$app_dir"/*)
      fail "notary output directory must not be inside the app bundle: $path"
      ;;
  esac
}

require_real_notary_profile() {
  profile="$1"

  case "$profile" in
    *\<*|*\>*)
      fail "FERMO_NOTARYTOOL_PROFILE must be a real keychain profile name, not a placeholder"
      ;;
  esac
}

case "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" in
  0)
    ;;
  1)
    fail "notarization cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1"
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '${FERMO_SKIP_SIGNATURE_CHECKS:-0}'"
    ;;
esac

if [ "$app_path" != "/Applications/Fermo.app" ]; then
  fail "notarization must use /Applications/Fermo.app, got $app_path"
fi

if [ -z "$notary_profile" ]; then
  fail "FERMO_NOTARYTOOL_PROFILE is required for notarization"
fi

require_real_notary_profile "$notary_profile"

require_output_dir_outside_app "$app_path" "$output_dir"
require_empty_output_dir "$output_dir"

if [ ! -d "$app_path" ]; then
  fail "signed Fermo.app missing at $app_path"
fi

if ! command -v xcrun >/dev/null 2>&1; then
  fail "xcrun is required for notarytool and stapler"
fi

if ! command -v ditto >/dev/null 2>&1; then
  fail "ditto is required to create the notary submission ZIP"
fi

if [ ! -x /usr/libexec/PlistBuddy ]; then
  fail "PlistBuddy is required to read app version metadata"
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist" 2>/dev/null || true)"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist" 2>/dev/null || true)"

if [ -z "$version" ]; then
  fail "Fermo.app is missing CFBundleShortVersionString"
fi

if [ -z "$build" ]; then
  fail "Fermo.app is missing CFBundleVersion"
fi

case "$version" in
  *[!0-9.]*|"")
    fail "Fermo.app version must be numeric dot-separated, got '$version'"
    ;;
esac

case "$build" in
  *[!0-9.]*|"")
    fail "Fermo.app build must be numeric dot-separated, got '$build'"
    ;;
esac

mkdir -p "$output_dir"

zip_path="$output_dir/Fermo-$version-$build-notary-submit.zip"
notary_log_path="$output_dir/Fermo-$version-$build-notarytool.log"
notary_request_id_path="$output_dir/Fermo-$version-$build-notary-request-id.txt"

if [ -e "$zip_path" ]; then
  fail "notary submission ZIP already exists at $zip_path"
fi

if [ -e "$notary_log_path" ]; then
  fail "notarytool log already exists at $notary_log_path"
fi

if [ -e "$notary_request_id_path" ]; then
  fail "notary request ID file already exists at $notary_request_id_path"
fi

printf 'Fermo signed notarization\n'
printf 'App: %s\n' "$app_path"
printf 'Output: %s\n' "$output_dir"
printf 'Notary profile: %s\n' "$notary_profile"

"$scripts_dir/verify-beta-candidate.sh" "$app_path"
ditto -c -k --keepParent "$app_path" "$zip_path"

if ! xcrun notarytool submit "$zip_path" --keychain-profile "$notary_profile" --wait >"$notary_log_path" 2>&1; then
  cat "$notary_log_path" >&2
  fail "notarytool submit failed; see $notary_log_path"
fi

notary_request_id="$("$scripts_dir/check-notarytool-log.sh" --id-only "$notary_log_path")"
printf '%s\n' "$notary_request_id" > "$notary_request_id_path"

xcrun stapler staple "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"
"$scripts_dir/verify-beta-candidate.sh" "$app_path"

printf 'Notarized and stapled Fermo beta candidate\n'
printf 'ZIP: %s\n' "$zip_path"
printf 'Notary log: %s\n' "$notary_log_path"
printf 'Notarization request ID: %s\n' "$notary_request_id"
printf 'Notary request ID file: %s\n' "$notary_request_id_path"
