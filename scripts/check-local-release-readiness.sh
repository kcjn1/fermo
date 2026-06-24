#!/bin/sh

set -eu

usage() {
  printf 'usage: %s [/path/to/Fermo.app]\n' "$0"
  printf '\n'
  printf 'Runs local dogfood/dev readiness checks: script syntax, release copy,\n'
  printf 'Endpoint Security request and export packet, beta runbook, runtime matrix template, app copy guardrails, release guardrails, source entitlements, Toolary metadata,\n'
  printf 'Swift tests, Swift build, unsigned Xcode build,\n'
  printf 'unsigned candidate preflight, and dogfood/dev package flow.\n'
  printf '\n'
  printf 'Environment:\n'
  printf '  FERMO_DERIVED_DATA_PATH  DerivedData path for xcodebuild; defaults to /tmp/FermoPlanDerivedData\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 64
fi

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"
derived_data_path="${FERMO_DERIVED_DATA_PATH:-/tmp/FermoPlanDerivedData}"
app_path="${1:-$derived_data_path/Build/Products/Debug/Fermo.app}"

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

printf 'Fermo local release readiness\n'
printf 'Repo: %s\n' "$repo_root"
printf 'DerivedData: %s\n' "$derived_data_path"
printf 'Candidate app: %s\n' "$app_path"

printf '\n==> sh -n scripts/*.sh\n'
for script_path in "$scripts_dir"/*.sh; do
  sh -n "$script_path"
done

cd "$repo_root"

run "$scripts_dir/check-toolary-metadata-gate.sh" "$repo_root/docs/toolary-catalog-metadata.json"
run "$scripts_dir/check-release-copy.sh"
run "$scripts_dir/check-endpoint-security-request.sh"
run "$scripts_dir/check-endpoint-security-request-packet.sh"
run "$scripts_dir/check-beta-release-runbook.sh"
run "$scripts_dir/check-runtime-matrix-template.sh"
run "$scripts_dir/check-beta-blocker-audit.sh"
run "$scripts_dir/check-signed-beta-operator-packet.sh"
run "$scripts_dir/check-app-copy-guardrails.sh"
run "$scripts_dir/check-release-guardrails.sh"
run "$scripts_dir/check-xcode-entitlements.sh"
run swift test
run swift build
run xcodebuild \
  -project "$repo_root/Fermo.xcodeproj" \
  -scheme Fermo \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO \
  build

printf '\n==> FERMO_SKIP_SIGNATURE_CHECKS=1 %s %s\n' "$scripts_dir/verify-beta-candidate.sh" "$app_path"
FERMO_SKIP_SIGNATURE_CHECKS=1 "$scripts_dir/verify-beta-candidate.sh" "$app_path"

run "$scripts_dir/check-dogfood-package-flow.sh" "$app_path"

printf '\nLocal release readiness checks passed\n'
