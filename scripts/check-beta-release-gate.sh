#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  printf 'usage: %s /path/to/manifest.md /path/to/completed-runtime-matrix.md\n' "$0" >&2
  exit 64
fi

manifest_path="$1"
matrix_path="$2"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
}

matrix_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$matrix_path"
}

incomplete_matrix_statuses() {
  awk -F'|' '
    /^\|/ {
      status = $(NF - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)

      if (status == "Status" || status ~ /^-+$/ || status == "") {
        next
      }

      if (status != "Passed" && status != "passed") {
        print status
      }
    }
  ' "$matrix_path" | sort -u
}

require_file() {
  path="$1"
  label="$2"

  if [ ! -s "$path" ]; then
    fail "$label missing or empty at $path"
  fi
}

require_matrix_text() {
  label="$1"
  expected="$2"

  if ! grep -F -- "$expected" "$matrix_path" >/dev/null; then
    fail "runtime matrix is missing required $label: $expected"
  fi
}

read_checksum_entry() {
  checksum_path="$1"
  expected_zip_basename="$2"

  entry_count="$(awk 'NF { count++ } END { print count + 0 }' "$checksum_path")"
  if [ "$entry_count" != "1" ]; then
    fail "checksum file must contain exactly one ZIP entry"
  fi

  entry_fields="$(awk 'NF { print NF; exit }' "$checksum_path")"
  if [ "$entry_fields" != "2" ]; then
    fail "checksum file entry must contain SHA-256 and ZIP basename"
  fi

  checksum_sha256="$(awk 'NF { print $1; exit }' "$checksum_path")"
  checksum_zip_basename="$(awk 'NF { print $2; exit }' "$checksum_path")"

  if ! printf '%s\n' "$checksum_sha256" | grep -Eq '^[0-9a-fA-F]{64}$'; then
    fail "checksum file SHA-256 is malformed"
  fi

  if [ "$checksum_zip_basename" != "$expected_zip_basename" ]; then
    fail "checksum file must reference ZIP basename '$expected_zip_basename', got '$checksum_zip_basename'"
  fi
}

require_numeric_dotted_value() {
  value="$1"
  label="$2"

  if ! printf '%s\n' "$value" | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$'; then
    fail "manifest $label must be numeric dot-separated, got '$value'"
  fi
}

is_git_sha() {
  printf '%s\n' "$1" | grep -Eq '^[0-9a-fA-F]{7,40}$'
}

is_utc_timestamp() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

is_uuid() {
  printf '%s\n' "$1" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
}

require_file "$manifest_path" "manifest"
require_file "$matrix_path" "runtime matrix"

created="$(manifest_value Created)"
channel="$(manifest_value Channel)"
version="$(manifest_value Version)"
build="$(manifest_value Build)"
git_commit="$(manifest_value "Git commit")"
git_tree="$(manifest_value "Git tree")"
app_path="$(manifest_value "App path")"
zip_path="$(manifest_value "ZIP path")"
sha256="$(manifest_value SHA-256)"
runtime_matrix="$(manifest_value "Runtime matrix")"
publishable="$(manifest_value "Toolary publishable")"
matrix_date="$(matrix_value Date)"
matrix_channel="$(matrix_value Channel)"
matrix_version="$(matrix_value Version)"
matrix_build="$(matrix_value Build)"
matrix_git_commit="$(matrix_value "Git commit")"
matrix_git_tree="$(matrix_value "Git tree")"
matrix_app_path="$(matrix_value "App path")"
matrix_signing_identity="$(matrix_value "Signing identity")"
matrix_team_id="$(matrix_value "Team ID")"
matrix_zip_path="$(matrix_value "ZIP path")"
matrix_sha256="$(matrix_value SHA-256)"
matrix_publishable="$(matrix_value "Toolary publishable")"
notarization_request_id="$(matrix_value "Notarization request ID")"
matrix_tester_mac="$(matrix_value "Tester Mac")"
matrix_macos_version="$(matrix_value "macOS version")"

if [ "$channel" != "beta" ]; then
  fail "manifest channel must be beta, got '$channel'"
fi

if [ "$runtime_matrix" != "passed" ]; then
  fail "manifest runtime matrix must be passed, got '$runtime_matrix'"
fi

if [ "$publishable" != "yes" ]; then
  fail "manifest Toolary publishable must be yes, got '$publishable'"
fi

if [ -z "$version" ]; then
  fail "manifest is missing Version"
fi

if [ -z "$build" ]; then
  fail "manifest is missing Build"
fi

if [ "$version" = "0.0.0" ]; then
  fail "manifest cannot use placeholder Version 0.0.0"
fi

if [ "$build" = "0" ]; then
  fail "manifest cannot use placeholder Build 0"
fi

require_numeric_dotted_value "$version" "Version"
require_numeric_dotted_value "$build" "Build"
expected_artifact_basename="Fermo-$version-$build-$channel.zip"

if [ -z "$created" ]; then
  fail "manifest is missing Created"
fi

if ! is_utc_timestamp "$created"; then
  fail "manifest Created must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ, got '$created'"
fi

if [ -z "$git_commit" ]; then
  fail "manifest is missing Git commit"
fi

if ! is_git_sha "$git_commit"; then
  fail "manifest Git commit must be a git SHA, got '$git_commit'"
fi

if [ -z "$git_tree" ]; then
  fail "manifest is missing Git tree"
fi

if [ "$git_tree" != "clean" ]; then
  fail "manifest Git tree must be clean, got '$git_tree'"
fi

if [ -z "$app_path" ]; then
  fail "manifest is missing App path"
fi

if [ "$app_path" != "/Applications/Fermo.app" ]; then
  fail "manifest App path must be /Applications/Fermo.app, got '$app_path'"
fi

if [ -z "$zip_path" ]; then
  fail "manifest does not include ZIP path"
fi

zip_basename="$(basename "$zip_path")"
if [ "$zip_basename" != "$expected_artifact_basename" ]; then
  fail "manifest ZIP basename must be $expected_artifact_basename, got '$zip_basename'"
fi

require_file "$zip_path" "ZIP artifact"

checksum_path="$zip_path.sha256"
require_file "$checksum_path" "checksum file"

computed_sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
read_checksum_entry "$checksum_path" "$zip_basename"

if [ "$sha256" != "$computed_sha256" ]; then
  fail "manifest SHA-256 does not match ZIP artifact"
fi

if [ "$checksum_sha256" != "$computed_sha256" ]; then
  fail "checksum file does not match ZIP artifact"
fi

# Exempt only the leading prose block (the template's instructions legitimately mention
# "FERMO_RUNTIME_MATRIX_STATUS=pending|passed"); scan everything from the first table row
# onward so unfinished "| Pending |" cells AND operator-appended trailing notes are still
# caught. Match Pending/TODO/TBD only as standalone words so "appending"/"spending" do not
# false-trip the gate.
if awk '
  /^[[:space:]]*\|/ { in_table = 1 }
  in_table {
    line = tolower($0)
    if (line ~ /(^|[^a-z])(pending|todo|tbd)([^a-z]|$)/) { found = 1 }
  }
  END { exit found ? 0 : 1 }
' "$matrix_path"; then
  fail "runtime matrix still contains Pending/TODO/TBD"
fi

require_matrix_text "App Guard policy snapshot row" "| App Guard policy snapshot |"
require_matrix_text "Content Filter rule snapshot row" "| Content Filter rule snapshot |"
require_matrix_text "Content Filter ready evidence" "contentFilterSnapshotState: ready"
require_matrix_text "App Guard ready evidence" "appGuardSnapshotState: ready"
require_matrix_text "diagnostics report row" "| Diagnostics report |"

incomplete_statuses="$(incomplete_matrix_statuses)"
if [ -n "$incomplete_statuses" ]; then
  fail "runtime matrix contains non-passing status values: $(printf '%s' "$incomplete_statuses" | paste -sd ', ' -)"
fi

if [ -z "$notarization_request_id" ]; then
  fail "runtime matrix is missing notarization request ID"
fi

if ! is_uuid "$notarization_request_id"; then
  fail "runtime matrix Notarization request ID must be a UUID, got '$notarization_request_id'"
fi

if [ -z "$matrix_date" ]; then
  fail "runtime matrix is missing Date"
fi

if ! is_utc_timestamp "$matrix_date"; then
  fail "runtime matrix Date must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ, got '$matrix_date'"
fi

if [ "$matrix_date" != "$created" ]; then
  fail "runtime matrix Date does not match manifest Created"
fi

if [ -z "$matrix_channel" ]; then
  fail "runtime matrix is missing Channel"
fi

if [ "$matrix_channel" != "$channel" ]; then
  fail "runtime matrix Channel does not match manifest"
fi

if [ -z "$matrix_version" ]; then
  fail "runtime matrix is missing Version"
fi

if [ "$matrix_version" != "$version" ]; then
  fail "runtime matrix Version does not match manifest"
fi

if [ -z "$matrix_build" ]; then
  fail "runtime matrix is missing Build"
fi

if [ "$matrix_build" != "$build" ]; then
  fail "runtime matrix Build does not match manifest"
fi

if [ -z "$matrix_git_commit" ]; then
  fail "runtime matrix is missing Git commit"
fi

if [ "$matrix_git_commit" != "$git_commit" ]; then
  fail "runtime matrix Git commit does not match manifest"
fi

if [ -z "$matrix_git_tree" ]; then
  fail "runtime matrix is missing Git tree"
fi

if [ "$matrix_git_tree" != "$git_tree" ]; then
  fail "runtime matrix Git tree does not match manifest"
fi

if [ -z "$matrix_app_path" ]; then
  fail "runtime matrix is missing App path"
fi

if [ "$matrix_app_path" != "$app_path" ]; then
  fail "runtime matrix App path does not match manifest"
fi

if [ -z "$matrix_signing_identity" ]; then
  fail "runtime matrix is missing Signing identity"
fi

if [ -z "$matrix_team_id" ]; then
  fail "runtime matrix is missing Team ID"
fi

if [ -z "$matrix_zip_path" ]; then
  fail "runtime matrix is missing ZIP path"
fi

if [ "$matrix_zip_path" != "$zip_path" ]; then
  fail "runtime matrix ZIP path does not match manifest"
fi

if [ -z "$matrix_sha256" ]; then
  fail "runtime matrix is missing SHA-256"
fi

if [ "$matrix_sha256" != "$computed_sha256" ]; then
  fail "runtime matrix SHA-256 does not match ZIP artifact"
fi

if [ -z "$matrix_publishable" ]; then
  fail "runtime matrix is missing Toolary publishable"
fi

if [ "$matrix_publishable" != "$publishable" ]; then
  fail "runtime matrix Toolary publishable does not match manifest"
fi

if [ -z "$matrix_tester_mac" ]; then
  fail "runtime matrix is missing Tester Mac"
fi

if [ -z "$matrix_macos_version" ]; then
  fail "runtime matrix is missing macOS version"
fi

printf 'Beta release gate passed\n'
printf 'Manifest: %s\n' "$manifest_path"
printf 'Matrix: %s\n' "$matrix_path"
printf 'ZIP: %s\n' "$zip_path"
printf 'SHA-256: %s\n' "$computed_sha256"
