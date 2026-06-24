#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/signed-runtime-evidence-dir [/path/to/beta-manifest.md]\n' "$0"
  printf '\n'
  printf 'Validates the directory produced by collect-signed-runtime-evidence.sh.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage >&2
  exit 64
fi

evidence_dir="$1"
manifest_path="${2:-}"

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

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
}

plist_value() {
  key="$1"
  awk -F'=> ' -v key="\"$key\"" '
    index($0, key) {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$info_plist_path"
}

if [ ! -d "$evidence_dir" ]; then
  fail "signed runtime evidence directory missing at $evidence_dir"
fi

if [ -L "$evidence_dir" ]; then
  fail "signed runtime evidence directory must not be a symlink: $evidence_dir"
fi

if [ -n "$manifest_path" ]; then
  require_file "$manifest_path" "manifest"
fi

summary_path="$evidence_dir/signed-runtime-evidence.md"
system_path="$evidence_dir/system.txt"
info_plist_path="$evidence_dir/Fermo-Info.plist.txt"
preflight_path="$evidence_dir/verify-beta-candidate.txt"
spctl_path="$evidence_dir/spctl-assess.txt"
systemextensions_path="$evidence_dir/systemextensionsctl-list.txt"
runtime_approvals_path="$evidence_dir/check-signed-runtime-approvals.txt"
helper_runtime_path="$evidence_dir/check-signed-helper-runtime.txt"
launchctl_path="$evidence_dir/launchctl-helper.txt"
pgrep_path="$evidence_dir/pgrep-helper.txt"
checksum_manifest_path="$evidence_dir/signed-runtime-evidence.sha256"

expected_files_path="$(mktemp /tmp/fermo-signed-runtime-expected.XXXXXX)"
actual_files_path="$(mktemp /tmp/fermo-signed-runtime-actual.XXXXXX)"
expected_dirs_path="$(mktemp /tmp/fermo-signed-runtime-expected-dirs.XXXXXX)"
actual_dirs_path="$(mktemp /tmp/fermo-signed-runtime-actual-dirs.XXXXXX)"
expected_checksum_files_path="$(mktemp /tmp/fermo-signed-runtime-expected-checksums.XXXXXX)"
actual_checksum_files_path="$(mktemp /tmp/fermo-signed-runtime-actual-checksums.XXXXXX)"
trap 'rm -f "$expected_files_path" "$actual_files_path" "$expected_dirs_path" "$actual_dirs_path" "$expected_checksum_files_path" "$actual_checksum_files_path"' EXIT

if find "$evidence_dir" ! -type f ! -type d -print -quit | grep . >/dev/null; then
  fail "signed runtime evidence contains unsupported non-file entries"
fi

{
  printf '%s\n' "signed-runtime-evidence.md"
  printf '%s\n' "system.txt"
  printf '%s\n' "Fermo-Info.plist.txt"
  printf '%s\n' "verify-beta-candidate.txt"
  printf '%s\n' "spctl-assess.txt"
  printf '%s\n' "systemextensionsctl-list.txt"
  printf '%s\n' "check-signed-runtime-approvals.txt"
  printf '%s\n' "check-signed-helper-runtime.txt"
  printf '%s\n' "launchctl-helper.txt"
  printf '%s\n' "pgrep-helper.txt"
  printf '%s\n' "signed-runtime-evidence.sha256"
} | LC_ALL=C sort > "$expected_files_path"

(
  cd "$evidence_dir"
  find . -type f | sed 's#^\./##' | LC_ALL=C sort
) > "$actual_files_path"

if ! cmp -s "$expected_files_path" "$actual_files_path"; then
  fail "signed runtime evidence contains unexpected or missing files"
fi

printf '.\n' > "$expected_dirs_path"
(
  cd "$evidence_dir"
  find . -type d | LC_ALL=C sort
) > "$actual_dirs_path"

if ! cmp -s "$expected_dirs_path" "$actual_dirs_path"; then
  fail "signed runtime evidence contains unexpected directories"
fi

require_file "$summary_path" "signed runtime evidence summary"
require_file "$system_path" "signed runtime system metadata"
require_file "$info_plist_path" "signed runtime app Info.plist"
require_file "$preflight_path" "signed runtime candidate preflight output"
require_file "$spctl_path" "signed runtime spctl output"
require_file "$systemextensions_path" "signed runtime systemextensionsctl output"
require_file "$runtime_approvals_path" "signed runtime approvals output"
require_file "$helper_runtime_path" "signed helper runtime output"
require_file "$launchctl_path" "signed helper launchctl output"
require_file "$pgrep_path" "signed helper process output"
require_file "$checksum_manifest_path" "signed runtime evidence checksum manifest"

require_text "$summary_path" "signed runtime evidence summary" "# Fermo Signed Runtime Evidence"
require_text "$summary_path" "signed runtime evidence summary" "- App path: /Applications/Fermo.app"
require_text "$summary_path" "signed runtime evidence summary" "- Helper service: \`gui/"
require_text "$summary_path" "signed runtime evidence summary" "- FermoHelper pids:"
require_text "$summary_path" "signed runtime evidence summary" "## Captured Files"
require_text "$summary_path" "signed runtime evidence summary" "signed-runtime-evidence.sha256"
require_text "$summary_path" "signed runtime evidence summary" "## Verification"
require_text "$summary_path" "signed runtime evidence summary" "signed preflight, spctl assessment, signed runtime approvals, helper runtime, launchctl service, and FermoHelper process checks exited 0"

require_text "$system_path" "signed runtime system metadata" "created="
require_text "$system_path" "signed runtime system metadata" "hostname="
require_text "$system_path" "signed runtime system metadata" "uid="
require_text "$system_path" "signed runtime system metadata" "uname="

require_text "$preflight_path" "signed runtime candidate preflight output" "Fermo beta candidate preflight"
require_text "$preflight_path" "signed runtime candidate preflight output" "Preflight complete"
require_text "$spctl_path" "signed runtime spctl output" "accepted"
require_text "$systemextensions_path" "signed runtime systemextensionsctl output" "com.toolary.fermo.filter"
require_text "$systemextensions_path" "signed runtime systemextensionsctl output" "com.toolary.fermo.appguard"
require_text "$systemextensions_path" "signed runtime systemextensionsctl output" "activated enabled"
require_text "$runtime_approvals_path" "signed runtime approvals output" "Signed runtime approval checks passed"
require_text "$helper_runtime_path" "signed helper runtime output" "Signed helper runtime checks passed"

if [ -n "$manifest_path" ]; then
  manifest_app_path="$(manifest_value "App path")"
  manifest_version="$(manifest_value Version)"
  manifest_build="$(manifest_value Build)"
  plist_version="$(plist_value CFBundleShortVersionString)"
  plist_build="$(plist_value CFBundleVersion)"

  if [ "$manifest_app_path" != "/Applications/Fermo.app" ]; then
    fail "manifest App path must be /Applications/Fermo.app for signed runtime evidence, got '$manifest_app_path'"
  fi

  if [ -z "$plist_version" ]; then
    fail "signed runtime app Info.plist missing CFBundleShortVersionString"
  fi

  if [ -z "$plist_build" ]; then
    fail "signed runtime app Info.plist missing CFBundleVersion"
  fi

  if [ "$plist_version" != "$manifest_version" ]; then
    fail "signed runtime evidence version '$plist_version' does not match manifest Version '$manifest_version'"
  fi

  if [ "$plist_build" != "$manifest_build" ]; then
    fail "signed runtime evidence build '$plist_build' does not match manifest Build '$manifest_build'"
  fi
fi

for checksum_file in \
  signed-runtime-evidence.md \
  system.txt \
  Fermo-Info.plist.txt \
  verify-beta-candidate.txt \
  spctl-assess.txt \
  systemextensionsctl-list.txt \
  check-signed-runtime-approvals.txt \
  check-signed-helper-runtime.txt \
  launchctl-helper.txt \
  pgrep-helper.txt; do
  if ! grep -E "^[0-9a-fA-F]{64}[[:space:]]+$checksum_file$" "$checksum_manifest_path" >/dev/null; then
    fail "signed runtime evidence checksum manifest missing entry for $checksum_file"
  fi
done

awk '$0 != "signed-runtime-evidence.sha256" { print }' "$actual_files_path" > "$expected_checksum_files_path"
awk '
  NF < 2 { exit 1 }
  {
    path = $2
    for (i = 3; i <= NF; i++) {
      path = path " " $i
    }
    if (path ~ /^\// || path ~ /(^|\/)\.\.($|\/)/ || path == ".") {
      exit 1
    }
    print path
  }
' "$checksum_manifest_path" | LC_ALL=C sort > "$actual_checksum_files_path" || fail "signed runtime evidence checksum manifest is malformed"

if ! cmp -s "$expected_checksum_files_path" "$actual_checksum_files_path"; then
  fail "signed runtime evidence checksum manifest does not list exactly the captured files"
fi

if ! (cd "$evidence_dir" && shasum -a 256 -c signed-runtime-evidence.sha256 >/dev/null); then
  fail "signed runtime evidence checksum manifest does not match captured files"
fi

if ! awk 'NF && $0 !~ /^[0-9]+$/ { exit 1 }' "$pgrep_path"; then
  fail "signed helper process output must contain numeric FermoHelper PIDs"
fi

printf 'Signed runtime evidence gate passed\n'
