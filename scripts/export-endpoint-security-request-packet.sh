#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/output-dir\n' "$0"
  printf '\n'
  printf 'Validates and exports the Apple Endpoint Security entitlement request\n'
  printf 'packet: request draft, signing checklist, App Guard entitlements, and\n'
  printf 'a generated PACKET.md summary with bundle IDs and local verification steps.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

output_dir="$1"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"
request_path="$repo_root/docs/apple-endpoint-security-entitlement-request.md"
signing_path="$repo_root/docs/macos-endpoint-security-signing.md"
entitlements_path="$repo_root/FermoAppGuardExtension/FermoAppGuardExtension.entitlements"
project_path="$repo_root/Fermo.xcodeproj/project.pbxproj"
appguard_source_path="$repo_root/FermoAppGuardExtension/main.swift"

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

require_empty_output_dir() {
  path="$1"

  if [ -L "$path" ]; then
    fail "Endpoint Security request packet output path must not be a symlink: $path"
  fi

  if [ -e "$path" ] && [ ! -d "$path" ]; then
    fail "Endpoint Security request packet output path exists and is not a directory at $path"
  fi

  if [ -d "$path" ] && [ -n "$(find "$path" -mindepth 1 -print -quit)" ]; then
    fail "Endpoint Security request packet output directory must be empty: $path"
  fi
}

require_file "$request_path" "Endpoint Security request"
require_file "$signing_path" "Endpoint Security signing checklist"
require_file "$entitlements_path" "App Guard entitlements"
require_file "$project_path" "Xcode project"
require_file "$appguard_source_path" "App Guard source"
require_empty_output_dir "$output_dir"

"$scripts_dir/check-endpoint-security-request.sh" >/dev/null

mkdir -p "$output_dir"

cp "$request_path" "$output_dir/apple-endpoint-security-entitlement-request.md"
cp "$signing_path" "$output_dir/macos-endpoint-security-signing.md"
cp "$entitlements_path" "$output_dir/FermoAppGuardExtension.entitlements"

xcode_summary_path="$output_dir/xcode-appguard-settings.txt"
{
  printf 'Fermo Endpoint Security Xcode source summary\n\n'
  printf 'Required bundle identifiers and build settings from Fermo.xcodeproj/project.pbxproj:\n\n'
  grep -E 'PRODUCT_BUNDLE_IDENTIFIER = com\.toolary\.fermo(;|\.appguard;)|FERMO_APP_GROUP_IDENTIFIER = MP3AWS77U3\.com\.toolary\.fermo;|CODE_SIGN_ENTITLEMENTS = FermoAppGuardExtension/FermoAppGuardExtension\.entitlements;|com\.toolary\.fermo\.appguard\.systemextension' "$project_path" | sed 's/^[[:space:]]*//'
  printf '\nEndpoint Security source signals from FermoAppGuardExtension/main.swift:\n\n'
  grep -E 'ES_EVENT_TYPE_AUTH_EXEC|es_respond_auth_result' "$appguard_source_path" | sed 's/^[[:space:]]*//'
} > "$xcode_summary_path"

packet_path="$output_dir/PACKET.md"
created="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

{
  printf '# Fermo Endpoint Security Request Packet\n\n'
  printf -- '- Created: %s\n' "$created"
  printf -- '- Entitlement: `com.apple.developer.endpoint-security.client`\n'
  printf -- '- Containing app bundle ID: `com.toolary.fermo`\n'
  printf -- '- App Guard bundle ID: `com.toolary.fermo.appguard`\n'
  printf -- '- Embedded product: `com.toolary.fermo.appguard.systemextension`\n'
  printf -- '- Shared app group: `MP3AWS77U3.com.toolary.fermo`\n'
  printf -- '- Distribution: direct-distribution macOS app, signed and notarized before beta\n\n'
  printf -- '- Output directory was empty before export.\n\n'
  printf -- '- Output path was not a symlink.\n\n'
  printf -- '- Copied request, signing checklist, and entitlement files match the repository source files at export time.\n\n'
  printf '## Files\n\n'
  printf -- '- `apple-endpoint-security-entitlement-request.md`: request text for Apple Developer Support.\n'
  printf -- '- `macos-endpoint-security-signing.md`: signing, approval, and runtime validation checklist.\n'
  printf -- '- `FermoAppGuardExtension.entitlements`: App Guard entitlement source.\n'
  printf -- '- `xcode-appguard-settings.txt`: source bundle ID, app group, entitlement, embedded product, and AUTH_EXEC source evidence.\n\n'
  printf '## Local Validation\n\n'
  printf 'This packet was exported only after this command passed:\n\n'
  printf '```sh\n'
  printf 'scripts/check-endpoint-security-request.sh\n'
  printf '```\n\n'
  printf 'Before claiming Toolary beta readiness, Apple must grant the entitlement, provisioning profiles must be regenerated, and the signed `/Applications/Fermo.app` runtime matrix must pass.\n'
} > "$packet_path"

printf 'Exported Endpoint Security request packet\n'
printf 'Packet: %s\n' "$packet_path"
printf 'Output: %s\n' "$output_dir"
