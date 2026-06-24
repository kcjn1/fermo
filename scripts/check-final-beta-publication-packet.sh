#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/publication-packet-dir /path/to/evidence-dir /path/to/beta-manifest.md /path/to/completed-runtime-matrix.md /path/to/toolary-catalog-metadata.json /path/to/notarytool.log /path/to/signed-runtime-evidence-dir\n' "$0"
  printf '\n'
  printf 'Validates the final upload-ready beta publication packet against the\n'
  printf 'source artifact, metadata, evidence archive, notary log, and signed\n'
  printf 'runtime evidence directory.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 7 ]; then
  usage >&2
  exit 64
fi

packet_dir="$1"
evidence_dir="$2"
manifest_path="$3"
matrix_path="$4"
metadata_path="$5"
notary_log_path="$6"
runtime_evidence_dir="$7"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"

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
    fail "$label does not match source file"
  fi
}

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
}

require_unique_packet_basename() {
  candidate="$1"
  label="$2"
  shift 2

  case "$candidate" in
    release-evidence.md|PUBLICATION_PACKET.md|publication-packet.sha256|signed-runtime-evidence)
      fail "$label basename conflicts with a reserved publication packet entry: $candidate"
      ;;
  esac

  for existing in "$@"; do
    if [ "$candidate" = "$existing" ]; then
      fail "$label basename conflicts with another publication packet source: $candidate"
    fi
  done
}

if [ ! -d "$packet_dir" ]; then
  fail "publication packet directory missing at $packet_dir"
fi

if [ -L "$packet_dir" ]; then
  fail "publication packet directory must not be a symlink: $packet_dir"
fi

"$scripts_dir/check-final-beta-publication-evidence.sh" \
  "$evidence_dir" \
  "$manifest_path" \
  "$matrix_path" \
  "$metadata_path" \
  "$notary_log_path" \
  "$runtime_evidence_dir" >/dev/null

zip_path="$(manifest_value "ZIP path")"
sha256="$(manifest_value SHA-256)"

if [ -z "$zip_path" ]; then
  fail "manifest does not include ZIP path"
fi

if [ -z "$sha256" ]; then
  fail "manifest does not include SHA-256"
fi

zip_basename="$(basename "$zip_path")"
checksum_basename="$(basename "$zip_path").sha256"
manifest_basename="$(basename "$manifest_path")"
matrix_basename="$(basename "$matrix_path")"
metadata_basename="$(basename "$metadata_path")"
notary_log_basename="$(basename "$notary_log_path")"

require_unique_packet_basename "$zip_basename" "ZIP artifact"
require_unique_packet_basename "$checksum_basename" "checksum file" "$zip_basename"
require_unique_packet_basename "$manifest_basename" "manifest" "$zip_basename" "$checksum_basename"
require_unique_packet_basename "$matrix_basename" "runtime matrix" "$zip_basename" "$checksum_basename" "$manifest_basename"
require_unique_packet_basename "$metadata_basename" "Toolary metadata" "$zip_basename" "$checksum_basename" "$manifest_basename" "$matrix_basename"
require_unique_packet_basename "$notary_log_basename" "notarytool log" "$zip_basename" "$checksum_basename" "$manifest_basename" "$matrix_basename" "$metadata_basename"

zip_copy="$packet_dir/$zip_basename"
checksum_copy="$packet_dir/$checksum_basename"
manifest_copy="$packet_dir/$manifest_basename"
matrix_copy="$packet_dir/$matrix_basename"
metadata_copy="$packet_dir/$metadata_basename"
evidence_copy="$packet_dir/release-evidence.md"
notary_copy="$packet_dir/$notary_log_basename"
runtime_copy="$packet_dir/signed-runtime-evidence"
packet_summary="$packet_dir/PUBLICATION_PACKET.md"
checksum_manifest="$packet_dir/publication-packet.sha256"

require_file "$zip_copy" "ZIP copy"
require_file "$checksum_copy" "checksum copy"
require_file "$manifest_copy" "manifest copy"
require_file "$matrix_copy" "runtime matrix copy"
require_file "$metadata_copy" "Toolary metadata copy"
require_file "$evidence_copy" "release evidence copy"
require_file "$notary_copy" "notarytool log copy"
require_file "$packet_summary" "publication packet summary"
require_file "$checksum_manifest" "publication packet checksum manifest"

if [ ! -d "$runtime_copy" ]; then
  fail "signed runtime evidence copy missing at $runtime_copy"
fi

require_same_file "$zip_path" "$zip_copy" "ZIP copy"
require_same_file "$zip_path.sha256" "$checksum_copy" "checksum copy"
require_same_file "$manifest_path" "$manifest_copy" "manifest copy"
require_same_file "$matrix_path" "$matrix_copy" "runtime matrix copy"
require_same_file "$metadata_path" "$metadata_copy" "Toolary metadata copy"
require_same_file "$evidence_dir/release-evidence.md" "$evidence_copy" "release evidence copy"
require_same_file "$notary_log_path" "$notary_copy" "notarytool log copy"

if ! diff -qr "$runtime_evidence_dir" "$runtime_copy" >/dev/null; then
  fail "signed runtime evidence copy does not match source directory"
fi

expected_files_path="$(mktemp /tmp/fermo-publication-packet-expected.XXXXXX)"
actual_files_path="$(mktemp /tmp/fermo-publication-packet-actual.XXXXXX)"
expected_dirs_path="$(mktemp /tmp/fermo-publication-packet-expected-dirs.XXXXXX)"
actual_dirs_path="$(mktemp /tmp/fermo-publication-packet-actual-dirs.XXXXXX)"
expected_checksum_files_path="$(mktemp /tmp/fermo-publication-packet-expected-checksums.XXXXXX)"
actual_checksum_files_path="$(mktemp /tmp/fermo-publication-packet-actual-checksums.XXXXXX)"
trap 'rm -f "$expected_files_path" "$actual_files_path" "$expected_dirs_path" "$actual_dirs_path" "$expected_checksum_files_path" "$actual_checksum_files_path"' EXIT

if find "$packet_dir" ! -type f ! -type d -print -quit | grep . >/dev/null; then
  fail "publication packet contains unsupported non-file entries"
fi

(
  cd "$packet_dir"
  {
    printf '%s\n' "$zip_basename"
    printf '%s\n' "$checksum_basename"
    printf '%s\n' "$manifest_basename"
    printf '%s\n' "$matrix_basename"
    printf '%s\n' "$metadata_basename"
    printf '%s\n' "release-evidence.md"
    printf '%s\n' "$notary_log_basename"
    printf '%s\n' "PUBLICATION_PACKET.md"
    printf '%s\n' "publication-packet.sha256"
    find signed-runtime-evidence -type f | LC_ALL=C sort
  } | LC_ALL=C sort
) > "$expected_files_path"

(
  cd "$packet_dir"
  find . -type f | sed 's#^\./##' | LC_ALL=C sort
) > "$actual_files_path"

if ! cmp -s "$expected_files_path" "$actual_files_path"; then
  fail "publication packet contains unexpected or missing files"
fi

(
  cd "$packet_dir"
  {
    printf '.\n'
    printf './signed-runtime-evidence\n'
  } | LC_ALL=C sort
) > "$expected_dirs_path"

(
  cd "$packet_dir"
  find . -type d | LC_ALL=C sort
) > "$actual_dirs_path"

if ! cmp -s "$expected_dirs_path" "$actual_dirs_path"; then
  fail "publication packet contains unexpected directories"
fi

computed_sha256="$(shasum -a 256 "$zip_copy" | awk '{print $1}')"
if [ "$computed_sha256" != "$sha256" ]; then
  fail "publication packet ZIP SHA-256 does not match manifest"
fi

if ! (
  cd "$packet_dir"
  awk '
    NF < 2 || length($1) != 64 || $1 !~ /^[0-9a-fA-F]+$/ { exit 1 }
    { seen = 1 }
    END { if (!seen) exit 1 }
  ' "$(basename "$checksum_manifest")" >/dev/null
); then
  fail "publication packet checksum manifest is malformed"
fi

grep -F -v -- "$(basename "$checksum_manifest")" "$actual_files_path" > "$expected_checksum_files_path"
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
' "$checksum_manifest" | LC_ALL=C sort > "$actual_checksum_files_path" || fail "publication packet checksum manifest is malformed"

if ! cmp -s "$expected_checksum_files_path" "$actual_checksum_files_path"; then
  fail "publication packet checksum manifest does not list exactly the packet files"
fi

(
  cd "$packet_dir"
  shasum -a 256 -c "$(basename "$checksum_manifest")" >/dev/null
) || fail "publication packet checksum manifest does not match packet files"

require_text "$packet_summary" "publication packet summary" "# Fermo Beta Publication Packet"
require_text "$packet_summary" "publication packet summary" "- ZIP: $zip_basename"
require_text "$packet_summary" "publication packet summary" "- SHA-256: $sha256"
require_text "$packet_summary" "publication packet summary" "- Release evidence: release-evidence.md"
require_text "$packet_summary" "publication packet summary" "- Signed runtime evidence: signed-runtime-evidence"
require_text "$packet_summary" "publication packet summary" "- Packet checksum manifest: publication-packet.sha256"
require_text "$packet_summary" "publication packet summary" "scripts/check-final-beta-publication-evidence.sh"

printf 'Final beta publication packet gate passed\n'
printf 'Packet: %s\n' "$packet_dir"
