#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/path/to/output-dir]\n' "$0"
  printf '\n'
  printf 'Exports and validates the Apple Endpoint Security request packet.\n'
  printf 'Uses a temporary output directory when omitted.\n'
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
output_dir="${1:-$(mktemp -d /tmp/fermo-endpoint-security-packet.XXXXXX)}"

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

require_same_file() {
  expected_path="$1"
  actual_path="$2"
  label="$3"

  if ! cmp -s "$expected_path" "$actual_path"; then
    fail "$label does not match repository source file"
  fi
}

"$scripts_dir/export-endpoint-security-request-packet.sh" "$output_dir" >/dev/null

packet_path="$output_dir/PACKET.md"
request_path="$output_dir/apple-endpoint-security-entitlement-request.md"
signing_path="$output_dir/macos-endpoint-security-signing.md"
entitlements_path="$output_dir/FermoAppGuardExtension.entitlements"
xcode_summary_path="$output_dir/xcode-appguard-settings.txt"
source_request_path="$repo_root/docs/apple-endpoint-security-entitlement-request.md"
source_signing_path="$repo_root/docs/macos-endpoint-security-signing.md"
source_entitlements_path="$repo_root/FermoAppGuardExtension/FermoAppGuardExtension.entitlements"

require_file "$packet_path" "Endpoint Security request packet summary"
require_file "$request_path" "exported Endpoint Security request"
require_file "$signing_path" "exported Endpoint Security signing checklist"
require_file "$entitlements_path" "exported App Guard entitlements"
require_file "$xcode_summary_path" "exported Xcode App Guard source summary"

require_same_file "$source_request_path" "$request_path" "exported Endpoint Security request"
require_same_file "$source_signing_path" "$signing_path" "exported Endpoint Security signing checklist"
require_same_file "$source_entitlements_path" "$entitlements_path" "exported App Guard entitlements"

for expected in \
  'Entitlement: `com.apple.developer.endpoint-security.client`' \
  'Containing app bundle ID: `com.toolary.fermo`' \
  'App Guard bundle ID: `com.toolary.fermo.appguard`' \
  'Embedded product: `com.toolary.fermo.appguard.systemextension`' \
  'Shared app group: `MP3AWS77U3.com.toolary.fermo`' \
  'Output directory was empty before export.' \
  'Output path was not a symlink.' \
  'Copied request, signing checklist, and entitlement files match the repository source files at export time.' \
  'scripts/check-endpoint-security-request.sh' \
  'Before claiming Toolary beta readiness, Apple must grant the entitlement'; do
  require_text "$packet_path" "Endpoint Security request packet summary" "$expected"
done

for expected in \
  'Status: draft for Apple Developer request.' \
  'Endpoint Security is needed specifically for `AUTH_EXEC` decisions' \
  'subscribes to `ES_EVENT_TYPE_AUTH_EXEC`' \
  'does not inspect file contents, network traffic, keystrokes, screen contents, or browser history' \
  'does not upload Endpoint Security events or focus history' \
  'Fermo does not claim impossible-to-bypass enforcement' \
  'Enable Endpoint Security for App ID `com.toolary.fermo.appguard`' \
  'Run `docs/toolary-beta-runtime-matrix.md`'; do
  require_text "$request_path" "exported Endpoint Security request" "$expected"
done

for expected in \
  'Request or confirm access to `com.apple.developer.endpoint-security.client`' \
  'ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED' \
  'scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app' \
  'App Launch Deny Validation'; do
  require_text "$signing_path" "exported Endpoint Security signing checklist" "$expected"
done

for expected in \
  'com.apple.developer.endpoint-security.client' \
  '$(FERMO_APP_GROUP_IDENTIFIER)'; do
  require_text "$entitlements_path" "exported App Guard entitlements" "$expected"
done

for expected in \
  'PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.appguard;' \
  'FERMO_APP_GROUP_IDENTIFIER = MP3AWS77U3.com.toolary.fermo;' \
  'CODE_SIGN_ENTITLEMENTS = FermoAppGuardExtension/FermoAppGuardExtension.entitlements;' \
  'ES_EVENT_TYPE_AUTH_EXEC' \
  'es_respond_auth_result'; do
  require_text "$xcode_summary_path" "exported Xcode App Guard source summary" "$expected"
done

printf 'Endpoint Security request packet gate passed\n'
printf 'Packet: %s\n' "$packet_path"
