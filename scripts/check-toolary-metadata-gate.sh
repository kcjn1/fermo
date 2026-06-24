#!/bin/sh

set -eu

if [ "$#" -ne 1 ] && [ "$#" -ne 3 ]; then
  printf 'usage: %s /path/to/toolary-catalog-metadata.json [/path/to/manifest.md /path/to/completed-runtime-matrix.md]\n' "$0" >&2
  exit 64
fi

metadata_path="$1"
manifest_path="${2:-}"
matrix_path="${3:-}"
overclaim_pattern='cannot be bypassed|can.t be bypassed|impossible to bypass|impossible blocker|unbreakable blocker|guaranteed enforcement|bypass-proof|nie do obejscia|nie do obejścia|nie do obej|nie da sie obejsc|nie da się obejść|nie można obejść|nie mozna obejsc|niemożliwe do obejścia|niemożliwe do obejscia|niemozliwe do obejscia|unmoeglich zu umgehen|unmöglich zu umgehen|nicht zu umgehen|nicht umgehbar|umgehungssicher'

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

json_value() {
  key_path="$1"

  /usr/bin/ruby -rjson -e '
    key_path = ARGV.fetch(0)
    metadata_path = ARGV.fetch(1)
    data = JSON.parse(File.read(metadata_path))
    value = key_path.split(".").reduce(data) do |current, key|
      current.is_a?(Hash) ? current[key] : nil
    end
    puts value unless value.nil?
  ' "$key_path" "$metadata_path" 2>/dev/null || true
}

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
}

require_json_value() {
  key_path="$1"
  value="$(json_value "$key_path")"

  if [ -z "$value" ]; then
    fail "metadata is missing $key_path"
  fi
}

require_json_equals() {
  key_path="$1"
  expected="$2"
  value="$(json_value "$key_path")"

  if [ -z "$value" ]; then
    fail "metadata is missing $key_path"
  fi

  if [ "$value" != "$expected" ]; then
    fail "metadata $key_path must be $expected"
  fi
}

require_file "$metadata_path" "Toolary metadata"

if [ ! -x /usr/bin/ruby ]; then
  fail "ruby is required to validate Toolary metadata"
fi

/usr/bin/ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "$metadata_path"

status="$(json_value status)"
product="$(json_value product)"
version="$(json_value version)"

if [ "$product" != "Fermo" ]; then
  fail "metadata product must be Fermo, got '$product'"
fi

if [ -z "$version" ]; then
  fail "metadata is missing version"
fi

require_json_equals releaseChannel beta
require_json_equals distribution direct-macos
require_json_equals releaseGate.requiredScript scripts/check-toolary-metadata-gate.sh
require_json_equals releaseGate.requiredStatusBeforeGate comingSoon
require_json_equals releaseGate.publishableStatusAfterGate beta
require_json_equals releaseGate.requiresSignedNotarizedApp true
require_json_equals releaseGate.requiresRuntimeMatrix true
require_json_equals releaseGate.requiresArtifactChecksum true

case "$status" in
  comingSoon|beta)
    ;;
  *)
    fail "metadata status must be comingSoon or beta, got '$status'"
    ;;
esac

for locale in en pl de; do
  require_json_value "locales.$locale.title"
  require_json_value "locales.$locale.shortDescription"
  require_json_value "locales.$locale.description"
  require_json_value "locales.$locale.privacy"
  require_json_value "locales.$locale.permissions"
done

if grep -Eiq "$overclaim_pattern" "$metadata_path"; then
  fail "metadata contains an overstrong bypass-resistance claim"
fi

scripts_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ -n "$manifest_path" ]; then
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path" >/dev/null

  manifest_version="$(manifest_value Version)"
  if [ -z "$manifest_version" ]; then
    fail "manifest is missing Version"
  fi

  if [ "$version" != "$manifest_version" ]; then
    fail "metadata version must match manifest Version '$manifest_version', got '$version'"
  fi

  printf 'Toolary metadata gate passed\n'
  printf 'Metadata: %s\n' "$metadata_path"
  printf 'Status: %s\n' "$status"
  printf 'Manifest: %s\n' "$manifest_path"
  printf 'Matrix: %s\n' "$matrix_path"

  if [ "$status" = "comingSoon" ]; then
    printf 'Artifact gate: passed\n'
    printf 'Publication: change metadata status to beta in the release branch before publishing\n'
  fi

  exit 0
fi

if [ "$status" = "beta" ]; then
  fail "beta metadata requires manifest and completed runtime matrix"
fi

printf 'Toolary metadata gate passed\n'
printf 'Metadata: %s\n' "$metadata_path"
printf 'Status: comingSoon\n'
printf 'Publication: blocked until beta release gate passes\n'
