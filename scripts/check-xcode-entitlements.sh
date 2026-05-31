#!/bin/sh

set -eu

usage() {
  printf 'usage: %s\n' "$0"
  printf '\n'
  printf 'Validates source Xcode project bundle IDs, build versions, app group\n'
  printf 'settings, and entitlements for the app, helper, Network Extension,\n'
  printf 'and App Guard extension.\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  FERMO_XCODE_PROJECT_PATH  Override project.pbxproj path for synthetic checks\n'
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
project_path="${FERMO_XCODE_PROJECT_PATH:-$repo_root/Fermo.xcodeproj/project.pbxproj}"
app_group_setting="MP3AWS77U3.com.toolary.fermo"

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

require_project_entitlements() {
  label="$1"
  relative_path="$2"
  count="$(grep -F "CODE_SIGN_ENTITLEMENTS = $relative_path;" "$project_path" | wc -l | tr -d ' ')"

  if [ "$count" -lt 2 ]; then
    fail "$label must reference $relative_path for Debug and Release"
  fi
}

require_project_bundle_identifier() {
  label="$1"
  bundle_identifier="$2"
  count="$(grep -F "PRODUCT_BUNDLE_IDENTIFIER = $bundle_identifier;" "$project_path" | wc -l | tr -d ' ')"

  if [ "$count" -lt 2 ]; then
    fail "$label must use PRODUCT_BUNDLE_IDENTIFIER = $bundle_identifier for Debug and Release"
  fi
}

plist_print() {
  relative_path="$1"
  key="$2"

  /usr/libexec/PlistBuddy -c "Print :$key" "$repo_root/$relative_path" 2>/dev/null || true
}

require_boolean_true() {
  relative_path="$1"
  key="$2"
  value="$(plist_print "$relative_path" "$key")"

  if [ "$value" != "true" ]; then
    fail "$relative_path missing true entitlement $key"
  fi
}

require_array_value() {
  relative_path="$1"
  key="$2"
  expected="$3"
  value="$(plist_print "$relative_path" "$key")"

  if ! printf '%s\n' "$value" | grep -F "$expected" >/dev/null; then
    fail "$relative_path missing $expected in entitlement $key"
  fi
}

require_app_group() {
  relative_path="$1"
  value="$(plist_print "$relative_path" "com.apple.security.application-groups")"

  if printf '%s\n' "$value" | grep -F "$app_group_setting" >/dev/null; then
    return
  fi

  if printf '%s\n' "$value" | grep -F '$(FERMO_APP_GROUP_IDENTIFIER)' >/dev/null; then
    return
  fi

  fail "$relative_path missing Fermo app group entitlement"
}

require_single_project_setting_value() {
  setting="$1"
  values="$(awk -F'= ' -v setting="$setting" '
    index($1, setting) > 0 {
      value = $2
      gsub(/;[[:space:]]*$/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
    }
  ' "$project_path" | sort -u)"

  if [ -z "$values" ]; then
    fail "project is missing $setting"
  fi

  count="$(printf '%s\n' "$values" | wc -l | tr -d ' ')"
  if [ "$count" != "1" ]; then
    fail "project has inconsistent $setting values"
  fi
}

require_file "$project_path" "Xcode project"

if [ ! -x /usr/libexec/PlistBuddy ]; then
  fail "PlistBuddy is required to validate entitlements"
fi

if ! grep -F "FERMO_APP_GROUP_IDENTIFIER = $app_group_setting;" "$project_path" >/dev/null; then
  fail "project missing FERMO_APP_GROUP_IDENTIFIER = $app_group_setting"
fi

require_single_project_setting_value "MARKETING_VERSION"
require_single_project_setting_value "CURRENT_PROJECT_VERSION"

require_project_bundle_identifier "Fermo app" "com.toolary.fermo"
require_project_bundle_identifier "FermoFilterExtension" "com.toolary.fermo.filter"
require_project_bundle_identifier "FermoHelper" "com.toolary.fermo.helper"
require_project_bundle_identifier "FermoAppGuardExtension" "com.toolary.fermo.appguard"

require_project_entitlements "Fermo app" "Xcode/Fermo/Fermo.entitlements"
require_project_entitlements "FermoFilterExtension" "FermoFilterExtension/FermoFilterExtension.entitlements"
require_project_entitlements "FermoHelper" "Xcode/FermoHelper/FermoHelper.entitlements"
require_project_entitlements "FermoAppGuardExtension" "FermoAppGuardExtension/FermoAppGuardExtension.entitlements"

for entitlements_path in \
  "Xcode/Fermo/Fermo.entitlements" \
  "FermoFilterExtension/FermoFilterExtension.entitlements" \
  "Xcode/FermoHelper/FermoHelper.entitlements" \
  "FermoAppGuardExtension/FermoAppGuardExtension.entitlements"; do
  require_file "$repo_root/$entitlements_path" "$entitlements_path"
  plutil -lint "$repo_root/$entitlements_path" >/dev/null
  require_app_group "$entitlements_path"
done

require_boolean_true "Xcode/Fermo/Fermo.entitlements" "com.apple.developer.system-extension.install"
require_array_value "Xcode/Fermo/Fermo.entitlements" "com.apple.developer.networking.networkextension" "content-filter-provider"

require_boolean_true "FermoFilterExtension/FermoFilterExtension.entitlements" "com.apple.security.app-sandbox"
require_array_value "FermoFilterExtension/FermoFilterExtension.entitlements" "com.apple.developer.networking.networkextension" "content-filter-provider"

require_array_value "Xcode/FermoHelper/FermoHelper.entitlements" "com.apple.developer.networking.networkextension" "content-filter-provider"

require_boolean_true "FermoAppGuardExtension/FermoAppGuardExtension.entitlements" "com.apple.developer.endpoint-security.client"

printf 'Xcode entitlements source gate passed\n'
