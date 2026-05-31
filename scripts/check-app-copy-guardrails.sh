#!/bin/sh

set -eu

usage() {
  printf 'usage: %s\n' "$0"
  printf '\n'
  printf 'Validates in-app copy does not overclaim beta readiness or signed runtime proof.\n'
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
app_sources_dir="$repo_root/Sources/FermoApp"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

reject_text() {
  label="$1"
  needle="$2"

  if grep -RInF -- "$needle" "$app_sources_dir" >/tmp/fermo-app-copy-guardrail.out; then
    cat /tmp/fermo-app-copy-guardrail.out >&2
    fail "in-app copy contains stale or overstrong claim: $label"
  fi
}

require_text() {
  label="$1"
  needle="$2"

  if ! grep -RIF -- "$needle" "$app_sources_dir" >/dev/null; then
    fail "in-app copy missing required beta caveat: $label"
  fi
}

reject_text "signed proof exists locally" "Signed proof exists locally"
reject_text "local signed proof passed" "Local signed proof passed"
reject_text "local signed spike proof passed" "Local signed spike proof passed"
reject_text "current local signed spike claim" "current local signed spike"
reject_text "main-app quit proof passed locally" "Main-app quit proof passed locally"
reject_text "specific activated local build claim" "Build 0.1.0/3 activated locally"
reject_text "start website spike action" "Start Website Spike"
reject_text "start app spike action" "Start App Spike"
reject_text "start helper spike action" "Start Helper Spike"
reject_text "stop spike action" "Stop Spike"
reject_text "website spike copy" "Website spike"
reject_text "website spike title copy" "Website Spike"
reject_text "app spike copy" "App spike"
reject_text "app spike title copy" "App Spike"
reject_text "helper spike copy" "Helper spike"
reject_text "helper spike title copy" "Helper Spike"
reject_text "restart spike instruction" "start the spike again"
reject_text "beta-ready claim" "beta-ready"
reject_text "Toolary beta ready claim" "Toolary beta ready"
reject_text "ready for Toolary beta claim" "ready for Toolary beta"

require_text "Endpoint Security beta gate" "Endpoint Security approval"
require_text "signed runtime matrix caveat" "signed runtime matrix"
require_text "signed/notarized candidate caveat" "signed/notarized candidate"
require_text "Content Filter diagnostics field" "contentFilterSnapshotState"
require_text "App Guard diagnostics field" "appGuardSnapshotState"
require_text "copyable diagnostics action" "Copy Diagnostics"

printf 'App copy guardrails passed\n'
