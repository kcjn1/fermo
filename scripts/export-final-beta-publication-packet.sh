#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /path/to/evidence-dir /path/to/beta-manifest.md /path/to/completed-runtime-matrix.md /path/to/toolary-catalog-metadata.json /path/to/notarytool.log /path/to/signed-runtime-evidence-dir /path/to/output-dir\n' "$0"
  printf '\n'
  printf 'Exports the final upload-ready beta publication packet after the final\n'
  printf 'publication evidence gate passes: ZIP, checksum, manifest, matrix,\n'
  printf 'metadata, release evidence, notary log, signed runtime evidence, and\n'
  printf 'a packet checksum manifest.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 7 ]; then
  usage >&2
  exit 64
fi

evidence_dir="$1"
manifest_path="$2"
matrix_path="$3"
metadata_path="$4"
notary_log_path="$5"
runtime_evidence_dir="$6"
output_dir="$7"

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

physical_containment_path() {
  path="$1"
  suffix=""

  while [ "$path" != "/" ] && [ "${path%/}" != "$path" ]; do
    path="${path%/}"
  done

  if [ -z "$path" ]; then
    printf '\n'
    return
  fi

  while [ ! -d "$path" ]; do
    base="$(basename -- "$path")"
    parent="$(dirname -- "$path")"

    if [ "$parent" = "$path" ]; then
      printf '%s\n' "$1"
      return
    fi

    if [ -z "$suffix" ]; then
      suffix="$base"
    else
      suffix="$base/$suffix"
    fi

    path="$parent"
  done

  path="$(CDPATH= cd -P -- "$path" && pwd -P)"
  if [ -n "$suffix" ]; then
    printf '%s/%s\n' "$path" "$suffix"
  else
    printf '%s\n' "$path"
  fi
}

require_output_dir_outside_app() {
  raw_app_dir="${1%/}"

  if [ -z "$raw_app_dir" ]; then
    return
  fi

  app_dir="$(physical_containment_path "$raw_app_dir")"
  path="$(physical_containment_path "$2")"

  if [ "$path" = "$app_dir" ]; then
    fail "publication packet output directory must not be the app bundle: $path"
  fi

  case "$path" in
    "$app_dir"/*)
      fail "publication packet output directory must not be inside the app bundle: $path"
      ;;
  esac
}

"$scripts_dir/check-final-beta-publication-evidence.sh" \
  "$evidence_dir" \
  "$manifest_path" \
  "$matrix_path" \
  "$metadata_path" \
  "$notary_log_path" \
  "$runtime_evidence_dir" >/dev/null

zip_path="$(manifest_value "ZIP path")"
sha256="$(manifest_value SHA-256)"
version="$(manifest_value Version)"
build="$(manifest_value Build)"
channel="$(manifest_value Channel)"
created="$(manifest_value Created)"
app_path="$(manifest_value "App path")"

require_output_dir_outside_app "$app_path" "$output_dir"

if [ -z "$zip_path" ]; then
  fail "manifest does not include ZIP path"
fi

require_file "$zip_path" "ZIP artifact"
require_file "$zip_path.sha256" "checksum file"
require_file "$evidence_dir/release-evidence.md" "release evidence summary"

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

if [ -L "$output_dir" ]; then
  fail "publication packet output path must not be a symlink: $output_dir"
fi

if [ -e "$output_dir" ] && [ ! -d "$output_dir" ]; then
  fail "publication packet output path exists and is not a directory at $output_dir"
fi

mkdir -p "$output_dir"
if find "$output_dir" -mindepth 1 -print -quit | grep . >/dev/null; then
  fail "publication packet output directory must be empty: $output_dir"
fi

cp "$zip_path" "$output_dir/$zip_basename"
cp "$zip_path.sha256" "$output_dir/$checksum_basename"
cp "$manifest_path" "$output_dir/$manifest_basename"
cp "$matrix_path" "$output_dir/$matrix_basename"
cp "$metadata_path" "$output_dir/$metadata_basename"
cp "$evidence_dir/release-evidence.md" "$output_dir/release-evidence.md"
cp "$notary_log_path" "$output_dir/$notary_log_basename"
rm -rf "$output_dir/signed-runtime-evidence"
cp -R "$runtime_evidence_dir" "$output_dir/signed-runtime-evidence"

packet_created="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
packet_path="$output_dir/PUBLICATION_PACKET.md"
checksum_manifest_path="$output_dir/publication-packet.sha256"

{
  printf '# Fermo Beta Publication Packet\n\n'
  printf -- '- Created: %s\n' "$packet_created"
  printf -- '- Candidate created: %s\n' "$created"
  printf -- '- Channel: %s\n' "$channel"
  printf -- '- Version: %s\n' "$version"
  printf -- '- Build: %s\n' "$build"
  printf -- '- ZIP: %s\n' "$zip_basename"
  printf -- '- SHA-256: %s\n' "$sha256"
  printf -- '- Manifest: %s\n' "$manifest_basename"
  printf -- '- Runtime matrix: %s\n' "$matrix_basename"
  printf -- '- Toolary metadata: %s\n' "$metadata_basename"
  printf -- '- Release evidence: release-evidence.md\n'
  printf -- '- Notary log: %s\n' "$notary_log_basename"
  printf -- '- Signed runtime evidence: signed-runtime-evidence\n'
  printf -- '- Packet checksum manifest: publication-packet.sha256\n\n'
  printf '## Verification\n\n'
  printf 'This packet was exported only after the final publication evidence gate passed:\n\n'
  printf '```sh\n'
  printf 'scripts/check-final-beta-publication-evidence.sh %s %s %s %s %s %s\n' "$evidence_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_dir"
  printf '```\n'
} > "$packet_path"

(
  cd "$output_dir"
  find . -type f ! -name "$(basename "$checksum_manifest_path")" | LC_ALL=C sort | while IFS= read -r path; do
    rel_path="${path#./}"
    shasum -a 256 "$rel_path"
  done
) > "$checksum_manifest_path"

"$scripts_dir/check-final-beta-publication-packet.sh" \
  "$output_dir" \
  "$evidence_dir" \
  "$manifest_path" \
  "$matrix_path" \
  "$metadata_path" \
  "$notary_log_path" \
  "$runtime_evidence_dir" >/dev/null

printf 'Exported final Fermo beta publication packet\n'
printf 'Packet: %s\n' "$packet_path"
printf 'Checksum manifest: %s\n' "$checksum_manifest_path"
printf 'Output: %s\n' "$output_dir"
