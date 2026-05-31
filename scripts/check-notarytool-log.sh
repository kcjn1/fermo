#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [--id-only] /path/to/notarytool.log\n' "$0"
  printf '\n'
  printf 'Validates that a notarytool submit log contains an Accepted status and\n'
  printf 'a UUID notarization request ID. Supports notarytool text and JSON output.\n'
}

id_only=0

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--id-only" ]; then
  id_only=1
  shift
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

log_path="$1"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

if [ ! -s "$log_path" ]; then
  fail "notarytool log missing or empty at $log_path"
fi

uuid_pattern='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

# `notarytool submit --wait` streams progress lines like "Current status: In Progress"
# before the final summary "  status: Accepted". Never match the unanchored "status:"
# substring (it catches "Current status:"), and take the LAST anchored summary line so the
# final state wins. JSON output, when present, is authoritative.
status="$(
  awk '
    match($0, /"status"[[:space:]]*:[[:space:]]*"[^"]+"/) {
      value = substr($0, RSTART, RLENGTH)
      sub(/^.*"status"[[:space:]]*:[[:space:]]*"/, "", value)
      sub(/".*$/, "", value)
      json = value
    }
    match($0, /^[[:space:]]*status:[[:space:]]*[^[:space:]]+/) {
      value = substr($0, RSTART, RLENGTH)
      sub(/^[[:space:]]*status:[[:space:]]*/, "", value)
      anchored = value
    }
    END {
      if (json != "") print json
      else if (anchored != "") print anchored
    }
  ' "$log_path"
)"

if [ "$status" != "Accepted" ]; then
  fail "notarytool log status must be Accepted, got '${status:-missing}'"
fi

request_id="$(
  {
    grep -Eo "\"id\"[[:space:]]*:[[:space:]]*\"$uuid_pattern\"" "$log_path" || true
    grep -Eo "(^|[[:space:]])id:[[:space:]]*$uuid_pattern" "$log_path" || true
  } | grep -Eo "$uuid_pattern" | head -n 1
)"

if [ -z "$request_id" ]; then
  fail "notarytool log is missing a UUID notarization request ID"
fi

if [ "$id_only" = "1" ]; then
  printf '%s\n' "$request_id"
  exit 0
fi

printf 'Notarytool log gate passed\n'
printf 'Notarization request ID: %s\n' "$request_id"
printf 'Status: %s\n' "$status"
