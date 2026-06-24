#!/bin/sh

set -eu

if [ "$#" -ne 3 ]; then
  printf 'usage: %s /path/to/manifest.md /path/to/runtime-matrix-template.md /path/to/output.md\n' "$0" >&2
  exit 64
fi

manifest_path="$1"
template_path="$2"
output_path="$3"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

is_utc_timestamp() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

manifest_value() {
  key="$1"
  awk -F': ' -v key="- $key" '$1 == key { print substr($0, length($1) + 3); exit }' "$manifest_path"
}

require_file() {
  path="$1"
  label="$2"

  if [ ! -s "$path" ]; then
    fail "$label missing or empty at $path"
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

require_output_path_outside_app() {
  raw_app_dir="${1%/}"

  if [ -z "$raw_app_dir" ]; then
    return
  fi

  app_dir="$(physical_containment_path "$raw_app_dir")"
  path="$(physical_containment_path "$2")"

  if [ "$path" = "$app_dir" ]; then
    fail "runtime matrix output path must not be the app bundle: $path"
  fi

  case "$path" in
    "$app_dir"/*)
      fail "runtime matrix output path must not be inside the app bundle: $path"
      ;;
  esac
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

require_file "$manifest_path" "manifest"
require_file "$template_path" "runtime matrix template"

created="$(manifest_value Created)"
channel="$(manifest_value Channel)"
version="$(manifest_value Version)"
build="$(manifest_value Build)"
git_commit="$(manifest_value "Git commit")"
git_tree="$(manifest_value "Git tree")"
app_path="$(manifest_value "App path")"
zip_path="$(manifest_value "ZIP path")"
sha256="$(manifest_value SHA-256)"
publishable="$(manifest_value "Toolary publishable")"

if [ -z "$created" ]; then
  fail "manifest must include Created"
fi

if ! is_utc_timestamp "$created"; then
  fail "manifest Created must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ, got '$created'"
fi

if [ -z "$channel" ]; then
  fail "manifest must include Channel"
fi

if [ -z "$version" ]; then
  fail "manifest must include Version"
fi

if [ -z "$build" ]; then
  fail "manifest must include Build"
fi

if [ -z "$git_commit" ]; then
  fail "manifest must include Git commit"
fi

if [ -z "$git_tree" ]; then
  fail "manifest must include Git tree"
fi

if [ -z "$app_path" ]; then
  fail "manifest must include App path"
fi

if [ -z "$zip_path" ]; then
  fail "manifest must include ZIP path"
fi

if [ -z "$sha256" ]; then
  fail "manifest must include SHA-256"
fi

if [ -z "$publishable" ]; then
  fail "manifest must include Toolary publishable"
fi

require_file "$zip_path" "ZIP artifact"
checksum_path="$zip_path.sha256"
require_file "$checksum_path" "checksum file"

require_output_path_outside_app "$app_path" "$output_path"

if [ -e "$output_path" ] || [ -L "$output_path" ]; then
  fail "runtime matrix output already exists at $output_path"
fi

computed_sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
expected_zip_basename="$(basename "$zip_path")"
read_checksum_entry "$checksum_path" "$expected_zip_basename"

if [ "$sha256" != "$computed_sha256" ]; then
  fail "manifest SHA-256 does not match ZIP artifact"
fi

if [ "$checksum_sha256" != "$computed_sha256" ]; then
  fail "checksum file does not match ZIP artifact"
fi

signing_identity="${FERMO_SIGNING_IDENTITY:-}"
team_id="${FERMO_TEAM_ID:-}"
notarization_request_id="${FERMO_NOTARIZATION_REQUEST_ID:-}"
tester_mac="${FERMO_TESTER_MAC:-$(hostname 2>/dev/null || true)}"
macos_version="${FERMO_MACOS_VERSION:-$(sw_vers -productVersion 2>/dev/null || true)}"

tmp_path="$output_path.tmp"
mkdir -p "$(dirname "$output_path")"

awk \
  -v created="$created" \
  -v channel="$channel" \
  -v version="$version" \
  -v build="$build" \
  -v git_commit="$git_commit" \
  -v git_tree="$git_tree" \
  -v app_path="$app_path" \
  -v signing_identity="$signing_identity" \
  -v team_id="$team_id" \
  -v notarization_request_id="$notarization_request_id" \
  -v zip_path="$zip_path" \
  -v sha256="$sha256" \
  -v publishable="$publishable" \
  -v tester_mac="$tester_mac" \
  -v macos_version="$macos_version" '
    /^- Date:/ { print "- Date: " created; next }
    /^- Channel:/ { print "- Channel: " channel; next }
    /^- Version:/ { print "- Version: " version; next }
    /^- Build:/ { print "- Build: " build; next }
    /^- Git commit:/ { print "- Git commit: " git_commit; next }
    /^- Git tree:/ { print "- Git tree: " git_tree; next }
    /^- App path:/ { print "- App path: " app_path; next }
    /^- Signing identity:/ { print "- Signing identity: " signing_identity; next }
    /^- Team ID:/ { print "- Team ID: " team_id; next }
    /^- Notarization request ID:/ { print "- Notarization request ID: " notarization_request_id; next }
    /^- ZIP path:/ { print "- ZIP path: " zip_path; next }
    /^- SHA-256:/ { print "- SHA-256: " sha256; next }
    /^- Toolary publishable:/ { print "- Toolary publishable: " publishable; next }
    /^- Tester Mac:/ { print "- Tester Mac: " tester_mac; next }
    /^- macOS version:/ { print "- macOS version: " macos_version; next }
    { print }
  ' "$template_path" > "$tmp_path"

mv "$tmp_path" "$output_path"

printf 'Prepared runtime matrix\n'
printf 'Output: %s\n' "$output_path"
printf 'Version: %s\n' "$version"
printf 'Build: %s\n' "$build"
printf 'ZIP: %s\n' "$zip_path"
printf 'SHA-256: %s\n' "$sha256"
