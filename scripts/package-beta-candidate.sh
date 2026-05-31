#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  printf 'usage: %s /path/to/Fermo.app /path/to/output-dir\n' "$0" >&2
  exit 64
fi

app_path="$1"
output_dir="$2"
skip_signature_checks="${FERMO_SKIP_SIGNATURE_CHECKS:-0}"
release_channel="${FERMO_RELEASE_CHANNEL:-dogfood-dev}"
runtime_matrix_status="${FERMO_RUNTIME_MATRIX_STATUS:-pending}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_empty_output_dir() {
  path="$1"

  if [ -L "$path" ]; then
    fail "candidate output path must not be a symlink: $path"
  fi

  if [ -e "$path" ] && [ ! -d "$path" ]; then
    fail "candidate output path exists and is not a directory at $path"
  fi

  if [ -d "$path" ] && [ -n "$(find "$path" -mindepth 1 -print -quit)" ]; then
    fail "candidate output directory must be empty: $path"
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
    fail "candidate output directory must not be the app bundle: $path"
  fi

  case "$path" in
    "$app_dir"/*)
      fail "candidate output directory must not be inside the app bundle: $path"
      ;;
  esac
}

read_plist_value() {
  key="$1"
  plist_path="$app_path/Contents/Info.plist"

  if [ -x /usr/libexec/PlistBuddy ] && [ -f "$plist_path" ]; then
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
  fi
}

sanitize() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-'
}

require_numeric_dotted_value() {
  value="$1"
  label="$2"

  if ! printf '%s\n' "$value" | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$'; then
    fail "beta channel $label must be numeric dot-separated, got '$value'"
  fi
}

is_git_sha() {
  printf '%s\n' "$1" | grep -Eq '^[0-9a-fA-F]{7,40}$'
}

case "$release_channel" in
  dogfood-dev|beta)
    ;;
  *)
    fail "FERMO_RELEASE_CHANNEL must be dogfood-dev or beta, got '$release_channel'"
    ;;
esac

case "$runtime_matrix_status" in
  pending|passed)
    ;;
  *)
    fail "FERMO_RUNTIME_MATRIX_STATUS must be pending or passed, got '$runtime_matrix_status'"
    ;;
esac

case "$skip_signature_checks" in
  0|1)
    ;;
  *)
    fail "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got '$skip_signature_checks'"
    ;;
esac

if [ "$release_channel" = "beta" ]; then
  if [ "$skip_signature_checks" = "1" ]; then
    fail "beta channel cannot be packaged with FERMO_SKIP_SIGNATURE_CHECKS=1"
  fi

  if [ "$runtime_matrix_status" != "passed" ]; then
    fail "beta channel requires FERMO_RUNTIME_MATRIX_STATUS=passed"
  fi

  if [ "$app_path" != "/Applications/Fermo.app" ]; then
    fail "beta channel must package /Applications/Fermo.app, got '$app_path'"
  fi
fi

version="${FERMO_RELEASE_VERSION:-$(read_plist_value CFBundleShortVersionString)}"
build="${FERMO_RELEASE_BUILD:-$(read_plist_value CFBundleVersion)}"

if [ "$release_channel" = "beta" ]; then
  if [ -z "$version" ]; then
    fail "beta channel requires FERMO_RELEASE_VERSION or app CFBundleShortVersionString"
  fi

  if [ -z "$build" ]; then
    fail "beta channel requires FERMO_RELEASE_BUILD or app CFBundleVersion"
  fi

  if [ "$version" = "0.0.0" ]; then
    fail "beta channel cannot use placeholder version 0.0.0"
  fi

  if [ "$build" = "0" ]; then
    fail "beta channel cannot use placeholder build 0"
  fi

  require_numeric_dotted_value "$version" "Version"
  require_numeric_dotted_value "$build" "Build"
fi

if [ -z "$version" ]; then
  version="0.0.0"
fi

if [ -z "$build" ]; then
  build="0"
fi

git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
if [ "$release_channel" = "beta" ] && ! is_git_sha "$git_commit"; then
  fail "beta channel requires git commit SHA, got '$git_commit'"
fi

if git_status_output="$(git status --porcelain 2>/dev/null)"; then
  if [ -z "$git_status_output" ]; then
    git_tree="clean"
  else
    git_tree="dirty"
  fi
else
  git_tree="unknown"
fi

if [ "$release_channel" = "beta" ] && [ "$git_tree" != "clean" ]; then
  fail "beta channel requires clean git tree, got '$git_tree'"
fi

require_output_dir_outside_app "$app_path" "$output_dir"
require_empty_output_dir "$output_dir"

scripts_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
FERMO_SKIP_SIGNATURE_CHECKS="$skip_signature_checks" "$scripts_dir/verify-beta-candidate.sh" "$app_path"

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
artifact_stem="Fermo-$(sanitize "$version")-$(sanitize "$build")-$(sanitize "$release_channel")"
zip_path="$output_dir/$artifact_stem.zip"
checksum_path="$zip_path.sha256"
manifest_path="$output_dir/$artifact_stem-manifest.md"

mkdir -p "$output_dir"

ditto -c -k --keepParent "$app_path" "$zip_path"
sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
printf '%s  %s\n' "$sha256" "$(basename "$zip_path")" > "$checksum_path"

publishable="no"
if [ "$release_channel" = "beta" ] && [ "$runtime_matrix_status" = "passed" ]; then
  publishable="yes"
fi

{
  printf '# Fermo Beta Candidate Manifest\n\n'
  printf -- '- Created: %s\n' "$timestamp"
  printf -- '- Channel: %s\n' "$release_channel"
  printf -- '- Version: %s\n' "$version"
  printf -- '- Build: %s\n' "$build"
  printf -- '- Git commit: %s\n' "$git_commit"
  printf -- '- Git tree: %s\n' "$git_tree"
  printf -- '- App path: %s\n' "$app_path"
  printf -- '- ZIP path: %s\n' "$zip_path"
  printf -- '- SHA-256: %s\n' "$sha256"
  printf -- '- Runtime matrix: %s\n' "$runtime_matrix_status"
  printf -- '- Toolary publishable: %s\n\n' "$publishable"
  printf '## Gate Notes\n\n'
  if [ "$publishable" = "yes" ]; then
    printf 'This manifest is eligible for Toolary beta metadata only if the completed runtime matrix is stored with the artifact.\n'
  else
    printf 'Keep Toolary metadata at `comingSoon`. This artifact is for dogfood/dev validation until signing, notarization, approvals, checksum, and the runtime matrix all pass.\n'
  fi
} > "$manifest_path"

printf 'Packaged Fermo candidate\n'
printf 'ZIP: %s\n' "$zip_path"
printf 'SHA-256: %s\n' "$sha256"
printf 'Checksum file: %s\n' "$checksum_path"
printf 'Manifest: %s\n' "$manifest_path"
