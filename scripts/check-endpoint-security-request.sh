#!/bin/sh

set -eu

usage() {
  printf 'usage: %s\n' "$0"
  printf '\n'
  printf 'Validates the Apple Endpoint Security entitlement request packet against\n'
  printf 'the current Xcode bundle IDs, app group, entitlement source, and privacy scope.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 0 ]; then
  usage >&2
  exit 64
fi

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
request_path="$repo_root/docs/apple-endpoint-security-entitlement-request.md"
signing_path="$repo_root/docs/macos-endpoint-security-signing.md"
project_path="$repo_root/Fermo.xcodeproj/project.pbxproj"
entitlements_path="$repo_root/FermoAppGuardExtension/FermoAppGuardExtension.entitlements"
appguard_main_path="$repo_root/FermoAppGuardExtension/main.swift"

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

reject_text() {
  path="$1"
  label="$2"
  rejected="$3"

  if grep -F -- "$rejected" "$path" >/dev/null; then
    fail "$label contains forbidden text: $rejected"
  fi
}

require_file "$request_path" "Endpoint Security request"
require_file "$signing_path" "Endpoint Security signing checklist"
require_file "$project_path" "Xcode project"
require_file "$entitlements_path" "App Guard entitlements"
require_file "$appguard_main_path" "App Guard source"

require_text "$project_path" "Xcode project" "PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo;"
require_text "$project_path" "Xcode project" "PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.appguard;"
require_text "$project_path" "Xcode project" "FERMO_APP_GROUP_IDENTIFIER = MP3AWS77U3.com.toolary.fermo;"
require_text "$project_path" "Xcode project" "CODE_SIGN_ENTITLEMENTS = FermoAppGuardExtension/FermoAppGuardExtension.entitlements;"
require_text "$project_path" "Xcode project" "com.toolary.fermo.appguard.systemextension"

require_text "$entitlements_path" "App Guard entitlements" "com.apple.developer.endpoint-security.client"
require_text "$entitlements_path" "App Guard entitlements" '$(FERMO_APP_GROUP_IDENTIFIER)'
require_text "$appguard_main_path" "App Guard source" "ES_EVENT_TYPE_AUTH_EXEC"
require_text "$appguard_main_path" "App Guard source" "es_respond_auth_result"

for expected in \
  'Status: draft for Apple Developer request.' \
  'scripts/export-endpoint-security-request-packet.sh <output-dir>' \
  'com.apple.developer.endpoint-security.client' \
  'Containing app bundle ID: `com.toolary.fermo`' \
  'Endpoint Security extension bundle ID: `com.toolary.fermo.appguard`' \
  'Embedded product: `com.toolary.fermo.appguard.systemextension`' \
  'Shared app group: `MP3AWS77U3.com.toolary.fermo`' \
  'direct-distribution macOS app, signed and notarized before beta' \
  'not surveillance, device management, employee monitoring, malware inspection, or background analytics' \
  'Endpoint Security is needed specifically for `AUTH_EXEC` decisions' \
  'subscribes to `ES_EVENT_TYPE_AUTH_EXEC`' \
  'does not inspect file contents, network traffic, keystrokes, screen contents, or browser history' \
  'does not upload Endpoint Security events or focus history' \
  'stores active policy snapshots locally in the configured App Group' \
  'System Health shows Endpoint Security App Guard readiness' \
  'Diagnostics include `appGuardApproval` and `appGuardApprovalDetail`' \
  'Diagnostics include `contentFilterSnapshotState` and `appGuardSnapshotState`' \
  'Fermo does not claim impossible-to-bypass enforcement' \
  'Finder' \
  'Dock' \
  'System Settings' \
  'FermoHelper' \
  'clear enforcement after the session ends' \
  'FermoAppGuardExtension/main.swift' \
  'FermoAppGuardExtension/FermoAppGuardExtension.entitlements' \
  'docs/macos-endpoint-security-signing.md' \
  'docs/toolary-beta-runtime-matrix.md' \
  'Enable Endpoint Security for App ID `com.toolary.fermo.appguard`' \
  'Regenerate provisioning profiles' \
  'Build signed app installed at `/Applications/Fermo.app`' \
  'Run `docs/toolary-beta-runtime-matrix.md`' \
  'Run `scripts/check-beta-release-gate.sh` and `scripts/check-toolary-metadata-gate.sh` before changing Toolary metadata from `comingSoon` to `beta`' \
  'After changing Toolary metadata to `beta`, run `scripts/check-signed-beta-readiness.sh`'; do
  require_text "$request_path" "Endpoint Security request" "$expected"
done

for expected in \
  'Use `docs/apple-endpoint-security-entitlement-request.md` as the prepared request packet for Apple.' \
  'scripts/export-endpoint-security-request-packet.sh <output-dir>' \
  'Request or confirm access to `com.apple.developer.endpoint-security.client`' \
  'Create or update the App ID `com.toolary.fermo.appguard`' \
  'ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED' \
  'contentFilterSnapshotState: ready' \
  'appGuardSnapshotState: ready' \
  'scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json <manifest> <completed-runtime-matrix>' \
  'scripts/check-signed-beta-readiness.sh /Applications/Fermo.app <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json' \
  'App Launch Deny Validation'; do
  require_text "$signing_path" "Endpoint Security signing checklist" "$expected"
done

reject_text "$request_path" "Endpoint Security request" "cannot be bypassed"
reject_text "$request_path" "Endpoint Security request" "can't be bypassed"
reject_text "$request_path" "Endpoint Security request" "can’t be bypassed"
reject_text "$request_path" "Endpoint Security request" "bypass-proof"

printf 'Endpoint Security request gate passed\n'
