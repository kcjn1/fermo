#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/Fermo.app /path/to/candidate-manifest.md\n' "$0"
  printf '\n'
  printf 'Verifies that the candidate manifest describes the same app bundle path,\n'
  printf 'version, and build as the supplied Fermo.app.\n'
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
manifest_path="$2"
plist_path="$app_path/Contents/Info.plist"

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

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
}

plist_value() {
  key="$1"

  if [ ! -x /usr/libexec/PlistBuddy ]; then
    fail "PlistBuddy is required to read app Info.plist"
  fi

  /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

require_file "$manifest_path" "candidate manifest"
require_file "$plist_path" "app Info.plist"

manifest_app_path="$(manifest_value "App path")"
manifest_version="$(manifest_value Version)"
manifest_build="$(manifest_value Build)"
app_version="$(plist_value CFBundleShortVersionString)"
app_build="$(plist_value CFBundleVersion)"

if [ -z "$manifest_app_path" ]; then
  fail "manifest does not include App path"
fi

if [ "$manifest_app_path" != "$app_path" ]; then
  fail "manifest App path must match app path '$app_path', got '$manifest_app_path'"
fi

if [ -z "$manifest_version" ]; then
  fail "manifest does not include Version"
fi

if [ -z "$app_version" ]; then
  fail "app Info.plist does not include CFBundleShortVersionString"
fi

if [ "$manifest_version" != "$app_version" ]; then
  fail "manifest Version must match app CFBundleShortVersionString '$app_version', got '$manifest_version'"
fi

if [ -z "$manifest_build" ]; then
  fail "manifest does not include Build"
fi

if [ -z "$app_build" ]; then
  fail "app Info.plist does not include CFBundleVersion"
fi

if [ "$manifest_build" != "$app_build" ]; then
  fail "manifest Build must match app CFBundleVersion '$app_build', got '$manifest_build'"
fi

printf 'Candidate manifest app check passed\n'
printf 'App: %s\n' "$app_path"
printf 'Manifest: %s\n' "$manifest_path"
printf 'Version: %s\n' "$app_version"
printf 'Build: %s\n' "$app_build"
