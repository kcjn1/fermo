#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [--team-id TEAM_ID]\n' "$0"
  printf '\n'
  printf 'Checks local prerequisites for creating the signed/notarized Fermo beta\n'
  printf 'candidate: Developer ID signing identity, notarytool availability, and\n'
  printf 'source Xcode signing/app-group settings. This does not replace Apple\n'
  printf 'Endpoint Security entitlement approval or the signed runtime matrix.\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  FERMO_NOTARYTOOL_PROFILE  Optional notarytool keychain profile name to report.\n'
}

team_id="MP3AWS77U3"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --team-id)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        usage >&2
        exit 64
      fi
      team_id="$2"
      shift 2
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
done

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
project_path="$repo_root/Fermo.xcodeproj/project.pbxproj"

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

require_project_text() {
  expected="$1"

  if ! grep -F -- "$expected" "$project_path" >/dev/null; then
    fail "Xcode project missing required signing text: $expected"
  fi
}

require_real_notary_profile() {
  profile="$1"

  case "$profile" in
    *\<*|*\>*)
      fail "FERMO_NOTARYTOOL_PROFILE must be a real keychain profile name, not a placeholder"
      ;;
  esac
}

require_valid_team_id() {
  value="$1"

  case "$value" in
    *\<*|*\>*)
      fail "Team ID must be a real 10-character Apple team ID, not a placeholder"
      ;;
  esac

  if ! printf '%s\n' "$value" | grep -Eq '^[A-Z0-9]{10}$'; then
    fail "Team ID must be a 10-character Apple team ID, got '$value'"
  fi
}

require_file "$project_path" "Xcode project"
require_valid_team_id "$team_id"

notary_profile="${FERMO_NOTARYTOOL_PROFILE:-}"
if [ -n "$notary_profile" ]; then
  require_real_notary_profile "$notary_profile"
fi

if ! command -v security >/dev/null 2>&1; then
  fail "security command is required to inspect local signing identities"
fi

if ! command -v xcrun >/dev/null 2>&1; then
  fail "xcrun is required to locate notarytool"
fi

identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
developer_id_line="$(printf '%s\n' "$identity_output" | grep -F "Developer ID Application:" | grep -F "($team_id)" | head -n 1 || true)"

if [ -z "$developer_id_line" ]; then
  fail "Developer ID Application signing identity for team $team_id was not found"
fi

if ! xcrun --find notarytool >/dev/null 2>&1; then
  fail "xcrun could not find notarytool"
fi

require_project_text "DEVELOPMENT_TEAM = $team_id;"
require_project_text "FERMO_APP_GROUP_IDENTIFIER = $team_id.com.toolary.fermo;"
require_project_text "PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo;"
require_project_text "PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.filter;"
require_project_text "PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.helper;"
require_project_text "PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.appguard;"
require_project_text "CODE_SIGN_ENTITLEMENTS = FermoAppGuardExtension/FermoAppGuardExtension.entitlements;"

printf 'Fermo signed build environment\n'
printf 'Team ID: %s\n' "$team_id"
printf 'Developer ID identity: %s\n' "$developer_id_line"
printf 'notarytool: %s\n' "$(xcrun --find notarytool)"

if [ -n "$notary_profile" ]; then
  printf 'Notary profile: %s\n' "$notary_profile"
else
  printf 'Notary profile: not set (set FERMO_NOTARYTOOL_PROFILE before notarization)\n'
fi

printf 'Xcode signing source settings: OK\n'
printf 'Signed build environment preflight passed\n'
