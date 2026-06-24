#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/evidence-dir /path/to/beta-manifest.md /path/to/completed-runtime-matrix.md /path/to/toolary-catalog-metadata.json [/path/to/notarytool.log] [/path/to/signed-runtime-evidence-dir]\n' "$0"
  printf '\n'
  printf 'Validates a Fermo beta release evidence directory after the final signed\n'
  printf 'readiness gate: release-evidence.md, manifest copy, runtime matrix copy,\n'
  printf 'metadata copy, checksum copy, optional notarytool log copy, optional signed\n'
  printf 'runtime evidence copy, ZIP path, and SHA-256 references.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 4 ] || [ "$#" -gt 6 ]; then
  usage >&2
  exit 64
fi

evidence_dir="$1"
manifest_path="$2"
matrix_path="$3"
metadata_path="$4"
notary_log_path="${5:-}"
runtime_evidence_dir="${6:-}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"
tmp_dir="$(mktemp -d /tmp/fermo-beta-release-evidence-archive.XXXXXX)"

cleanup() {
  rm -rf "$tmp_dir"
}

trap cleanup EXIT HUP INT TERM

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

matrix_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$matrix_path"
}

read_checksum_entry() {
  checksum_file="$1"
  expected_zip_basename="$2"

  checksum_line_count="$(awk 'NF > 0 { count += 1 } END { print count + 0 }' "$checksum_file")"
  if [ "$checksum_line_count" != "1" ]; then
    fail "checksum copy must contain exactly one ZIP entry"
  fi

  # shellcheck disable=SC2086
  set -- $(awk 'NF > 0 { print; exit }' "$checksum_file")
  if [ "$#" -ne 2 ]; then
    fail "checksum copy entry must contain SHA-256 and ZIP basename"
  fi

  checksum_sha256="$1"
  checksum_zip_basename="$2"

  case "$checksum_sha256" in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
      ;;
    *)
      fail "checksum copy SHA-256 is malformed"
      ;;
  esac

  if [ "$checksum_zip_basename" != "$expected_zip_basename" ]; then
    fail "checksum copy must reference ZIP basename '$expected_zip_basename', got '$checksum_zip_basename'"
  fi

  printf '%s\n' "$checksum_sha256"
}

require_unique_archive_basename() {
  candidate="$1"
  label="$2"
  shift 2

  case "$candidate" in
    release-evidence.md|signed-runtime-evidence)
      fail "$label basename conflicts with a reserved release evidence archive entry: $candidate"
      ;;
  esac

  for existing in "$@"; do
    if [ "$candidate" = "$existing" ]; then
      fail "$label basename conflicts with another release evidence source: $candidate"
    fi
  done
}

if [ ! -d "$evidence_dir" ]; then
  fail "evidence directory missing at $evidence_dir"
fi

if [ -L "$evidence_dir" ]; then
  fail "release evidence archive directory must not be a symlink: $evidence_dir"
fi

require_file "$manifest_path" "manifest"
require_file "$matrix_path" "completed runtime matrix"
require_file "$metadata_path" "Toolary metadata"

if [ -n "$notary_log_path" ]; then
  require_file "$notary_log_path" "notarytool log"
fi

if [ -n "$runtime_evidence_dir" ]; then
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_dir" "$manifest_path" >/dev/null
fi

zip_path="$(manifest_value "ZIP path")"
sha256="$(manifest_value SHA-256)"
version="$(manifest_value Version)"
build="$(manifest_value Build)"
channel="$(manifest_value Channel)"
created="$(manifest_value Created)"
git_commit="$(manifest_value "Git commit")"
git_tree="$(manifest_value "Git tree")"
matrix_notary_request_id="$(matrix_value "Notarization request ID")"
notary_log_hash=""
runtime_checksum_hash=""

if [ -z "$zip_path" ]; then
  fail "manifest does not include ZIP path"
fi

if [ -z "$sha256" ]; then
  fail "manifest does not include SHA-256"
fi

require_file "$zip_path" "ZIP artifact"
require_file "$zip_path.sha256" "checksum file"

manifest_basename="$(basename "$manifest_path")"
matrix_basename="$(basename "$matrix_path")"
metadata_basename="$(basename "$metadata_path")"
checksum_basename="$(basename "$zip_path").sha256"
notary_log_basename=""

require_unique_archive_basename "$manifest_basename" "manifest"
require_unique_archive_basename "$matrix_basename" "runtime matrix" "$manifest_basename"
require_unique_archive_basename "$metadata_basename" "Toolary metadata" "$manifest_basename" "$matrix_basename"
require_unique_archive_basename "$checksum_basename" "checksum file" "$manifest_basename" "$matrix_basename" "$metadata_basename"

if [ -n "$notary_log_path" ]; then
  notary_log_basename="$(basename "$notary_log_path")"
  require_unique_archive_basename "$notary_log_basename" "notarytool log" "$manifest_basename" "$matrix_basename" "$metadata_basename" "$checksum_basename"
fi

evidence_path="$evidence_dir/release-evidence.md"
manifest_copy="$evidence_dir/$manifest_basename"
matrix_copy="$evidence_dir/$matrix_basename"
metadata_copy="$evidence_dir/$metadata_basename"
checksum_copy="$evidence_dir/$checksum_basename"
notary_log_copy=""
runtime_evidence_copy=""

if [ -n "$notary_log_path" ]; then
  notary_log_copy="$evidence_dir/$notary_log_basename"
fi

if [ -n "$runtime_evidence_dir" ]; then
  runtime_evidence_copy="$evidence_dir/signed-runtime-evidence"
fi

require_file "$evidence_path" "release evidence summary"
require_file "$manifest_copy" "manifest copy"
require_file "$matrix_copy" "runtime matrix copy"
require_file "$metadata_copy" "Toolary metadata copy"
require_file "$checksum_copy" "checksum copy"

if [ -n "$notary_log_path" ]; then
  require_file "$notary_log_copy" "notarytool log copy"
fi

if [ -n "$runtime_evidence_dir" ]; then
  if [ ! -d "$runtime_evidence_copy" ]; then
    fail "signed runtime evidence copy missing at $runtime_evidence_copy"
  fi
fi

unsupported_entry="$(find "$evidence_dir" -mindepth 1 ! -type f ! -type d -print -quit)"
if [ -n "$unsupported_entry" ]; then
  fail "release evidence archive contains unsupported non-file entries: $unsupported_entry"
fi

expected_dirs_path="$tmp_dir/expected-dirs.txt"
actual_dirs_path="$tmp_dir/actual-dirs.txt"
{
  printf '.\n'
  if [ -n "$runtime_evidence_dir" ]; then
    printf './signed-runtime-evidence\n'
  fi
} | LC_ALL=C sort > "$expected_dirs_path"
(
  cd "$evidence_dir"
  find . -type d | LC_ALL=C sort
) > "$actual_dirs_path"
if ! cmp -s "$expected_dirs_path" "$actual_dirs_path"; then
  fail "release evidence archive contains unexpected directories"
fi

expected_files_path="$tmp_dir/expected-files.txt"
actual_files_path="$tmp_dir/actual-files.txt"
{
  printf './release-evidence.md\n'
  printf './%s\n' "$manifest_basename"
  printf './%s\n' "$matrix_basename"
  printf './%s\n' "$metadata_basename"
  printf './%s\n' "$checksum_basename"
  if [ -n "$notary_log_path" ]; then
    printf './%s\n' "$notary_log_basename"
  fi
  if [ -n "$runtime_evidence_dir" ]; then
    printf './signed-runtime-evidence/signed-runtime-evidence.md\n'
    printf './signed-runtime-evidence/system.txt\n'
    printf './signed-runtime-evidence/Fermo-Info.plist.txt\n'
    printf './signed-runtime-evidence/verify-beta-candidate.txt\n'
    printf './signed-runtime-evidence/spctl-assess.txt\n'
    printf './signed-runtime-evidence/systemextensionsctl-list.txt\n'
    printf './signed-runtime-evidence/check-signed-runtime-approvals.txt\n'
    printf './signed-runtime-evidence/check-signed-helper-runtime.txt\n'
    printf './signed-runtime-evidence/launchctl-helper.txt\n'
    printf './signed-runtime-evidence/pgrep-helper.txt\n'
    printf './signed-runtime-evidence/signed-runtime-evidence.sha256\n'
  fi
} | LC_ALL=C sort > "$expected_files_path"
(
  cd "$evidence_dir"
  find . -type f | LC_ALL=C sort
) > "$actual_files_path"
if ! cmp -s "$expected_files_path" "$actual_files_path"; then
  fail "release evidence archive contains unexpected or missing files"
fi

require_same_file "$manifest_path" "$manifest_copy" "manifest copy"
require_same_file "$matrix_path" "$matrix_copy" "runtime matrix copy"
require_same_file "$metadata_path" "$metadata_copy" "Toolary metadata copy"
require_same_file "$zip_path.sha256" "$checksum_copy" "checksum copy"

checksum_copy_sha256="$(read_checksum_entry "$checksum_copy" "$(basename "$zip_path")")"
if [ "$checksum_copy_sha256" != "$sha256" ]; then
  fail "checksum copy SHA-256 does not match manifest"
fi

if [ -n "$notary_log_path" ]; then
  require_same_file "$notary_log_path" "$notary_log_copy" "notarytool log copy"
  notary_request_id="$("$scripts_dir/check-notarytool-log.sh" --id-only "$notary_log_path")"
  "$scripts_dir/check-notarytool-log.sh" "$notary_log_copy" >/dev/null
  notary_log_hash="$(shasum -a 256 "$notary_log_copy" | awk '{print $1}')"

  if [ "$matrix_notary_request_id" != "$notary_request_id" ]; then
    fail "runtime matrix Notarization request ID '$matrix_notary_request_id' does not match notarytool log request ID '$notary_request_id'"
  fi
fi

if [ -n "$runtime_evidence_dir" ]; then
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_copy" "$manifest_path" >/dev/null
  if ! diff -qr "$runtime_evidence_dir" "$runtime_evidence_copy" >/dev/null; then
    fail "signed runtime evidence copy does not match source directory"
  fi
  runtime_checksum_hash="$(shasum -a 256 "$runtime_evidence_copy/signed-runtime-evidence.sha256" | awk '{print $1}')"
fi

computed_sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
if [ "$computed_sha256" != "$sha256" ]; then
  fail "manifest SHA-256 does not match ZIP artifact"
fi

require_text "$evidence_path" "release evidence summary" "# Fermo Beta Release Evidence"
require_text "$evidence_path" "release evidence summary" "- Candidate created: $created"
require_text "$evidence_path" "release evidence summary" "- Channel: $channel"
require_text "$evidence_path" "release evidence summary" "- Version: $version"
require_text "$evidence_path" "release evidence summary" "- Build: $build"
require_text "$evidence_path" "release evidence summary" "- Git commit: $git_commit"
require_text "$evidence_path" "release evidence summary" "- Git tree: $git_tree"
require_text "$evidence_path" "release evidence summary" "- App path: /Applications/Fermo.app"
require_text "$evidence_path" "release evidence summary" "- ZIP path: $zip_path"
require_text "$evidence_path" "release evidence summary" "- ZIP basename: $(basename "$zip_path")"
require_text "$evidence_path" "release evidence summary" "- SHA-256: $sha256"
require_text "$evidence_path" "release evidence summary" "- Manifest: $manifest_basename"
require_text "$evidence_path" "release evidence summary" "- Runtime matrix: $matrix_basename"
require_text "$evidence_path" "release evidence summary" "- Toolary metadata: $metadata_basename"
require_text "$evidence_path" "release evidence summary" "- Checksum file: $checksum_basename"
if [ -n "$notary_log_path" ]; then
  require_text "$evidence_path" "release evidence summary" "- Notarization request ID: $notary_request_id"
  require_text "$evidence_path" "release evidence summary" "- Notary log: $notary_log_basename"
  require_text "$evidence_path" "release evidence summary" "- Notary log SHA-256: $notary_log_hash"
fi
if [ -n "$runtime_evidence_dir" ]; then
  require_text "$evidence_path" "release evidence summary" "- Signed runtime evidence: signed-runtime-evidence"
  require_text "$evidence_path" "release evidence summary" "- Signed runtime evidence checksum file: signed-runtime-evidence/signed-runtime-evidence.sha256"
  require_text "$evidence_path" "release evidence summary" "- Signed runtime evidence checksum SHA-256: $runtime_checksum_hash"
fi
require_text "$evidence_path" "release evidence summary" "scripts/check-signed-beta-readiness.sh /Applications/Fermo.app"

printf 'Beta release evidence archive gate passed\n'
