#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/Fermo.app\n' "$0"
  printf '\n'
  printf 'Packages an unsigned dogfood/dev candidate into a temporary directory,\n'
  printf 'verifies ZIP/SHA/manifest consistency, and prepares a runtime matrix draft.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"
app_path="$1"
output_dir="${FERMO_DOGFOOD_PACKAGE_OUTPUT_DIR:-$(mktemp -d /tmp/fermo-dogfood-package.XXXXXX)}"

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

sanitize() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-'
}

require_file() {
  path="$1"
  label="$2"

  if [ ! -s "$path" ]; then
    fail "$label missing or empty at $path"
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

printf 'Fermo dogfood package flow\n'
printf 'App: %s\n' "$app_path"
printf 'Output: %s\n' "$output_dir"

FERMO_SKIP_SIGNATURE_CHECKS=1 \
  FERMO_RELEASE_CHANNEL=dogfood-dev \
  FERMO_RUNTIME_MATRIX_STATUS=pending \
  "$scripts_dir/package-beta-candidate.sh" "$app_path" "$output_dir"

manifest_path="$(find "$output_dir" -maxdepth 1 -name 'Fermo-*-dogfood-dev-manifest.md' -print | head -n 1)"
if [ -z "$manifest_path" ]; then
  fail "dogfood/dev manifest was not created"
fi

zip_path="$(manifest_value "ZIP path")"
sha256="$(manifest_value SHA-256)"
checksum_path="$zip_path.sha256"
matrix_path="$output_dir/$(basename "$manifest_path" -manifest.md)-runtime-matrix.md"

require_file "$manifest_path" "manifest"
require_file "$zip_path" "ZIP artifact"
require_file "$checksum_path" "checksum file"

computed_sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
read_checksum_entry "$checksum_path" "$(basename "$zip_path")"

if [ "$sha256" != "$computed_sha256" ]; then
  fail "manifest SHA-256 does not match ZIP artifact"
fi

if [ "$checksum_sha256" != "$computed_sha256" ]; then
  fail "checksum file does not match ZIP artifact"
fi

if [ "$(manifest_value Channel)" != "dogfood-dev" ]; then
  fail "manifest channel must be dogfood-dev"
fi

if [ "$(manifest_value "Runtime matrix")" != "pending" ]; then
  fail "dogfood/dev manifest runtime matrix must stay pending"
fi

if [ "$(manifest_value "Toolary publishable")" != "no" ]; then
  fail "dogfood/dev manifest must not be Toolary publishable"
fi

manifest_version="$(manifest_value Version)"
manifest_build="$(manifest_value Build)"
manifest_channel="$(manifest_value Channel)"
expected_zip_basename="Fermo-$(sanitize "$manifest_version")-$(sanitize "$manifest_build")-$(sanitize "$manifest_channel").zip"
zip_basename="$(basename "$zip_path")"

if [ "$zip_basename" != "$expected_zip_basename" ]; then
  fail "dogfood/dev ZIP basename must be $expected_zip_basename, got '$zip_basename'"
fi

"$scripts_dir/check-candidate-manifest-app.sh" "$app_path" "$manifest_path" >/dev/null

"$scripts_dir/prepare-beta-runtime-matrix.sh" \
  "$manifest_path" \
  "$repo_root/docs/toolary-beta-runtime-matrix.md" \
  "$matrix_path"

require_file "$matrix_path" "prepared runtime matrix"

if [ "$(matrix_value Date)" != "$(manifest_value Created)" ]; then
  fail "prepared matrix Date does not match manifest Created"
fi

if [ "$(matrix_value Channel)" != "$(manifest_value Channel)" ]; then
  fail "prepared matrix Channel does not match manifest"
fi

if [ "$(matrix_value Version)" != "$(manifest_value Version)" ]; then
  fail "prepared matrix Version does not match manifest"
fi

if [ "$(matrix_value Build)" != "$(manifest_value Build)" ]; then
  fail "prepared matrix Build does not match manifest"
fi

if [ "$(matrix_value "Git commit")" != "$(manifest_value "Git commit")" ]; then
  fail "prepared matrix Git commit does not match manifest"
fi

if [ "$(matrix_value "Git tree")" != "$(manifest_value "Git tree")" ]; then
  fail "prepared matrix Git tree does not match manifest"
fi

if [ "$(matrix_value "App path")" != "$(manifest_value "App path")" ]; then
  fail "prepared matrix App path does not match manifest"
fi

if [ "$(matrix_value "ZIP path")" != "$zip_path" ]; then
  fail "prepared matrix ZIP path does not match manifest"
fi

if [ "$(matrix_value SHA-256)" != "$computed_sha256" ]; then
  fail "prepared matrix SHA-256 does not match ZIP artifact"
fi

if [ "$(matrix_value "Toolary publishable")" != "$(manifest_value "Toolary publishable")" ]; then
  fail "prepared matrix Toolary publishable does not match manifest"
fi

"$scripts_dir/check-toolary-metadata-gate.sh" "$repo_root/docs/toolary-catalog-metadata.json" >/dev/null

printf 'Dogfood package flow passed\n'
printf 'Manifest: %s\n' "$manifest_path"
printf 'Matrix: %s\n' "$matrix_path"
printf 'ZIP: %s\n' "$zip_path"
printf 'SHA-256: %s\n' "$computed_sha256"
