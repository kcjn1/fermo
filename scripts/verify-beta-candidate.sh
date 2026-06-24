#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/Applications/Fermo.app]\n' "$0"
  printf '\n'
  printf 'Verifies the Fermo app bundle, embedded extensions, helper, signature,\n'
  printf 'notarization, bundle identifiers, package types, and required entitlements.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 64
fi

app_path="${1:-/Applications/Fermo.app}"
skip_signature_checks="${FERMO_SKIP_SIGNATURE_CHECKS:-0}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

case "$skip_signature_checks" in
  0|1)
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '$skip_signature_checks'"
    ;;
esac

require_path() {
  path="$1"
  label="$2"

  if [ ! -e "$path" ]; then
    fail "$label missing at $path"
  fi
}

require_directory() {
  path="$1"
  label="$2"

  if [ ! -d "$path" ]; then
    fail "$label missing at $path"
  fi
}

plist_value() {
  bundle_path="$1"
  key="$2"

  if [ ! -x /usr/libexec/PlistBuddy ]; then
    fail "PlistBuddy is required to validate bundle Info.plist"
  fi

  /usr/libexec/PlistBuddy -c "Print :$key" "$bundle_path/Contents/Info.plist" 2>/dev/null || true
}

require_plist_value() {
  bundle_path="$1"
  key="$2"
  expected="$3"
  label="$4"
  value="$(plist_value "$bundle_path" "$key")"

  if [ "$value" != "$expected" ]; then
    fail "$label $key must be $expected, got '$value'"
  fi
}

require_signed_entitlement() {
  bundle_path="$1"
  entitlement_key="$2"
  expected_value="$3"
  label="$4"

  entitlements="$(codesign -d --entitlements :- "$bundle_path" 2>/dev/null || true)"
  if [ -z "$entitlements" ]; then
    fail "$label entitlements could not be read from signed bundle"
  fi

  if ! printf '%s\n' "$entitlements" | grep -Fq "$entitlement_key"; then
    fail "$label missing entitlement $entitlement_key"
  fi

  if [ -n "$expected_value" ] && ! printf '%s\n' "$entitlements" | grep -Fq "$expected_value"; then
    fail "$label entitlement $entitlement_key does not include $expected_value"
  fi
}

verify_signed_bundle() {
  bundle_path="$1"
  label="$2"

  if ! codesign --verify --strict --verbose=2 "$bundle_path"; then
    fail "$label signature verification failed"
  fi
}

printf 'Fermo beta candidate preflight\n'
printf 'App: %s\n' "$app_path"

require_directory "$app_path" "Fermo.app"
require_path "$app_path/Contents/MacOS/Fermo" "Fermo executable"

system_extensions_dir="$app_path/Contents/Library/SystemExtensions"
filter_extension_path="$system_extensions_dir/com.toolary.fermo.filter.systemextension"
appguard_extension_path="$system_extensions_dir/com.toolary.fermo.appguard.systemextension"

login_items_dir="$app_path/Contents/Library/LoginItems"
helper_app_path="$login_items_dir/FermoHelper.app"

require_directory "$system_extensions_dir" "SystemExtensions directory"
require_directory "$filter_extension_path" "Network Extension"
require_directory "$appguard_extension_path" "App Guard Endpoint Security extension"
require_directory "$login_items_dir" "LoginItems directory"
require_directory "$helper_app_path" "FermoHelper login item"

require_plist_value "$app_path" "CFBundleIdentifier" "com.toolary.fermo" "Fermo.app"
require_plist_value "$app_path" "CFBundlePackageType" "APPL" "Fermo.app"
require_plist_value "$filter_extension_path" "CFBundleIdentifier" "com.toolary.fermo.filter" "Network Extension"
require_plist_value "$filter_extension_path" "CFBundlePackageType" "SYSX" "Network Extension"
require_plist_value "$appguard_extension_path" "CFBundleIdentifier" "com.toolary.fermo.appguard" "App Guard Endpoint Security extension"
require_plist_value "$appguard_extension_path" "CFBundlePackageType" "SYSX" "App Guard Endpoint Security extension"
require_plist_value "$helper_app_path" "CFBundleIdentifier" "com.toolary.fermo.helper" "FermoHelper login item"
require_plist_value "$helper_app_path" "CFBundlePackageType" "APPL" "FermoHelper login item"

if [ "$skip_signature_checks" = "1" ]; then
  printf 'SKIP signature/notarization checks because FERMO_SKIP_SIGNATURE_CHECKS=1\n'
else
  verify_signed_bundle "$app_path" "Fermo.app"
  verify_signed_bundle "$filter_extension_path" "Network Extension"
  verify_signed_bundle "$appguard_extension_path" "App Guard Endpoint Security extension"
  verify_signed_bundle "$helper_app_path" "FermoHelper login item"
  spctl --assess --type execute --verbose=4 "$app_path"
fi

if [ "$skip_signature_checks" != "1" ]; then
  require_signed_entitlement "$app_path" "com.apple.developer.system-extension.install" "" "Fermo.app"
  require_signed_entitlement "$app_path" "com.apple.security.application-groups" "com.toolary.fermo" "Fermo.app"
  require_signed_entitlement "$filter_extension_path" "com.apple.developer.networking.networkextension" "content-filter-provider" "Network Extension"
  require_signed_entitlement "$filter_extension_path" "com.apple.security.application-groups" "com.toolary.fermo" "Network Extension"
  require_signed_entitlement "$appguard_extension_path" "com.apple.developer.endpoint-security.client" "" "App Guard Endpoint Security extension"
  require_signed_entitlement "$appguard_extension_path" "com.apple.security.application-groups" "com.toolary.fermo" "App Guard Endpoint Security extension"
  require_signed_entitlement "$helper_app_path" "com.apple.security.application-groups" "com.toolary.fermo" "FermoHelper login item"
fi

printf 'OK embedded Network Extension: %s\n' "$filter_extension_path"
printf 'OK embedded App Guard: %s\n' "$appguard_extension_path"
printf 'OK embedded helper: %s\n' "$helper_app_path"
printf 'Preflight complete. Continue with macOS approval and runtime matrix checks.\n'
