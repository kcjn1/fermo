#!/bin/sh

set -eu

usage() {
  printf 'usage: %s\n' "$0"
  printf '\n'
  printf 'Audits that Toolary beta is still honestly blocked until the external\n'
  printf 'Apple/signing/runtime evidence exists. This is a guard against accidental\n'
  printf 'publication claims from local-only readiness checks.\n'
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
scripts_dir="$repo_root/scripts"
runbook_path="$repo_root/docs/toolary-beta-release-runbook.md"
matrix_path="$repo_root/docs/toolary-beta-runtime-matrix.md"
metadata_path="$repo_root/docs/toolary-catalog-metadata.json"
roadmap_path="$repo_root/docs/roadmap.md"

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
    fail "$label missing required blocker text: $expected"
  fi
}

reject_text() {
  path="$1"
  label="$2"
  rejected="$3"

  if grep -F -- "$rejected" "$path" >/dev/null; then
    fail "$label contains forbidden beta-ready claim: $rejected"
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

require_file "$runbook_path" "beta release runbook"
require_file "$matrix_path" "runtime matrix template"
require_file "$metadata_path" "Toolary metadata"
require_file "$roadmap_path" "roadmap"

if [ ! -x /usr/bin/ruby ]; then
  fail "ruby is required to validate Toolary metadata blocker status"
fi

"$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_path" >/dev/null
"$scripts_dir/check-beta-release-runbook.sh" "$runbook_path" >/dev/null
"$scripts_dir/check-runtime-matrix-template.sh" "$matrix_path" >/dev/null

metadata_status="$(json_value status)"
if [ "$metadata_status" != "comingSoon" ]; then
  fail "Toolary metadata must remain comingSoon until signed artifact gates pass, got '$metadata_status'"
fi

for expected in \
  "## Hard Blockers" \
  'Apple has granted `com.apple.developer.endpoint-security.client` for `com.toolary.fermo.appguard`' \
  "Fresh provisioning profiles include Endpoint Security and the shared app group" \
  'The candidate app is signed, notarized, and installed exactly at `/Applications/Fermo.app`' \
  "macOS approvals are complete for Network Extension, Endpoint Security App Guard, and Login Item" \
  '`docs/toolary-beta-runtime-matrix.md` has passed on the signed, notarized app' \
  'Toolary metadata remains `comingSoon` until the artifact gates pass' \
  'scripts/check-final-beta-publication-evidence.sh <evidence-dir> <manifest> <completed-runtime-matrix> docs/toolary-catalog-metadata.json <notary-output-dir>/Fermo-<Version>-<Build>-notarytool.log <signed-runtime-evidence-dir>'; do
  require_text "$runbook_path" "beta release runbook" "$expected"
done

for expected in \
  'A build is not beta-ready until every required row passes on a signed, notarized app installed in `/Applications`' \
  "| App notarization |" \
  "| Network Extension approval |" \
  "| Endpoint Security approval |" \
  "| Helper registration |" \
  "| Safari |" \
  "| Chrome |" \
  "| Firefox |" \
  "| Launch blocked app while session is active |" \
  "| Main app quit during active session |" \
  "| Reboot / login during active session |" \
  "| Install newer build over current build |"; do
  require_text "$matrix_path" "runtime matrix template" "$expected"
done

for expected in \
  "scripts/check-final-beta-publication-evidence.sh" \
  "scripts/export-final-beta-publication-packet.sh" \
  "scripts/check-final-beta-publication-packet.sh" \
  'Toolary metadata status `beta`'; do
  require_text "$matrix_path" "runtime matrix template" "$expected"
done

require_text \
  "$roadmap_path" \
  "roadmap" \
  "Remaining before beta: Apple Endpoint Security entitlement, signed/notarized \`/Applications/Fermo.app\`, macOS approvals, and the full signed lifecycle/browser/runtime matrix."

for claim in \
  "Toolary beta is ready" \
  "Toolary beta ready" \
  "public beta ready" \
  "metadata can be published now"; do
  reject_text "$runbook_path" "beta release runbook" "$claim"
  reject_text "$roadmap_path" "roadmap" "$claim"
done

printf 'Beta blocker audit passed\n'
printf 'Publication status: blocked\n'
printf 'Metadata: comingSoon\n'
printf 'Missing external evidence: Apple Endpoint Security entitlement/profiles, signed notarized /Applications/Fermo.app, macOS approvals, completed signed runtime matrix.\n'
