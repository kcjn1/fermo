#!/bin/sh

set -eu

usage() {
  printf 'usage: %s\n' "$0"
  printf '\n'
  printf 'Validates release notes and Toolary beta copy drafts for required locales,\n'
  printf 'privacy/permission sections, beta constraints, and overclaim guardrails.\n'
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
release_notes_path="${FERMO_RELEASE_NOTES_PATH:-$repo_root/docs/release-notes.md}"
toolary_copy_path="${FERMO_TOOLARY_COPY_PATH:-$repo_root/docs/toolary-beta-copy.md}"
metadata_path="${FERMO_TOOLARY_METADATA_PATH:-$repo_root/docs/toolary-catalog-metadata.json}"
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

require_text() {
  path="$1"
  label="$2"
  expected="$3"

  if ! grep -F -- "$expected" "$path" >/dev/null; then
    fail "$label missing required copy: $expected"
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

reject_positive_overclaim() {
  path="$1"
  label="$2"

  if grep -Eiq "$overclaim_pattern" "$path"; then
    matches="$(grep -Ein "$overclaim_pattern" "$path")"
    allowed="$(printf '%s\n' "$matches" | grep -Eic 'No |Bez |Kein |keine |claims|claim|obietnic|Versprechen|without' || true)"
    total="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"

    if [ "$allowed" != "$total" ]; then
      fail "$label contains an overstrong bypass-resistance claim"
    fi
  fi
}

require_metadata_copy() {
  key_path="$1"
  value="$(json_value "$key_path")"

  if [ -z "$value" ]; then
    fail "Toolary metadata is missing $key_path"
  fi

  require_text "$toolary_copy_path" "Toolary beta copy" "$value"
}

require_file "$release_notes_path" "release notes"
require_file "$toolary_copy_path" "Toolary beta copy"
require_file "$metadata_path" "Toolary metadata"

if [ ! -x /usr/bin/ruby ]; then
  fail "ruby is required to validate Toolary metadata version"
fi

metadata_version="$(json_value version)"
if [ -z "$metadata_version" ]; then
  fail "Toolary metadata is missing version"
fi

require_text "$release_notes_path" "release notes" "Status: not published."
require_text "$toolary_copy_path" "Toolary beta copy" "Status: draft only."
require_text "$release_notes_path" "release notes" "## $metadata_version beta candidate draft"
require_text "$release_notes_path" "release notes" "Fermo $metadata_version introduces protected focus contracts for macOS."
require_text "$release_notes_path" "release notes" "Fermo $metadata_version wprowadza chronione kontrakty skupienia dla macOS."
require_text "$release_notes_path" "release notes" "Fermo $metadata_version fuehrt geschuetzte Fokusvertraege fuer macOS ein."

for locale in EN PL DE; do
  require_text "$release_notes_path" "release notes" "### $locale"
  require_text "$toolary_copy_path" "Toolary beta copy" "## $locale"
done

for locale in en pl de; do
  require_metadata_copy "locales.$locale.title"
  require_metadata_copy "locales.$locale.shortDescription"
done

for heading in \
  "### Catalog Title" \
  "### Short Description" \
  "### Description" \
  "### Privacy Copy" \
  "### Permission Copy" \
  "### Tytul w katalogu" \
  "### Krotki opis" \
  "### Opis" \
  "### Prywatnosc" \
  "### Uprawnienia" \
  "### Katalogtitel" \
  "### Kurzbeschreibung" \
  "### Beschreibung" \
  "### Datenschutz" \
  "### Berechtigungen"; do
  require_text "$toolary_copy_path" "Toolary beta copy" "$heading"
done

require_text "$release_notes_path" "release notes" "Known beta constraints:"
require_text "$release_notes_path" "release notes" "Ograniczenia bety:"
require_text "$release_notes_path" "release notes" "Bekannte Beta-Einschraenkungen:"
require_text "$release_notes_path" "release notes" "Endpoint Security entitlement"
require_text "$release_notes_path" "release notes" "No cloud sync"
require_text "$release_notes_path" "release notes" "Bez cloud sync"
require_text "$release_notes_path" "release notes" "Kein Cloud Sync"

require_text "$toolary_copy_path" "Toolary beta copy" "Fermo runs locally."
require_text "$toolary_copy_path" "Toolary beta copy" "Fermo działa lokalnie."
require_text "$toolary_copy_path" "Toolary beta copy" "Fermo laeuft lokal."
require_text "$toolary_copy_path" "Toolary beta copy" "does not upload your focus history"
require_text "$toolary_copy_path" "Toolary beta copy" "nie wysyła historii skupienia"
require_text "$toolary_copy_path" "Toolary beta copy" "laedt Fermo deine Fokus-Historie"
require_text "$toolary_copy_path" "Toolary beta copy" "Endpoint Security approval enables app launch enforcement"
require_text "$toolary_copy_path" "Toolary beta copy" "Endpoint Security umożliwia egzekwowanie uruchamiania aplikacji"
require_text "$toolary_copy_path" "Toolary beta copy" "Endpoint Security aktiviert App-Launch-Enforcement"

reject_positive_overclaim "$release_notes_path" "release notes"
reject_positive_overclaim "$toolary_copy_path" "Toolary beta copy"

printf 'Release copy gate passed\n'
