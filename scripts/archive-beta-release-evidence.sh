#!/bin/sh

set -eu

usage() {
  printf 'usage: %s /Applications/Fermo.app /path/to/beta-manifest.md /path/to/completed-runtime-matrix.md /path/to/toolary-catalog-metadata.json /path/to/evidence-dir [/path/to/notarytool.log] [/path/to/signed-runtime-evidence-dir]\n' "$0"
  printf '\n'
  printf 'Runs the final signed beta readiness gate and writes an audit bundle with\n'
  printf 'the manifest, completed matrix, Toolary metadata, checksum file, optional\n'
  printf 'notarytool log, optional signed runtime evidence, and a release-evidence.md\n'
  printf 'summary. The ZIP artifact remains at the manifest path.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 5 ] || [ "$#" -gt 7 ]; then
  usage >&2
  exit 64
fi

app_path="$1"
manifest_path="$2"
matrix_path="$3"
metadata_path="$4"
evidence_dir="$5"
notary_log_path="${6:-}"
runtime_evidence_dir="${7:-}"

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

require_empty_output_dir() {
  path="$1"

  if [ -L "$path" ]; then
    fail "beta release evidence output path must not be a symlink: $path"
  fi

  if [ -e "$path" ] && [ ! -d "$path" ]; then
    fail "beta release evidence output path exists and is not a directory at $path"
  fi

  if [ -d "$path" ] && [ -n "$(find "$path" -mindepth 1 -print -quit)" ]; then
    fail "beta release evidence output directory must be empty: $path"
  fi
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
    fail "beta release evidence output directory must not be the app bundle: $path"
  fi

  case "$path" in
    "$app_dir"/*)
      fail "beta release evidence output directory must not be inside the app bundle: $path"
      ;;
  esac
}

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
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

case "${FERMO_SKIP_SIGNATURE_CHECKS:-0}" in
  0)
    ;;
  1)
    fail "beta release evidence archive cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1"
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '${FERMO_SKIP_SIGNATURE_CHECKS:-0}'"
    ;;
esac

if [ "$app_path" != "/Applications/Fermo.app" ]; then
  fail "beta release evidence archive must use /Applications/Fermo.app, got '$app_path'"
fi

require_output_dir_outside_app "$app_path" "$evidence_dir"

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
notary_request_id=""
notary_log_hash=""
runtime_checksum_hash=""

if [ -n "$notary_log_path" ]; then
  notary_request_id="$("$scripts_dir/check-notarytool-log.sh" --id-only "$notary_log_path")"
  notary_log_hash="$(shasum -a 256 "$notary_log_path" | awk '{print $1}')"
fi

if [ -n "$runtime_evidence_dir" ]; then
  runtime_checksum_hash="$(shasum -a 256 "$runtime_evidence_dir/signed-runtime-evidence.sha256" | awk '{print $1}')"
fi

if [ -z "$zip_path" ]; then
  fail "manifest does not include ZIP path"
fi

require_file "$zip_path" "ZIP artifact"
require_file "$zip_path.sha256" "checksum file"
require_empty_output_dir "$evidence_dir"

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

"$scripts_dir/check-signed-beta-readiness.sh" "$app_path" "$manifest_path" "$matrix_path" "$metadata_path" >/dev/null

mkdir -p "$evidence_dir"
cp "$manifest_path" "$evidence_dir/$manifest_basename"
cp "$matrix_path" "$evidence_dir/$matrix_basename"
cp "$metadata_path" "$evidence_dir/$metadata_basename"
cp "$zip_path.sha256" "$evidence_dir/$checksum_basename"

if [ -n "$notary_log_path" ]; then
  cp "$notary_log_path" "$evidence_dir/$notary_log_basename"
fi

if [ -n "$runtime_evidence_dir" ]; then
  cp -R "$runtime_evidence_dir" "$evidence_dir/signed-runtime-evidence"
fi

archive_created="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
evidence_path="$evidence_dir/release-evidence.md"

{
  printf '# Fermo Beta Release Evidence\n\n'
  printf -- '- Archived: %s\n' "$archive_created"
  printf -- '- Candidate created: %s\n' "$created"
  printf -- '- Channel: %s\n' "$channel"
  printf -- '- Version: %s\n' "$version"
  printf -- '- Build: %s\n' "$build"
  printf -- '- Git commit: %s\n' "$git_commit"
  printf -- '- Git tree: %s\n' "$git_tree"
  printf -- '- App path: %s\n' "$app_path"
  printf -- '- ZIP path: %s\n' "$zip_path"
  printf -- '- ZIP basename: %s\n' "$(basename "$zip_path")"
  printf -- '- SHA-256: %s\n' "$sha256"
  printf -- '- Manifest: %s\n' "$manifest_basename"
  printf -- '- Runtime matrix: %s\n' "$matrix_basename"
  printf -- '- Toolary metadata: %s\n' "$metadata_basename"
  printf -- '- Checksum file: %s\n' "$checksum_basename"
  if [ -n "$notary_log_path" ]; then
    printf -- '- Notarization request ID: %s\n' "$notary_request_id"
    printf -- '- Notary log: %s\n' "$notary_log_basename"
    printf -- '- Notary log SHA-256: %s\n' "$notary_log_hash"
  fi
  if [ -n "$runtime_evidence_dir" ]; then
    printf -- '- Signed runtime evidence: signed-runtime-evidence\n'
    printf -- '- Signed runtime evidence checksum file: signed-runtime-evidence/signed-runtime-evidence.sha256\n'
    printf -- '- Signed runtime evidence checksum SHA-256: %s\n' "$runtime_checksum_hash"
  fi
  printf '\n'
  printf '## Verification\n\n'
  printf 'The archive was created only after this command passed with signature checks enabled:\n\n'
  printf '```sh\n'
  printf 'scripts/check-signed-beta-readiness.sh /Applications/Fermo.app %s %s %s\n' "$manifest_path" "$matrix_path" "$metadata_path"
  printf '```\n\n'
  printf 'Keep this evidence directory with the ZIP artifact referenced above.\n'
} > "$evidence_path"

if [ -n "$runtime_evidence_dir" ]; then
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_dir" >/dev/null
elif [ -n "$notary_log_path" ]; then
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" >/dev/null
else
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_dir" "$manifest_path" "$matrix_path" "$metadata_path" >/dev/null
fi

printf 'Archived Fermo beta release evidence\n'
printf 'Evidence: %s\n' "$evidence_path"
printf 'ZIP: %s\n' "$zip_path"
printf 'SHA-256: %s\n' "$sha256"
if [ -n "$notary_log_path" ]; then
  printf 'Notarization request ID: %s\n' "$notary_request_id"
  printf 'Notary log: %s\n' "$notary_log_path"
fi
if [ -n "$runtime_evidence_dir" ]; then
  printf 'Signed runtime evidence: %s\n' "$runtime_evidence_dir"
fi
