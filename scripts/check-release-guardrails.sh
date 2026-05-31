#!/bin/sh

set -eu

usage() {
  printf 'usage: %s\n' "$0"
  printf '\n'
  printf 'Runs synthetic release guardrail checks for beta packaging, beta release gate,\n'
  printf 'and Toolary metadata publication rules.\n'
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
tmp_dir="$(mktemp -d /tmp/fermo-release-guardrails.XXXXXX)"
notary_request_id_fixture="12345678-1234-1234-1234-123456789abc"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

expect_failure() {
  label="$1"
  expected="$2"
  shift 2
  output_path="$tmp_dir/$label.out"

  if "$@" >"$output_path" 2>&1; then
    cat "$output_path" >&2
    fail "$label unexpectedly passed"
  fi

  if ! grep -F "$expected" "$output_path" >/dev/null; then
    cat "$output_path" >&2
    fail "$label did not fail with expected message: $expected"
  fi
}

expect_success() {
  label="$1"
  shift
  output_path="$tmp_dir/$label.out"

  if ! "$@" >"$output_path" 2>&1; then
    cat "$output_path" >&2
    fail "$label failed unexpectedly"
  fi
}

require_repo_text() {
  path="$1"
  label="$2"
  expected="$3"

  if ! grep -F -- "$expected" "$path" >/dev/null; then
    fail "$label missing required text: $expected"
  fi
}

expect_failure \
  endpoint-security-request-packet-rejects-extra-args \
  "usage:" \
  "$scripts_dir/check-endpoint-security-request-packet.sh" "$tmp_dir/one" "$tmp_dir/two"

expect_success \
  endpoint-security-request-packet-passes \
  "$scripts_dir/check-endpoint-security-request-packet.sh" "$tmp_dir/endpoint-security-packet"

expect_failure \
  signed-runtime-evidence-rejects-extra-args \
  "usage:" \
  "$scripts_dir/collect-signed-runtime-evidence.sh" /Applications/Fermo.app "$tmp_dir/runtime-evidence" "$tmp_dir/extra"

expect_failure \
  signed-runtime-evidence-rejects-non-applications-path \
  "signed runtime evidence collection must use /Applications/Fermo.app" \
  "$scripts_dir/collect-signed-runtime-evidence.sh" "$tmp_dir/Fermo.app" "$tmp_dir/runtime-evidence"

expect_failure \
  signed-runtime-evidence-rejects-skip-signature-checks \
  "signed runtime evidence collection cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/collect-signed-runtime-evidence.sh" /Applications/Fermo.app "$tmp_dir/runtime-evidence"

mkdir -p "$tmp_dir/nonempty-runtime-evidence"
printf 'stale\n' > "$tmp_dir/nonempty-runtime-evidence/stale.txt"
expect_failure \
  signed-runtime-evidence-rejects-nonempty-output-dir \
  "signed runtime evidence output directory must be empty" \
  "$scripts_dir/collect-signed-runtime-evidence.sh" /Applications/Fermo.app "$tmp_dir/nonempty-runtime-evidence"

mkdir -p "$tmp_dir/runtime-evidence-target"
ln -s "$tmp_dir/runtime-evidence-target" "$tmp_dir/runtime-evidence-symlink"
expect_failure \
  signed-runtime-evidence-rejects-output-symlink \
  "signed runtime evidence output path must not be a symlink" \
  "$scripts_dir/collect-signed-runtime-evidence.sh" /Applications/Fermo.app "$tmp_dir/runtime-evidence-symlink"

expect_failure \
  signed-runtime-evidence-rejects-output-inside-app-bundle \
  "signed runtime evidence output directory must not be inside the app bundle" \
  "$scripts_dir/collect-signed-runtime-evidence.sh" /Applications/Fermo.app /Applications/Fermo.app/runtime-evidence

expect_failure \
  signed-runtime-evidence-check-rejects-extra-args \
  "usage:" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$tmp_dir/runtime-evidence" "$tmp_dir/manifest" "$tmp_dir/extra"

write_beta_fixture() {
  matrix_status="$1"
  zip_path="$tmp_dir/Fermo-0.1.0-3-beta.zip"
  checksum_path="$zip_path.sha256"
  manifest_path="$tmp_dir/manifest.md"
  matrix_path="$tmp_dir/matrix-$matrix_status.md"

  printf 'artifact\n' > "$zip_path"
  sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
  printf '%s  %s\n' "$sha256" "$(basename "$zip_path")" > "$checksum_path"

  {
    printf '# Manifest\n'
    printf -- '- Created: 2026-05-25T07:00:00Z\n'
    printf -- '- Channel: beta\n'
    printf -- '- Version: 0.1.0\n'
    printf -- '- Build: 3\n'
    printf -- '- Git commit: abc1234\n'
    printf -- '- Git tree: clean\n'
    printf -- '- App path: /Applications/Fermo.app\n'
    printf -- '- Runtime matrix: passed\n'
    printf -- '- Toolary publishable: yes\n'
    printf -- '- ZIP path: %s\n' "$zip_path"
    printf -- '- SHA-256: %s\n' "$sha256"
  } > "$manifest_path"

  {
    printf '# Matrix\n'
    # Leading instructional prose legitimately mentions the marker word, exactly like the
    # real template (docs/toolary-beta-runtime-matrix.md). The gate must not trip on it.
    printf 'Set `FERMO_RUNTIME_MATRIX_STATUS=pending|passed` only after every row passes.\n'
    printf -- '- Date: 2026-05-25T07:00:00Z\n'
    printf -- '- Channel: beta\n'
    printf -- '- Version: 0.1.0\n'
    printf -- '- Build: 3\n'
    printf -- '- Git commit: abc1234\n'
    printf -- '- Git tree: clean\n'
    printf -- '- App path: /Applications/Fermo.app\n'
    printf -- '- Signing identity: Developer ID Application: Toolary Test\n'
    printf -- '- Team ID: TEAM123456\n'
    printf -- '- Notarization request ID: %s\n' "$notary_request_id_fixture"
    printf -- '- ZIP path: %s\n' "$zip_path"
    printf -- '- SHA-256: %s\n' "$sha256"
    printf -- '- Toolary publishable: yes\n'
    printf -- '- Tester Mac: ci-mac\n'
    printf -- '- macOS version: 15.5\n'
    printf '\n'
    printf '| Check | Required Result | Status |\n'
    printf '| --- | --- | --- |\n'
    printf '| Website blocking | fail closed while active | %s |\n' "$matrix_status"
    printf '| App Guard policy snapshot | `appGuardSnapshotState: ready` and protected apps listed | %s |\n' "$matrix_status"
    printf '| Content Filter rule snapshot | `contentFilterSnapshotState: ready` and domains listed | %s |\n' "$matrix_status"
    printf '| Diagnostics report | Includes filter snapshot and App Guard snapshot | %s |\n' "$matrix_status"
  } > "$matrix_path"
}

write_beta_metadata_fixture() {
  metadata_path="$tmp_dir/toolary-beta-metadata.json"

  /usr/bin/ruby -rjson -e '
    source_path = ARGV.fetch(0)
    output_path = ARGV.fetch(1)
    data = JSON.parse(File.read(source_path))
    data["status"] = "beta"
    File.write(output_path, JSON.pretty_generate(data))
  ' "$repo_root/docs/toolary-catalog-metadata.json" "$metadata_path"
}

write_app_manifest_fixture() {
  app_path="$tmp_dir/Fermo.app"
  manifest_path="$tmp_dir/app-manifest.md"

  mkdir -p "$app_path/Contents"
  cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>3</string>
</dict>
</plist>
PLIST

  {
    printf '# Manifest\n'
    printf -- '- App path: %s\n' "$app_path"
    printf -- '- Version: 0.1.0\n'
    printf -- '- Build: 3\n'
  } > "$manifest_path"
}

write_info_plist() {
  plist_path="$1"
  bundle_identifier="$2"
  package_type="$3"

  mkdir -p "$(dirname "$plist_path")"
  cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$bundle_identifier</string>
  <key>CFBundlePackageType</key>
  <string>$package_type</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>3</string>
</dict>
</plist>
PLIST
}

write_candidate_app_fixture() {
  candidate_app_path="$tmp_dir/Candidate.app"
  filter_extension_path="$candidate_app_path/Contents/Library/SystemExtensions/com.toolary.fermo.filter.systemextension"
  appguard_extension_path="$candidate_app_path/Contents/Library/SystemExtensions/com.toolary.fermo.appguard.systemextension"
  helper_app_path="$candidate_app_path/Contents/Library/LoginItems/FermoHelper.app"

  mkdir -p "$candidate_app_path/Contents/MacOS"
  printf '#!/bin/sh\nexit 0\n' > "$candidate_app_path/Contents/MacOS/Fermo"
  chmod +x "$candidate_app_path/Contents/MacOS/Fermo"

  write_info_plist "$candidate_app_path/Contents/Info.plist" "com.toolary.fermo" "APPL"
  write_info_plist "$filter_extension_path/Contents/Info.plist" "com.toolary.fermo.filter" "SYSX"
  write_info_plist "$appguard_extension_path/Contents/Info.plist" "com.toolary.fermo.appguard" "SYSX"
  write_info_plist "$helper_app_path/Contents/Info.plist" "com.toolary.fermo.helper" "APPL"
}

write_release_copy_fixture() {
  release_notes_fixture_path="$tmp_dir/release-notes.md"
  toolary_copy_fixture_path="$tmp_dir/toolary-beta-copy.md"
  metadata_fixture_path="$tmp_dir/toolary-copy-metadata.json"

  cp "$repo_root/docs/release-notes.md" "$release_notes_fixture_path"
  cp "$repo_root/docs/toolary-beta-copy.md" "$toolary_copy_fixture_path"
  cp "$repo_root/docs/toolary-catalog-metadata.json" "$metadata_fixture_path"
}

write_xcode_project_fixture() {
  xcode_project_fixture_path="$tmp_dir/project.pbxproj"
  cp "$repo_root/Fermo.xcodeproj/project.pbxproj" "$xcode_project_fixture_path"
}

write_failing_git_fixture() {
  failing_git_bin_dir="$tmp_dir/failing-git-bin"
  mkdir -p "$failing_git_bin_dir"
  cat > "$failing_git_bin_dir/git" <<'SH'
#!/bin/sh
exit 1
SH
  chmod +x "$failing_git_bin_dir/git"
}

write_dirty_git_fixture() {
  dirty_git_bin_dir="$tmp_dir/dirty-git-bin"
  mkdir -p "$dirty_git_bin_dir"
  cat > "$dirty_git_bin_dir/git" <<'SH'
#!/bin/sh
if [ "$1" = "rev-parse" ]; then
  printf 'abc1234\n'
  exit 0
fi

if [ "$1" = "status" ]; then
  printf ' M Sources/FermoApp/FermoApp.swift\n'
  exit 0
fi

exit 1
SH
  chmod +x "$dirty_git_bin_dir/git"
}

write_release_evidence_fixture() {
  evidence_fixture_dir="$tmp_dir/evidence-fixture"

  rm -rf "$evidence_fixture_dir"
  mkdir -p "$evidence_fixture_dir"
  cp "$manifest_path" "$evidence_fixture_dir/$(basename "$manifest_path")"
  cp "$matrix_path" "$evidence_fixture_dir/$(basename "$matrix_path")"
  cp "$metadata_path" "$evidence_fixture_dir/$(basename "$metadata_path")"
  cp "$checksum_path" "$evidence_fixture_dir/$(basename "$zip_path").sha256"

  {
    printf '# Fermo Beta Release Evidence\n\n'
    printf -- '- Archived: 2026-05-25T08:00:00Z\n'
    printf -- '- Candidate created: 2026-05-25T07:00:00Z\n'
    printf -- '- Channel: beta\n'
    printf -- '- Version: 0.1.0\n'
    printf -- '- Build: 3\n'
    printf -- '- Git commit: abc1234\n'
    printf -- '- Git tree: clean\n'
    printf -- '- App path: /Applications/Fermo.app\n'
    printf -- '- ZIP path: %s\n' "$zip_path"
    printf -- '- ZIP basename: %s\n' "$(basename "$zip_path")"
    printf -- '- SHA-256: %s\n' "$sha256"
    printf -- '- Manifest: %s\n' "$(basename "$manifest_path")"
    printf -- '- Runtime matrix: %s\n' "$(basename "$matrix_path")"
    printf -- '- Toolary metadata: %s\n' "$(basename "$metadata_path")"
    printf -- '- Checksum file: %s\n\n' "$(basename "$zip_path").sha256"
    printf '## Verification\n\n'
    printf '```sh\n'
    printf 'scripts/check-signed-beta-readiness.sh /Applications/Fermo.app %s %s %s\n' "$manifest_path" "$matrix_path" "$metadata_path"
    printf '```\n'
  } > "$evidence_fixture_dir/release-evidence.md"
}

write_signed_runtime_evidence_fixture() {
  runtime_evidence_fixture_dir="$tmp_dir/signed-runtime-evidence-source"

  rm -rf "$runtime_evidence_fixture_dir"
  mkdir -p "$runtime_evidence_fixture_dir"

  {
    printf '# Fermo Signed Runtime Evidence\n\n'
    printf -- '- Created: 2026-05-25T07:30:00Z\n'
    printf -- '- App path: /Applications/Fermo.app\n'
    printf -- '- Hostname: ci-mac\n'
    printf -- '- User ID: 501\n'
    printf -- '- Helper service: `gui/501/com.toolary.fermo.helper`\n'
    printf -- '- FermoHelper pids: 12345\n\n'
    printf '## Captured Files\n\n'
    printf -- '- `system.txt`: host, UID, uname, and macOS version.\n'
    printf -- '- `Fermo-Info.plist.txt`: installed app bundle metadata.\n'
    printf -- '- `verify-beta-candidate.txt`: signed candidate preflight output.\n'
    printf -- '- `spctl-assess.txt`: notarization/Gatekeeper assessment output.\n'
    printf -- '- `systemextensionsctl-list.txt`: raw system extension list.\n'
    printf -- '- `check-signed-runtime-approvals.txt`: Network Extension, App Guard, and helper approval gate output.\n'
    printf -- '- `check-signed-helper-runtime.txt`: Login Item helper gate output.\n'
    printf -- '- `launchctl-helper.txt`: raw Login Item launchctl service state.\n'
    printf -- '- `pgrep-helper.txt`: running FermoHelper process IDs.\n\n'
    printf -- '- `signed-runtime-evidence.sha256`: SHA-256 manifest for the captured evidence files.\n'
    printf '\n'
    printf '## Verification\n\n'
    printf 'This evidence directory was written only after the signed preflight, spctl assessment, signed runtime approvals, helper runtime, launchctl service, and FermoHelper process checks exited 0.\n'
  } > "$runtime_evidence_fixture_dir/signed-runtime-evidence.md"

  {
    printf 'created=2026-05-25T07:30:00Z\n'
    printf 'hostname=ci-mac\n'
    printf 'uid=501\n'
    printf 'uname=Darwin ci-mac 25.0.0\n'
  } > "$runtime_evidence_fixture_dir/system.txt"

  {
    printf '["CFBundleIdentifier"] => "com.toolary.fermo"\n'
    printf '["CFBundleShortVersionString"] => "0.1.0"\n'
    printf '["CFBundleVersion"] => "3"\n'
  } > "$runtime_evidence_fixture_dir/Fermo-Info.plist.txt"
  {
    printf 'Fermo beta candidate preflight\n'
    printf 'App: /Applications/Fermo.app\n'
    printf 'Preflight complete. Continue with macOS approval and runtime matrix checks.\n'
  } > "$runtime_evidence_fixture_dir/verify-beta-candidate.txt"
  printf '/Applications/Fermo.app: accepted\n' > "$runtime_evidence_fixture_dir/spctl-assess.txt"
  {
    printf '* ABCD com.toolary.fermo.filter [activated enabled]\n'
    printf '* ABCD com.toolary.fermo.appguard [activated enabled]\n'
  } > "$runtime_evidence_fixture_dir/systemextensionsctl-list.txt"
  printf 'Signed runtime approval checks passed\n' > "$runtime_evidence_fixture_dir/check-signed-runtime-approvals.txt"
  printf 'Signed helper runtime checks passed\n' > "$runtime_evidence_fixture_dir/check-signed-helper-runtime.txt"
  printf 'com.toolary.fermo.helper = {\n  state = running\n}\n' > "$runtime_evidence_fixture_dir/launchctl-helper.txt"
  printf '12345\n' > "$runtime_evidence_fixture_dir/pgrep-helper.txt"

  (
    cd "$runtime_evidence_fixture_dir"
    shasum -a 256 \
      signed-runtime-evidence.md \
      system.txt \
      Fermo-Info.plist.txt \
      verify-beta-candidate.txt \
      spctl-assess.txt \
      systemextensionsctl-list.txt \
      check-signed-runtime-approvals.txt \
      check-signed-helper-runtime.txt \
      launchctl-helper.txt \
      pgrep-helper.txt
  ) > "$runtime_evidence_fixture_dir/signed-runtime-evidence.sha256"
}

printf 'Fermo release guardrails\n'
printf 'Temp: %s\n' "$tmp_dir"

require_repo_text \
  "$repo_root/README.md" \
  "README local readiness expansion" \
  "scripts/check-toolary-metadata-gate.sh docs/toolary-catalog-metadata.json"

expect_failure \
  endpoint-security-request-export-rejects-missing-output-dir \
  'usage:' \
  "$scripts_dir/export-endpoint-security-request-packet.sh"

mkdir -p "$tmp_dir/nonempty-endpoint-security-request-packet"
printf 'stale\n' > "$tmp_dir/nonempty-endpoint-security-request-packet/stale.txt"
expect_failure \
  endpoint-security-request-export-rejects-nonempty-output-dir \
  "Endpoint Security request packet output directory must be empty" \
  "$scripts_dir/export-endpoint-security-request-packet.sh" "$tmp_dir/nonempty-endpoint-security-request-packet"

mkdir -p "$tmp_dir/endpoint-security-request-packet-target"
ln -s "$tmp_dir/endpoint-security-request-packet-target" "$tmp_dir/endpoint-security-request-packet-symlink"
expect_failure \
  endpoint-security-request-export-rejects-output-symlink \
  "Endpoint Security request packet output path must not be a symlink" \
  "$scripts_dir/export-endpoint-security-request-packet.sh" "$tmp_dir/endpoint-security-request-packet-symlink"

endpoint_packet_dir="$tmp_dir/endpoint-security-request-packet"
expect_success \
  endpoint-security-request-export-succeeds \
  "$scripts_dir/export-endpoint-security-request-packet.sh" "$endpoint_packet_dir"

for expected_packet_file in \
  "$endpoint_packet_dir/PACKET.md" \
  "$endpoint_packet_dir/apple-endpoint-security-entitlement-request.md" \
  "$endpoint_packet_dir/macos-endpoint-security-signing.md" \
  "$endpoint_packet_dir/FermoAppGuardExtension.entitlements" \
  "$endpoint_packet_dir/xcode-appguard-settings.txt"; do
  if [ ! -s "$expected_packet_file" ]; then
    fail "Endpoint Security request export missing expected file: $expected_packet_file"
  fi
done

for expected_packet_text in \
  'com.apple.developer.endpoint-security.client' \
  'com.toolary.fermo.appguard' \
  'com.toolary.fermo.appguard.systemextension' \
  'MP3AWS77U3.com.toolary.fermo' \
  'scripts/check-endpoint-security-request.sh'; do
  if ! grep -F -- "$expected_packet_text" "$endpoint_packet_dir/PACKET.md" >/dev/null; then
    fail "Endpoint Security request PACKET.md missing expected text: $expected_packet_text"
  fi
done

expect_failure \
  signed-beta-operator-packet-export-rejects-missing-output-dir \
  'usage:' \
  "$scripts_dir/export-signed-beta-operator-packet.sh"

mkdir -p "$tmp_dir/nonempty-signed-beta-operator-packet"
printf 'stale\n' > "$tmp_dir/nonempty-signed-beta-operator-packet/stale.txt"
expect_failure \
  signed-beta-operator-packet-export-rejects-nonempty-output-dir \
  "signed beta operator packet output directory must be empty" \
  "$scripts_dir/export-signed-beta-operator-packet.sh" "$tmp_dir/nonempty-signed-beta-operator-packet"

mkdir -p "$tmp_dir/signed-beta-operator-packet-target"
ln -s "$tmp_dir/signed-beta-operator-packet-target" "$tmp_dir/signed-beta-operator-packet-symlink"
expect_failure \
  signed-beta-operator-packet-export-rejects-output-symlink \
  "signed beta operator packet output path must not be a symlink" \
  "$scripts_dir/export-signed-beta-operator-packet.sh" "$tmp_dir/signed-beta-operator-packet-symlink"

operator_packet_dir="$tmp_dir/signed-beta-operator-packet"
expect_success \
  signed-beta-operator-packet-export-succeeds \
  "$scripts_dir/export-signed-beta-operator-packet.sh" "$operator_packet_dir"

expect_failure \
  signed-beta-operator-packet-check-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-signed-beta-operator-packet.sh" "$tmp_dir/operator-check" "$tmp_dir/extra"

expect_success \
  signed-beta-operator-packet-check-succeeds \
  "$scripts_dir/check-signed-beta-operator-packet.sh" "$tmp_dir/operator-check"

expect_failure \
  beta-blocker-audit-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-beta-blocker-audit.sh" "$tmp_dir/extra"

expect_success \
  beta-blocker-audit-passes \
  "$scripts_dir/check-beta-blocker-audit.sh"

write_signed_runtime_evidence_fixture
expect_success \
  signed-runtime-evidence-check-passes \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir"

runtime_manifest_fixture_path="$tmp_dir/signed-runtime-manifest.md"
{
  printf '# Manifest\n'
  printf -- '- App path: /Applications/Fermo.app\n'
  printf -- '- Version: 0.1.0\n'
  printf -- '- Build: 3\n'
} > "$runtime_manifest_fixture_path"

expect_success \
  signed-runtime-evidence-check-matches-manifest \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir" "$runtime_manifest_fixture_path"

awk 'NR == 1 { print; print; next } { print }' "$runtime_evidence_fixture_dir/signed-runtime-evidence.sha256" > "$tmp_dir/signed-runtime-evidence-duplicate-files.sha256"
mv "$tmp_dir/signed-runtime-evidence-duplicate-files.sha256" "$runtime_evidence_fixture_dir/signed-runtime-evidence.sha256"
expect_failure \
  signed-runtime-evidence-check-checksum-duplicate-files \
  "signed runtime evidence checksum manifest does not list exactly the captured files" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir"
write_signed_runtime_evidence_fixture

ln -s "$runtime_evidence_fixture_dir" "$tmp_dir/runtime-evidence-check-symlink"
expect_failure \
  signed-runtime-evidence-check-rejects-root-symlink \
  "signed runtime evidence directory must not be a symlink" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$tmp_dir/runtime-evidence-check-symlink"
rm "$tmp_dir/runtime-evidence-check-symlink"

printf 'stale\n' > "$runtime_evidence_fixture_dir/stale.txt"
expect_failure \
  signed-runtime-evidence-check-rejects-unexpected-file \
  "signed runtime evidence contains unexpected or missing files" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir"
write_signed_runtime_evidence_fixture

ln -s system.txt "$runtime_evidence_fixture_dir/stale-link"
expect_failure \
  signed-runtime-evidence-check-rejects-symlink \
  "signed runtime evidence contains unsupported non-file entries" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir"
write_signed_runtime_evidence_fixture

mkdir "$runtime_evidence_fixture_dir/stale-dir"
expect_failure \
  signed-runtime-evidence-check-rejects-unexpected-directory \
  "signed runtime evidence contains unexpected directories" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir"
write_signed_runtime_evidence_fixture

sed 's/- Version: 0.1.0/- Version: 0.2.0/' "$runtime_manifest_fixture_path" > "$tmp_dir/signed-runtime-manifest-version-mismatch.md"
expect_failure \
  signed-runtime-evidence-check-version-mismatch \
  "signed runtime evidence version '0.1.0' does not match manifest Version '0.2.0'" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir" "$tmp_dir/signed-runtime-manifest-version-mismatch.md"

printf '\ndrift\n' >> "$runtime_evidence_fixture_dir/system.txt"
expect_failure \
  signed-runtime-evidence-check-checksum-drift \
  "signed runtime evidence checksum manifest does not match captured files" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir"
write_signed_runtime_evidence_fixture

rm "$runtime_evidence_fixture_dir/spctl-assess.txt"
expect_failure \
  signed-runtime-evidence-check-rejects-missing-spctl-output \
  "signed runtime evidence contains unexpected or missing files" \
  "$scripts_dir/check-signed-runtime-evidence.sh" "$runtime_evidence_fixture_dir"
write_signed_runtime_evidence_fixture

for expected_operator_packet_file in \
  "$operator_packet_dir/PACKET.md" \
  "$operator_packet_dir/SIGNED_RELEASE_COMMANDS.md" \
  "$operator_packet_dir/toolary-beta-release-runbook.md" \
  "$operator_packet_dir/toolary-beta-runtime-matrix.md" \
  "$operator_packet_dir/release-notes.md" \
  "$operator_packet_dir/toolary-beta-copy.md" \
  "$operator_packet_dir/toolary-catalog-metadata.json"; do
  if [ ! -s "$expected_operator_packet_file" ]; then
    fail "signed beta operator packet missing expected file: $expected_operator_packet_file"
  fi
done

for expected_operator_text in \
  'scripts/check-local-release-readiness.sh' \
  'scripts/check-signed-build-environment.sh' \
  'scripts/install-signed-beta-app.sh "$FERMO_SIGNED_EXPORT_APP"' \
  'scripts/notarize-signed-beta-app.sh /Applications/Fermo.app "$FERMO_NOTARY_OUTPUT_DIR"' \
  'scripts/check-signed-runtime-approvals.sh /Applications/Fermo.app' \
  'scripts/check-signed-runtime-evidence.sh "$FERMO_RUNTIME_EVIDENCE_DIR" "$FERMO_RELEASE_OUTPUT_DIR"/Fermo-<Version>-<Build>-beta-manifest.md' \
  'FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed scripts/package-beta-candidate.sh /Applications/Fermo.app "$FERMO_RELEASE_OUTPUT_DIR"' \
  'FERMO_NOTARIZATION_REQUEST_ID="$(cat "$FERMO_NOTARY_OUTPUT_DIR"/Fermo-<Version>-<Build>-notary-request-id.txt)"' \
  'scripts/check-signed-beta-readiness.sh /Applications/Fermo.app' \
  'scripts/archive-beta-release-evidence.sh /Applications/Fermo.app'; do
  if ! grep -F -- "$expected_operator_text" "$operator_packet_dir/SIGNED_RELEASE_COMMANDS.md" >/dev/null; then
    fail "SIGNED_RELEASE_COMMANDS.md missing expected text: $expected_operator_text"
  fi
done

expect_failure \
  beta-package-rejects-extra-args \
  'usage:' \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Fermo.app" "$tmp_dir/out" "$tmp_dir/extra"

expect_failure \
  beta-package-rejects-unknown-channel \
  "FERMO_RELEASE_CHANNEL must be dogfood-dev or beta, got 'betta'" \
  env FERMO_RELEASE_CHANNEL=betta \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Missing.app" "$tmp_dir/out"

expect_failure \
  beta-package-rejects-unknown-runtime-matrix-status \
  "FERMO_RUNTIME_MATRIX_STATUS must be pending or passed, got 'passsed'" \
  env FERMO_RUNTIME_MATRIX_STATUS=passsed \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Missing.app" "$tmp_dir/out"

expect_failure \
  beta-package-rejects-unknown-skip-signature-flag \
  "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got 'true'" \
  env FERMO_SKIP_SIGNATURE_CHECKS=true \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Missing.app" "$tmp_dir/out"

mkdir -p "$tmp_dir/nonempty-candidate-output"
printf 'stale\n' > "$tmp_dir/nonempty-candidate-output/stale.txt"
expect_failure \
  beta-package-rejects-nonempty-output-dir \
  "candidate output directory must be empty" \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Missing.app" "$tmp_dir/nonempty-candidate-output"

mkdir -p "$tmp_dir/candidate-output-target"
ln -s "$tmp_dir/candidate-output-target" "$tmp_dir/candidate-output-symlink"
expect_failure \
  beta-package-rejects-output-symlink \
  "candidate output path must not be a symlink" \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Missing.app" "$tmp_dir/candidate-output-symlink"

write_candidate_app_fixture
expect_failure \
  beta-package-rejects-output-inside-app-bundle \
  "candidate output directory must not be inside the app bundle" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/package-beta-candidate.sh" "$candidate_app_path" "$candidate_app_path/release-output"

expect_failure \
  beta-package-rejects-physically-nested-output-inside-app-bundle \
  "candidate output directory must not be inside the app bundle" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/package-beta-candidate.sh" "$candidate_app_path" "$candidate_app_path/../Candidate.app/release-output"

ln -s "$candidate_app_path" "$tmp_dir/candidate-app-symlink"
expect_failure \
  beta-package-rejects-nested-output-under-symlinked-app-ancestor \
  "candidate output directory must not be inside the app bundle" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/package-beta-candidate.sh" "$candidate_app_path" "$tmp_dir/candidate-app-symlink/deep/release-output"

expect_failure \
  beta-package-skip-signature \
  'beta channel cannot be packaged with FERMO_SKIP_SIGNATURE_CHECKS=1' \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Missing.app" "$tmp_dir/out"

expect_failure \
  beta-package-pending-matrix \
  'beta channel requires FERMO_RUNTIME_MATRIX_STATUS=passed' \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=pending \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Missing.app" "$tmp_dir/out"

expect_failure \
  beta-package-missing-version \
  'beta channel requires FERMO_RELEASE_VERSION or app CFBundleShortVersionString' \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_BUILD=3 \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

expect_failure \
  beta-package-missing-build \
  'beta channel requires FERMO_RELEASE_BUILD or app CFBundleVersion' \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION=0.1.0 \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

expect_failure \
  beta-package-requires-installed-app-path \
  'beta channel must package /Applications/Fermo.app, got' \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION=0.1.0 FERMO_RELEASE_BUILD=3 \
  "$scripts_dir/package-beta-candidate.sh" "$tmp_dir/Fermo.app" "$tmp_dir/out"

expect_failure \
  beta-package-placeholder-version \
  'beta channel cannot use placeholder version 0.0.0' \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION=0.0.0 FERMO_RELEASE_BUILD=3 \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

expect_failure \
  beta-package-placeholder-build \
  'beta channel cannot use placeholder build 0' \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION=0.1.0 FERMO_RELEASE_BUILD=0 \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

expect_failure \
  beta-package-invalid-version-format \
  "beta channel Version must be numeric dot-separated, got '0.1 beta'" \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION="0.1 beta" FERMO_RELEASE_BUILD=3 \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

expect_failure \
  beta-package-invalid-build-format \
  "beta channel Build must be numeric dot-separated, got 'build-three'" \
  env FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION=0.1.0 FERMO_RELEASE_BUILD=build-three \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

write_failing_git_fixture
expect_failure \
  beta-package-requires-git-commit-sha \
  "beta channel requires git commit SHA, got 'unknown'" \
  env PATH="$failing_git_bin_dir:$PATH" FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION=0.1.0 FERMO_RELEASE_BUILD=3 \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

write_dirty_git_fixture
expect_failure \
  beta-package-requires-clean-git-tree \
  "beta channel requires clean git tree, got 'dirty'" \
  env PATH="$dirty_git_bin_dir:$PATH" FERMO_RELEASE_CHANNEL=beta FERMO_RUNTIME_MATRIX_STATUS=passed FERMO_RELEASE_VERSION=0.1.0 FERMO_RELEASE_BUILD=3 \
  "$scripts_dir/package-beta-candidate.sh" "/Applications/Fermo.app" "$tmp_dir/out"

write_beta_fixture "Passed"
write_beta_metadata_fixture
expect_failure \
  signed-readiness-rejects-skipped-signatures \
  "signed beta readiness cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/check-signed-beta-readiness.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path"

expect_failure \
  signed-readiness-rejects-unknown-skip-signature-flag \
  "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got 'true'" \
  env FERMO_SKIP_SIGNATURE_CHECKS=true \
  "$scripts_dir/check-signed-beta-readiness.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path"

expect_failure \
  signed-readiness-requires-installed-app-path \
  "signed beta readiness must use /Applications/Fermo.app, got" \
  "$scripts_dir/check-signed-beta-readiness.sh" "$tmp_dir/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path"

expect_failure \
  signed-readiness-runs-release-copy-gate \
  "Toolary beta copy missing or empty" \
  env FERMO_TOOLARY_COPY_PATH="$tmp_dir/missing-toolary-copy.md" \
  "$scripts_dir/check-signed-beta-readiness.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path"

expect_failure \
  signed-beta-install-rejects-extra-args \
  'usage:' \
  "$scripts_dir/install-signed-beta-app.sh" "$tmp_dir/Fermo.app" "$tmp_dir/extra"

expect_failure \
  signed-beta-install-rejects-skipped-signatures \
  "signed beta install cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/install-signed-beta-app.sh" "$tmp_dir/Fermo.app"

expect_failure \
  signed-beta-install-rejects-unknown-replace-flag \
  "FERMO_REPLACE_APPLICATIONS_APP must be 0 or 1, got 'true'" \
  env FERMO_REPLACE_APPLICATIONS_APP=true \
  "$scripts_dir/install-signed-beta-app.sh" "$tmp_dir/Fermo.app"

expect_failure \
  signed-beta-install-rejects-installed-app-source \
  "source app is already /Applications/Fermo.app" \
  "$scripts_dir/install-signed-beta-app.sh" "/Applications/Fermo.app"

expect_failure \
  signed-beta-install-rejects-source-inside-installed-app \
  "signed Fermo.app source must not be inside /Applications/Fermo.app" \
  "$scripts_dir/install-signed-beta-app.sh" "/Applications/Fermo.app/Nested/Fermo.app"

mkdir -p "$tmp_dir/DerivedData/Build/Products/Release/Fermo.app"
expect_failure \
  signed-beta-install-rejects-derived-data-source \
  "signed beta install refuses DerivedData or Build Products source paths" \
  "$scripts_dir/install-signed-beta-app.sh" "$tmp_dir/DerivedData/Build/Products/Release/Fermo.app"

mkdir -p "$tmp_dir/signed-export/Fermo.app"
ln -s "$tmp_dir/signed-export/Fermo.app" "$tmp_dir/symlink-source-Fermo.app"
expect_failure \
  signed-beta-install-rejects-source-symlink \
  "signed Fermo.app source must not be a symlink" \
  "$scripts_dir/install-signed-beta-app.sh" "$tmp_dir/symlink-source-Fermo.app"

expect_failure \
  notarize-signed-app-rejects-extra-args \
  'usage:' \
  "$scripts_dir/notarize-signed-beta-app.sh" "/Applications/Fermo.app" "$tmp_dir/notary" "$tmp_dir/extra"

expect_failure \
  notarize-signed-app-rejects-skipped-signatures \
  "notarization cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 FERMO_NOTARYTOOL_PROFILE=test-profile \
  "$scripts_dir/notarize-signed-beta-app.sh" "/Applications/Fermo.app" "$tmp_dir/notary"

expect_failure \
  notarize-signed-app-requires-installed-app-path \
  "notarization must use /Applications/Fermo.app, got" \
  env FERMO_NOTARYTOOL_PROFILE=test-profile \
  "$scripts_dir/notarize-signed-beta-app.sh" "$tmp_dir/Fermo.app" "$tmp_dir/notary"

expect_failure \
  notarize-signed-app-requires-notary-profile \
  "FERMO_NOTARYTOOL_PROFILE is required for notarization" \
  "$scripts_dir/notarize-signed-beta-app.sh" "/Applications/Fermo.app" "$tmp_dir/notary"

expect_failure \
  notarize-signed-app-rejects-placeholder-notary-profile \
  "FERMO_NOTARYTOOL_PROFILE must be a real keychain profile name, not a placeholder" \
  env FERMO_NOTARYTOOL_PROFILE="<profile>" \
  "$scripts_dir/notarize-signed-beta-app.sh" "/Applications/Fermo.app" "$tmp_dir/notary"

expect_failure \
  signed-build-environment-rejects-placeholder-notary-profile \
  "FERMO_NOTARYTOOL_PROFILE must be a real keychain profile name, not a placeholder" \
  env FERMO_NOTARYTOOL_PROFILE="<notarytool-keychain-profile>" \
  "$scripts_dir/check-signed-build-environment.sh"

expect_failure \
  signed-build-environment-rejects-placeholder-team-id \
  "Team ID must be a real 10-character Apple team ID, not a placeholder" \
  "$scripts_dir/check-signed-build-environment.sh" --team-id "<TEAM_ID>"

expect_failure \
  signed-build-environment-rejects-invalid-team-id \
  "Team ID must be a 10-character Apple team ID, got 'team123'" \
  "$scripts_dir/check-signed-build-environment.sh" --team-id "team123"

mkdir -p "$tmp_dir/nonempty-notary"
printf 'stale\n' > "$tmp_dir/nonempty-notary/stale.txt"
expect_failure \
  notarize-signed-app-rejects-nonempty-output-dir \
  "notary output directory must be empty" \
  env FERMO_NOTARYTOOL_PROFILE=test-profile \
  "$scripts_dir/notarize-signed-beta-app.sh" "/Applications/Fermo.app" "$tmp_dir/nonempty-notary"

mkdir -p "$tmp_dir/notary-target"
ln -s "$tmp_dir/notary-target" "$tmp_dir/notary-symlink"
expect_failure \
  notarize-signed-app-rejects-output-symlink \
  "notary output path must not be a symlink" \
  env FERMO_NOTARYTOOL_PROFILE=test-profile \
  "$scripts_dir/notarize-signed-beta-app.sh" "/Applications/Fermo.app" "$tmp_dir/notary-symlink"

expect_failure \
  notarize-signed-app-rejects-output-inside-app-bundle \
  "notary output directory must not be inside the app bundle" \
  env FERMO_NOTARYTOOL_PROFILE=test-profile \
  "$scripts_dir/notarize-signed-beta-app.sh" "/Applications/Fermo.app" "/Applications/Fermo.app/notary-output"

expect_failure \
  notarytool-log-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-notarytool-log.sh" "$tmp_dir/notarytool.log" "$tmp_dir/extra"

expect_failure \
  notarytool-log-rejects-missing-log \
  "notarytool log missing or empty" \
  "$scripts_dir/check-notarytool-log.sh" "$tmp_dir/missing-notarytool.log"

accepted_notary_id="$notary_request_id_fixture"
accepted_notary_log_path="$tmp_dir/accepted-notarytool.log"
printf 'id: %s\nstatus: Accepted\n' "$accepted_notary_id" > "$accepted_notary_log_path"
expect_success \
  notarytool-log-accepts-text-log \
  "$scripts_dir/check-notarytool-log.sh" "$accepted_notary_log_path"

notary_id_only_output_path="$tmp_dir/notary-id-only.out"
if ! "$scripts_dir/check-notarytool-log.sh" --id-only "$accepted_notary_log_path" > "$notary_id_only_output_path" 2>&1; then
  cat "$notary_id_only_output_path" >&2
  fail "notarytool-log-id-only failed unexpectedly"
fi
if [ "$(cat "$notary_id_only_output_path")" != "$accepted_notary_id" ]; then
  cat "$notary_id_only_output_path" >&2
  fail "notarytool-log-id-only did not print the expected request ID"
fi

json_notary_log_path="$tmp_dir/accepted-notarytool.json"
printf '{"id":"%s","status":"Accepted"}\n' "$accepted_notary_id" > "$json_notary_log_path"
expect_success \
  notarytool-log-accepts-json-log \
  "$scripts_dir/check-notarytool-log.sh" "$json_notary_log_path"

rejected_notary_log_path="$tmp_dir/rejected-notarytool.log"
printf 'id: %s\nstatus: Invalid\n' "$accepted_notary_id" > "$rejected_notary_log_path"
expect_failure \
  notarytool-log-rejects-nonaccepted-status \
  "notarytool log status must be Accepted, got 'Invalid'" \
  "$scripts_dir/check-notarytool-log.sh" "$rejected_notary_log_path"

missing_id_notary_log_path="$tmp_dir/missing-id-notarytool.log"
printf 'status: Accepted\n' > "$missing_id_notary_log_path"
expect_failure \
  notarytool-log-rejects-missing-request-id \
  "notarytool log is missing a UUID notarization request ID" \
  "$scripts_dir/check-notarytool-log.sh" "$missing_id_notary_log_path"

unrelated_uuid_notary_log_path="$tmp_dir/unrelated-uuid-notarytool.log"
printf 'status: Accepted\nmessage: archived request %s\n' "$accepted_notary_id" > "$unrelated_uuid_notary_log_path"
expect_failure \
  notarytool-log-rejects-unrelated-uuid-without-id-field \
  "notarytool log is missing a UUID notarization request ID" \
  "$scripts_dir/check-notarytool-log.sh" "$unrelated_uuid_notary_log_path"

# Regression: `notarytool submit --wait` streams "Current status: In Progress" lines before
# the final "  status: Accepted". The parser must read the final anchored status, not the
# first "status:" substring inside a progress line.
wait_stream_notary_log_path="$tmp_dir/wait-stream-notarytool.log"
{
  printf 'Submitting to the Notarization service\n'
  printf '  id: %s\n' "$accepted_notary_id"
  printf 'Current status: In Progress.....\n'
  printf 'Current status: In Progress.....\n'
  printf 'Processing complete\n'
  printf '  id: %s\n' "$accepted_notary_id"
  printf '  status: Accepted\n'
} > "$wait_stream_notary_log_path"
expect_success \
  notarytool-log-accepts-wait-stream-with-in-progress-lines \
  "$scripts_dir/check-notarytool-log.sh" "$wait_stream_notary_log_path"

# Regression: a --wait stream that ends Invalid must still be rejected (no false-accept from
# an earlier "Current status: In Progress" line).
wait_stream_invalid_notary_log_path="$tmp_dir/wait-stream-invalid-notarytool.log"
{
  printf 'Current status: In Progress.....\n'
  printf '  id: %s\n' "$accepted_notary_id"
  printf '  status: Invalid\n'
} > "$wait_stream_invalid_notary_log_path"
expect_failure \
  notarytool-log-rejects-wait-stream-ending-invalid \
  "notarytool log status must be Accepted, got 'Invalid'" \
  "$scripts_dir/check-notarytool-log.sh" "$wait_stream_invalid_notary_log_path"

expect_failure \
  signed-runtime-approvals-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-signed-runtime-approvals.sh" "/Applications/Fermo.app" "$tmp_dir/extra"

expect_failure \
  signed-runtime-approvals-requires-installed-app-path \
  "signed runtime approval check must use /Applications/Fermo.app, got" \
  "$scripts_dir/check-signed-runtime-approvals.sh" "$tmp_dir/Fermo.app"

expect_failure \
  signed-runtime-approvals-rejects-skipped-signatures \
  "signed runtime approval check cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/check-signed-runtime-approvals.sh" "/Applications/Fermo.app"

expect_failure \
  signed-helper-runtime-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-signed-helper-runtime.sh" "/Applications/Fermo.app" "$tmp_dir/extra"

expect_failure \
  signed-helper-runtime-requires-installed-app-path \
  "signed helper runtime check must use /Applications/Fermo.app, got" \
  "$scripts_dir/check-signed-helper-runtime.sh" "$tmp_dir/Fermo.app"

expect_failure \
  signed-helper-runtime-rejects-skipped-signatures \
  "signed helper runtime check cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/check-signed-helper-runtime.sh" "/Applications/Fermo.app"

expect_failure \
  archive-beta-release-evidence-rejects-extra-args \
  'usage:' \
  "$scripts_dir/archive-beta-release-evidence.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/evidence" "$tmp_dir/extra" "$tmp_dir/extra2" "$tmp_dir/extra3"

expect_failure \
  final-beta-publication-evidence-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-final-beta-publication-evidence.sh" "$tmp_dir/evidence" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/notarytool.log" "$tmp_dir/runtime-evidence" "$tmp_dir/extra"

expect_failure \
  export-final-beta-publication-packet-rejects-extra-args \
  'usage:' \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$tmp_dir/evidence" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/notarytool.log" "$tmp_dir/runtime-evidence" "$tmp_dir/publication-packet" "$tmp_dir/extra"

expect_failure \
  final-beta-publication-packet-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$tmp_dir/publication-packet" "$tmp_dir/evidence" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/notarytool.log" "$tmp_dir/runtime-evidence" "$tmp_dir/extra"

expect_failure \
  archive-beta-release-evidence-requires-installed-app-path \
  "beta release evidence archive must use /Applications/Fermo.app, got" \
  "$scripts_dir/archive-beta-release-evidence.sh" "$tmp_dir/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/evidence"

expect_failure \
  archive-beta-release-evidence-rejects-skipped-signatures \
  "beta release evidence archive cannot run with FERMO_SKIP_SIGNATURE_CHECKS=1" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/archive-beta-release-evidence.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/evidence"

mkdir -p "$tmp_dir/nonempty-release-evidence"
printf 'stale\n' > "$tmp_dir/nonempty-release-evidence/stale.txt"
expect_failure \
  archive-beta-release-evidence-rejects-nonempty-output-dir \
  "beta release evidence output directory must be empty" \
  "$scripts_dir/archive-beta-release-evidence.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/nonempty-release-evidence"

mkdir -p "$tmp_dir/release-evidence-target"
ln -s "$tmp_dir/release-evidence-target" "$tmp_dir/release-evidence-symlink"
expect_failure \
  archive-beta-release-evidence-rejects-output-symlink \
  "beta release evidence output path must not be a symlink" \
  "$scripts_dir/archive-beta-release-evidence.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path" "$tmp_dir/release-evidence-symlink"

expect_failure \
  archive-beta-release-evidence-rejects-output-inside-app-bundle \
  "beta release evidence output directory must not be inside the app bundle" \
  "$scripts_dir/archive-beta-release-evidence.sh" "/Applications/Fermo.app" "$manifest_path" "$matrix_path" "$metadata_path" "/Applications/Fermo.app/release-evidence"

write_release_evidence_fixture
expect_success \
  beta-release-evidence-archive-valid \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path"

{
  printf '%s  %s\n' "$sha256" "$(basename "$zip_path")"
  printf '%s  %s\n' "$sha256" "$(basename "$zip_path")"
} > "$checksum_path"
write_release_evidence_fixture
expect_failure \
  beta-release-evidence-archive-checksum-extra-entry \
  "checksum copy must contain exactly one ZIP entry" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path"
printf '%s  %s\n' "$sha256" "$(basename "$zip_path")" > "$checksum_path"

printf '%s  Other.zip\n' "$sha256" > "$checksum_path"
write_release_evidence_fixture
expect_failure \
  beta-release-evidence-archive-checksum-basename-mismatch \
  "checksum copy must reference ZIP basename 'Fermo-0.1.0-3-beta.zip', got 'Other.zip'" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path"
printf '%s  %s\n' "$sha256" "$(basename "$zip_path")" > "$checksum_path"

notary_log_path="$tmp_dir/notarytool.log"
printf 'id: %s\nstatus: Accepted\n' "$accepted_notary_id" > "$notary_log_path"
notary_log_hash="$(shasum -a 256 "$notary_log_path" | awk '{print $1}')"
write_release_evidence_fixture
cp "$notary_log_path" "$evidence_fixture_dir/$(basename "$notary_log_path")"
awk -v log_basename="$(basename "$notary_log_path")" -v notary_id="$accepted_notary_id" -v notary_log_hash="$notary_log_hash" '
  /^- Checksum file:/ {
    print
    printf "- Notarization request ID: %s\n", notary_id
    printf "- Notary log: %s\n", log_basename
    printf "- Notary log SHA-256: %s\n", notary_log_hash
    next
  }
  { print }
' "$evidence_fixture_dir/release-evidence.md" > "$tmp_dir/release-evidence-with-notary.md"
mv "$tmp_dir/release-evidence-with-notary.md" "$evidence_fixture_dir/release-evidence.md"
expect_success \
  beta-release-evidence-archive-valid-with-notary-log \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path"

reserved_archive_notary_log_path="$tmp_dir/release-evidence.md"
printf 'id: %s\nstatus: Accepted\n' "$accepted_notary_id" > "$reserved_archive_notary_log_path"
expect_failure \
  beta-release-evidence-archive-rejects-reserved-notary-log-basename \
  "notarytool log basename conflicts with a reserved release evidence archive entry: release-evidence.md" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$reserved_archive_notary_log_path"

sed 's/- Notary log SHA-256: .*/- Notary log SHA-256: deadbeef/' "$evidence_fixture_dir/release-evidence.md" > "$tmp_dir/release-evidence-notary-log-checksum-mismatch.md"
mv "$tmp_dir/release-evidence-notary-log-checksum-mismatch.md" "$evidence_fixture_dir/release-evidence.md"
expect_failure \
  beta-release-evidence-archive-notary-log-checksum-summary-mismatch \
  "release evidence summary missing required text: - Notary log SHA-256: $notary_log_hash" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path"

write_signed_runtime_evidence_fixture
write_release_evidence_fixture
printf 'id: %s\nstatus: Accepted\n' "$accepted_notary_id" > "$notary_log_path"
notary_log_hash="$(shasum -a 256 "$notary_log_path" | awk '{print $1}')"
cp "$notary_log_path" "$evidence_fixture_dir/$(basename "$notary_log_path")"
cp -R "$runtime_evidence_fixture_dir" "$evidence_fixture_dir/signed-runtime-evidence"
runtime_checksum_hash="$(shasum -a 256 "$runtime_evidence_fixture_dir/signed-runtime-evidence.sha256" | awk '{print $1}')"
awk -v log_basename="$(basename "$notary_log_path")" -v notary_id="$accepted_notary_id" -v notary_log_hash="$notary_log_hash" -v runtime_checksum_hash="$runtime_checksum_hash" '
  /^- Checksum file:/ {
    print
    printf "- Notarization request ID: %s\n", notary_id
    printf "- Notary log: %s\n", log_basename
    printf "- Notary log SHA-256: %s\n", notary_log_hash
    printf "- Signed runtime evidence: signed-runtime-evidence\n"
    printf "- Signed runtime evidence checksum file: signed-runtime-evidence/signed-runtime-evidence.sha256\n"
    printf "- Signed runtime evidence checksum SHA-256: %s\n", runtime_checksum_hash
    next
  }
  { print }
' "$evidence_fixture_dir/release-evidence.md" > "$tmp_dir/release-evidence-with-runtime.md"
mv "$tmp_dir/release-evidence-with-runtime.md" "$evidence_fixture_dir/release-evidence.md"
expect_success \
  beta-release-evidence-archive-valid-with-runtime-evidence \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

ln -s "$evidence_fixture_dir" "$tmp_dir/release-evidence-check-symlink"
expect_failure \
  beta-release-evidence-archive-rejects-root-symlink \
  "release evidence archive directory must not be a symlink" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$tmp_dir/release-evidence-check-symlink" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rm "$tmp_dir/release-evidence-check-symlink"

printf 'stale\n' > "$evidence_fixture_dir/stale-release-evidence.txt"
expect_failure \
  beta-release-evidence-archive-rejects-unexpected-file \
  "release evidence archive contains unexpected or missing files" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rm "$evidence_fixture_dir/stale-release-evidence.txt"

ln -s release-evidence.md "$evidence_fixture_dir/stale-release-evidence-link"
expect_failure \
  beta-release-evidence-archive-rejects-symlink \
  "release evidence archive contains unsupported non-file entries" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rm "$evidence_fixture_dir/stale-release-evidence-link"

mkdir "$evidence_fixture_dir/stale-release-evidence-dir"
expect_failure \
  beta-release-evidence-archive-rejects-unexpected-directory \
  "release evidence archive contains unexpected directories" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rmdir "$evidence_fixture_dir/stale-release-evidence-dir"

expect_success \
  final-beta-publication-evidence-valid \
  "$scripts_dir/check-final-beta-publication-evidence.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

reserved_publication_notary_log_path="$tmp_dir/PUBLICATION_PACKET.md"
reserved_publication_evidence_dir="$tmp_dir/evidence-publication-reserved"
printf 'id: %s\nstatus: Accepted\n' "$accepted_notary_id" > "$reserved_publication_notary_log_path"
cp -R "$evidence_fixture_dir" "$reserved_publication_evidence_dir"
rm "$reserved_publication_evidence_dir/$(basename "$notary_log_path")"
cp "$reserved_publication_notary_log_path" "$reserved_publication_evidence_dir/$(basename "$reserved_publication_notary_log_path")"
sed "s/- Notary log: $(basename "$notary_log_path")/- Notary log: $(basename "$reserved_publication_notary_log_path")/" "$reserved_publication_evidence_dir/release-evidence.md" > "$tmp_dir/release-evidence-publication-reserved.md"
mv "$tmp_dir/release-evidence-publication-reserved.md" "$reserved_publication_evidence_dir/release-evidence.md"
expect_failure \
  export-final-beta-publication-packet-rejects-reserved-notary-log-basename \
  "notarytool log basename conflicts with a reserved publication packet entry: PUBLICATION_PACKET.md" \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$reserved_publication_evidence_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$reserved_publication_notary_log_path" "$runtime_evidence_fixture_dir" "$tmp_dir/publication-packet-reserved"

publication_packet_dir="$tmp_dir/publication-packet"
expect_success \
  export-final-beta-publication-packet-valid \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir" "$publication_packet_dir"

expect_failure \
  export-final-beta-publication-packet-rejects-nonempty-output-dir \
  "publication packet output directory must be empty" \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir" "$publication_packet_dir"

mkdir -p "$tmp_dir/publication-packet-target"
ln -s "$tmp_dir/publication-packet-target" "$tmp_dir/publication-packet-symlink"
expect_failure \
  export-final-beta-publication-packet-rejects-output-symlink \
  "publication packet output path must not be a symlink" \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir" "$tmp_dir/publication-packet-symlink"

expect_failure \
  export-final-beta-publication-packet-rejects-output-inside-app-bundle \
  "publication packet output directory must not be inside the app bundle" \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir" "/Applications/Fermo.app/publication-packet"

expect_success \
  final-beta-publication-packet-valid \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$publication_packet_dir" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

ln -s "$publication_packet_dir" "$tmp_dir/publication-packet-check-symlink"
expect_failure \
  final-beta-publication-packet-rejects-root-symlink \
  "publication packet directory must not be a symlink" \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$tmp_dir/publication-packet-check-symlink" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rm "$tmp_dir/publication-packet-check-symlink"

printf 'stale\n' > "$publication_packet_dir/stale-upload.txt"
expect_failure \
  final-beta-publication-packet-rejects-unexpected-file \
  "publication packet contains unexpected or missing files" \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$publication_packet_dir" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rm "$publication_packet_dir/stale-upload.txt"

ln -s "$(basename "$zip_path")" "$publication_packet_dir/stale-upload-link"
expect_failure \
  final-beta-publication-packet-rejects-symlink \
  "publication packet contains unsupported non-file entries" \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$publication_packet_dir" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rm "$publication_packet_dir/stale-upload-link"

mkdir "$publication_packet_dir/stale-upload-dir"
expect_failure \
  final-beta-publication-packet-rejects-unexpected-directory \
  "publication packet contains unexpected directories" \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$publication_packet_dir" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
rmdir "$publication_packet_dir/stale-upload-dir"

printf '\ndrift\n' >> "$publication_packet_dir/$(basename "$zip_path")"
expect_failure \
  final-beta-publication-packet-zip-drift \
  "ZIP copy does not match source file" \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$publication_packet_dir" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

publication_packet_dir_restored="$tmp_dir/publication-packet-restored"
expect_success \
  export-final-beta-publication-packet-restores-fixture \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir" "$publication_packet_dir_restored"

publication_packet_dir_missing_checksum="$tmp_dir/publication-packet-missing-checksum"
expect_success \
  export-final-beta-publication-packet-missing-checksum-fixture \
  "$scripts_dir/export-final-beta-publication-packet.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir" "$publication_packet_dir_missing_checksum"
awk 'NR == 1 { print; exit }' "$publication_packet_dir_missing_checksum/publication-packet.sha256" > "$tmp_dir/publication-packet-missing-files.sha256"
mv "$tmp_dir/publication-packet-missing-files.sha256" "$publication_packet_dir_missing_checksum/publication-packet.sha256"
expect_failure \
  final-beta-publication-packet-checksum-missing-files \
  "publication packet checksum manifest does not list exactly the packet files" \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$publication_packet_dir_missing_checksum" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

sed '1s/^[0-9a-f][0-9a-f]*/0000000000000000000000000000000000000000000000000000000000000000/' "$publication_packet_dir_restored/publication-packet.sha256" > "$tmp_dir/publication-packet-checksum-drift.sha256"
mv "$tmp_dir/publication-packet-checksum-drift.sha256" "$publication_packet_dir_restored/publication-packet.sha256"
expect_failure \
  final-beta-publication-packet-checksum-drift \
  "publication packet checksum manifest does not match packet files" \
  "$scripts_dir/check-final-beta-publication-packet.sh" "$publication_packet_dir_restored" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

metadata_beta_backup_path="$tmp_dir/toolary-beta-metadata.backup.json"
cp "$metadata_path" "$metadata_beta_backup_path"
/usr/bin/ruby -rjson -e '
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))
  data["status"] = "comingSoon"
  File.write(path, JSON.pretty_generate(data))
' "$metadata_path"
cp "$metadata_path" "$evidence_fixture_dir/$(basename "$metadata_path")"
expect_failure \
  final-beta-publication-evidence-requires-beta-metadata \
  "final publication evidence requires Toolary metadata status beta, got 'comingSoon'" \
  "$scripts_dir/check-final-beta-publication-evidence.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"
cp "$metadata_beta_backup_path" "$metadata_path"
cp "$metadata_path" "$evidence_fixture_dir/$(basename "$metadata_path")"

sed 's/- Signed runtime evidence checksum SHA-256: .*/- Signed runtime evidence checksum SHA-256: deadbeef/' "$evidence_fixture_dir/release-evidence.md" > "$tmp_dir/release-evidence-runtime-checksum-mismatch.md"
mv "$tmp_dir/release-evidence-runtime-checksum-mismatch.md" "$evidence_fixture_dir/release-evidence.md"
expect_failure \
  beta-release-evidence-archive-runtime-checksum-summary-mismatch \
  "release evidence summary missing required text: - Signed runtime evidence checksum SHA-256: $runtime_checksum_hash" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

awk -v runtime_checksum_hash="$runtime_checksum_hash" '
  /^- Signed runtime evidence checksum SHA-256:/ {
    printf "- Signed runtime evidence checksum SHA-256: %s\n", runtime_checksum_hash
    next
  }
  { print }
' "$evidence_fixture_dir/release-evidence.md" > "$tmp_dir/release-evidence-runtime-checksum-restored.md"
mv "$tmp_dir/release-evidence-runtime-checksum-restored.md" "$evidence_fixture_dir/release-evidence.md"

printf '\ndrift\n' >> "$evidence_fixture_dir/signed-runtime-evidence/system.txt"
expect_failure \
  beta-release-evidence-archive-runtime-evidence-drift \
  "signed runtime evidence checksum manifest does not match captured files" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path" "$runtime_evidence_fixture_dir"

rm -rf "$evidence_fixture_dir/signed-runtime-evidence"

printf '\ndrift\n' >> "$evidence_fixture_dir/$(basename "$notary_log_path")"
expect_failure \
  beta-release-evidence-archive-notary-log-drift \
  "notarytool log copy does not match source file" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path"

printf 'id: %s\nstatus: Invalid\n' "$accepted_notary_id" > "$evidence_fixture_dir/$(basename "$notary_log_path")"
cp "$evidence_fixture_dir/$(basename "$notary_log_path")" "$notary_log_path"
expect_failure \
  beta-release-evidence-archive-rejects-invalid-notary-log \
  "notarytool log status must be Accepted, got 'Invalid'" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path"

printf 'id: 87654321-4321-4321-4321-cba987654321\nstatus: Accepted\n' > "$notary_log_path"
cp "$notary_log_path" "$evidence_fixture_dir/$(basename "$notary_log_path")"
expect_failure \
  beta-release-evidence-archive-rejects-notary-request-id-mismatch \
  "does not match notarytool log request ID" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path" "$notary_log_path"

rm "$evidence_fixture_dir/release-evidence.md"
expect_failure \
  beta-release-evidence-archive-missing-summary \
  "release evidence summary missing or empty" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path"

write_release_evidence_fixture
printf '\n# drift\n' >> "$evidence_fixture_dir/$(basename "$manifest_path")"
expect_failure \
  beta-release-evidence-archive-manifest-copy-drift \
  "manifest copy does not match source file" \
  "$scripts_dir/check-beta-release-evidence-archive.sh" "$evidence_fixture_dir" "$manifest_path" "$matrix_path" "$metadata_path"

write_beta_fixture "Failed"
expect_failure \
  beta-release-gate-failed-status \
  'runtime matrix contains non-passing status values: Failed' \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

write_beta_fixture "Passed"
expect_success \
  beta-release-gate-passed-status \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

printf '\nmanual note: pending browser retest\n' >> "$matrix_path"
expect_failure \
  beta-release-gate-lowercase-pending-marker \
  "runtime matrix still contains Pending/TODO/TBD" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

# Regression for the false-failure where the template's own instructional prose
# ("FERMO_RUNTIME_MATRIX_STATUS=pending|passed") used to trip the whole-file marker scan,
# so a correctly completed matrix could never pass. write_beta_fixture now embeds that
# prose, so a passing run also proves the leading prose is exempt.
write_beta_fixture "Passed"
expect_success \
  beta-release-gate-passes-with-template-pending-prose \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

# Regression for the brittle substring match: a benign word containing "pending"
# ("appending") in a trailing note must not be mistaken for an unfinished row.
write_beta_fixture "Passed"
printf '\nmanual note: appending signed evidence links before upload\n' >> "$matrix_path"
expect_success \
  beta-release-gate-allows-benign-pending-substring \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

write_beta_fixture "Passed"

expect_failure \
  beta-release-gate-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path" "$tmp_dir/extra"

sed "s/$sha256/deadbeef/" "$manifest_path" > "$tmp_dir/manifest-sha-mismatch.md"
expect_failure \
  beta-release-gate-manifest-sha-mismatch \
  "manifest SHA-256 does not match ZIP artifact" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-sha-mismatch.md" "$matrix_path"

printf '0000000000000000000000000000000000000000000000000000000000000000  %s\n' "$(basename "$zip_path")" > "$checksum_path"
expect_failure \
  beta-release-gate-checksum-file-mismatch \
  "checksum file does not match ZIP artifact" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

write_beta_fixture "Passed"

printf '%s  Other.zip\n' "$sha256" > "$checksum_path"
expect_failure \
  beta-release-gate-checksum-filename-mismatch \
  "checksum file must reference ZIP basename 'Fermo-0.1.0-3-beta.zip', got 'Other.zip'" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

write_beta_fixture "Passed"

{
  printf '%s  %s\n' "$sha256" "$(basename "$zip_path")"
  printf '%s  %s\n' "$sha256" "$(basename "$zip_path")"
} > "$checksum_path"
expect_failure \
  beta-release-gate-checksum-extra-entry \
  "checksum file must contain exactly one ZIP entry" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$matrix_path"

write_beta_fixture "Passed"

wrong_zip_path="$tmp_dir/Fermo-0.1.0-3-dogfood-dev.zip"
cp "$zip_path" "$wrong_zip_path"
printf '%s  %s\n' "$sha256" "$(basename "$wrong_zip_path")" > "$wrong_zip_path.sha256"
sed "s#$(printf '%s' "$zip_path")#$wrong_zip_path#" "$manifest_path" > "$tmp_dir/manifest-wrong-zip-basename.md"
expect_failure \
  beta-release-gate-wrong-zip-basename \
  "manifest ZIP basename must be Fermo-0.1.0-3-beta.zip, got 'Fermo-0.1.0-3-dogfood-dev.zip'" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-wrong-zip-basename.md" "$matrix_path"

write_beta_fixture "Passed"

sed 's/- Created: 2026-05-25T07:00:00Z/- Created: 2026-05-25 07:00/' "$manifest_path" > "$tmp_dir/manifest-invalid-created-format.md"
expect_failure \
  beta-release-gate-invalid-created-format \
  "manifest Created must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ, got '2026-05-25 07:00'" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-invalid-created-format.md" "$matrix_path"

write_beta_fixture "Passed"

sed 's/- Version: 0.1.0/- Version: 0.0.0/' "$manifest_path" > "$tmp_dir/manifest-placeholder-version.md"
expect_failure \
  beta-release-gate-placeholder-version \
  "manifest cannot use placeholder Version 0.0.0" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-placeholder-version.md" "$matrix_path"

sed 's/- Build: 3/- Build: 0/' "$manifest_path" > "$tmp_dir/manifest-placeholder-build.md"
expect_failure \
  beta-release-gate-placeholder-build \
  "manifest cannot use placeholder Build 0" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-placeholder-build.md" "$matrix_path"

sed 's/- Version: 0.1.0/- Version: 0.1 beta/' "$manifest_path" > "$tmp_dir/manifest-invalid-version-format.md"
expect_failure \
  beta-release-gate-invalid-version-format \
  "manifest Version must be numeric dot-separated, got '0.1 beta'" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-invalid-version-format.md" "$matrix_path"

sed 's/- Build: 3/- Build: build-three/' "$manifest_path" > "$tmp_dir/manifest-invalid-build-format.md"
expect_failure \
  beta-release-gate-invalid-build-format \
  "manifest Build must be numeric dot-separated, got 'build-three'" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-invalid-build-format.md" "$matrix_path"

sed 's/- Git commit: abc1234/- Git commit: unknown/' "$manifest_path" > "$tmp_dir/manifest-invalid-git-commit.md"
expect_failure \
  beta-release-gate-invalid-git-commit \
  "manifest Git commit must be a git SHA, got 'unknown'" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-invalid-git-commit.md" "$matrix_path"

sed 's/- Git tree: clean/- Git tree: dirty/' "$manifest_path" > "$tmp_dir/manifest-dirty-git-tree.md"
expect_failure \
  beta-release-gate-dirty-git-tree \
  "manifest Git tree must be clean, got 'dirty'" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-dirty-git-tree.md" "$matrix_path"

grep -v 'App path' "$manifest_path" > "$tmp_dir/manifest-missing-app-path.md"
expect_failure \
  beta-release-gate-missing-app-path \
  "manifest is missing App path" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-missing-app-path.md" "$matrix_path"

sed 's#/Applications/Fermo.app#/tmp/Fermo.app#' "$manifest_path" > "$tmp_dir/manifest-wrong-app-path.md"
expect_failure \
  beta-release-gate-wrong-app-path \
  "manifest App path must be /Applications/Fermo.app" \
  "$scripts_dir/check-beta-release-gate.sh" "$tmp_dir/manifest-wrong-app-path.md" "$matrix_path"

sed 's/- Build: 3/- Build: 4/' "$matrix_path" > "$tmp_dir/matrix-build-mismatch.md"
expect_failure \
  beta-release-gate-build-mismatch \
  "runtime matrix Build does not match manifest" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-build-mismatch.md"

sed 's/- Channel: beta/- Channel: dogfood-dev/' "$matrix_path" > "$tmp_dir/matrix-channel-mismatch.md"
expect_failure \
  beta-release-gate-channel-mismatch \
  "runtime matrix Channel does not match manifest" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-channel-mismatch.md"

sed 's/- Date: 2026-05-25T07:00:00Z/- Date: 2026-05-25 07:00/' "$matrix_path" > "$tmp_dir/matrix-invalid-date-format.md"
expect_failure \
  beta-release-gate-invalid-matrix-date-format \
  "runtime matrix Date must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ, got '2026-05-25 07:00'" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-invalid-date-format.md"

sed 's/- Git tree: clean/- Git tree: dirty/' "$matrix_path" > "$tmp_dir/matrix-git-tree-mismatch.md"
expect_failure \
  beta-release-gate-git-tree-mismatch \
  "runtime matrix Git tree does not match manifest" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-git-tree-mismatch.md"

grep -v 'App path' "$matrix_path" > "$tmp_dir/matrix-missing-app-path.md"
expect_failure \
  beta-release-gate-missing-matrix-app-path \
  "runtime matrix is missing App path" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-missing-app-path.md"

sed 's#/Applications/Fermo.app#/tmp/Fermo.app#' "$matrix_path" > "$tmp_dir/matrix-app-path-mismatch.md"
expect_failure \
  beta-release-gate-matrix-app-path-mismatch \
  "runtime matrix App path does not match manifest" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-app-path-mismatch.md"

grep -v 'Content Filter rule snapshot' "$matrix_path" > "$tmp_dir/matrix-missing-content-filter-snapshot.md"
expect_failure \
  beta-release-gate-missing-content-filter-snapshot \
  "runtime matrix is missing required Content Filter rule snapshot row" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-missing-content-filter-snapshot.md"

sed 's/appGuardSnapshotState: ready/appGuardSnapshotState: missing/' "$matrix_path" > "$tmp_dir/matrix-missing-app-guard-ready-evidence.md"
expect_failure \
  beta-release-gate-missing-app-guard-ready-evidence \
  "runtime matrix is missing required App Guard ready evidence" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-missing-app-guard-ready-evidence.md"

sed 's/contentFilterSnapshotState: ready/contentFilterSnapshotState: missing/' "$matrix_path" > "$tmp_dir/matrix-missing-content-filter-ready-evidence.md"
expect_failure \
  beta-release-gate-missing-content-filter-ready-evidence \
  "runtime matrix is missing required Content Filter ready evidence" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-missing-content-filter-ready-evidence.md"

sed 's/- Signing identity: Developer ID Application: Toolary Test/- Signing identity:/' "$matrix_path" > "$tmp_dir/matrix-missing-signing-identity.md"
expect_failure \
  beta-release-gate-missing-signing-identity \
  "runtime matrix is missing Signing identity" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-missing-signing-identity.md"

sed 's/- Notarization request ID: .*/- Notarization request ID: test-notary/' "$matrix_path" > "$tmp_dir/matrix-invalid-notary-request-id.md"
expect_failure \
  beta-release-gate-invalid-notary-request-id \
  "runtime matrix Notarization request ID must be a UUID" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-invalid-notary-request-id.md"

sed 's/- Toolary publishable: yes/- Toolary publishable: no/' "$matrix_path" > "$tmp_dir/matrix-publishable-mismatch.md"
expect_failure \
  beta-release-gate-publishable-mismatch \
  "runtime matrix Toolary publishable does not match manifest" \
  "$scripts_dir/check-beta-release-gate.sh" "$manifest_path" "$tmp_dir/matrix-publishable-mismatch.md"

expect_success \
  prepare-runtime-matrix-from-valid-manifest \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$manifest_path" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-runtime-matrix.md"

expect_failure \
  prepare-runtime-matrix-rejects-output-inside-app-bundle \
  "runtime matrix output path must not be inside the app bundle" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$manifest_path" "$repo_root/docs/toolary-beta-runtime-matrix.md" "/Applications/Fermo.app/prepared-runtime-matrix.md"

sed "s#- App path: /Applications/Fermo.app#- App path: $candidate_app_path#" "$manifest_path" > "$tmp_dir/manifest-tmp-app-path.md"
ln -s "$candidate_app_path" "$tmp_dir/prepared-runtime-matrix-app-symlink"
expect_failure \
  prepare-runtime-matrix-rejects-output-under-symlinked-app-ancestor \
  "runtime matrix output path must not be inside the app bundle" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$tmp_dir/manifest-tmp-app-path.md" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-runtime-matrix-app-symlink/deep/prepared-runtime-matrix.md"

expect_failure \
  prepare-runtime-matrix-rejects-existing-output \
  "runtime matrix output already exists" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$manifest_path" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-runtime-matrix.md"

grep -v 'Created' "$manifest_path" > "$tmp_dir/manifest-missing-created.md"
expect_failure \
  prepare-runtime-matrix-missing-created \
  "manifest must include Created" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$tmp_dir/manifest-missing-created.md" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-missing-created.md"

sed 's/- Created: 2026-05-25T07:00:00Z/- Created: 2026-05-25 07:00/' "$manifest_path" > "$tmp_dir/manifest-prepare-invalid-created-format.md"
expect_failure \
  prepare-runtime-matrix-invalid-created-format \
  "manifest Created must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ, got '2026-05-25 07:00'" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$tmp_dir/manifest-prepare-invalid-created-format.md" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-invalid-created-format.md"

sed "s/$sha256/deadbeef/" "$manifest_path" > "$tmp_dir/manifest-prepare-sha-mismatch.md"
expect_failure \
  prepare-runtime-matrix-sha-mismatch \
  "manifest SHA-256 does not match ZIP artifact" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$tmp_dir/manifest-prepare-sha-mismatch.md" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-sha-mismatch.md"

printf '%s  Other.zip\n' "$sha256" > "$checksum_path"
expect_failure \
  prepare-runtime-matrix-checksum-filename-mismatch \
  "checksum file must reference ZIP basename 'Fermo-0.1.0-3-beta.zip', got 'Other.zip'" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$manifest_path" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-checksum-filename-mismatch.md"

write_beta_fixture "Passed"

{
  printf '%s  %s\n' "$sha256" "$(basename "$zip_path")"
  printf '%s  %s\n' "$sha256" "$(basename "$zip_path")"
} > "$checksum_path"
expect_failure \
  prepare-runtime-matrix-checksum-extra-entry \
  "checksum file must contain exactly one ZIP entry" \
  "$scripts_dir/prepare-beta-runtime-matrix.sh" "$manifest_path" "$repo_root/docs/toolary-beta-runtime-matrix.md" "$tmp_dir/prepared-checksum-extra-entry.md"

write_beta_fixture "Passed"

write_beta_metadata_fixture
expect_failure \
  metadata-gate-rejects-partial-artifact-args \
  'usage:' \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_path" "$manifest_path"

expect_failure \
  metadata-gate-rejects-extra-args \
  'usage:' \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_path" "$manifest_path" "$matrix_path" "$tmp_dir/extra"

expect_failure \
  beta-metadata-requires-artifact-gates \
  'beta metadata requires manifest and completed runtime matrix' \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_path"

metadata_version_mismatch_path="$tmp_dir/toolary-beta-metadata-version-mismatch.json"
/usr/bin/ruby -rjson -e '
  source_path = ARGV.fetch(0)
  output_path = ARGV.fetch(1)
  data = JSON.parse(File.read(source_path))
  data["version"] = "9.9.9"
  File.write(output_path, JSON.pretty_generate(data))
' "$metadata_path" "$metadata_version_mismatch_path"

expect_failure \
  beta-metadata-version-mismatch \
  "metadata version must match manifest Version '0.1.0', got '9.9.9'" \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_version_mismatch_path" "$manifest_path" "$matrix_path"

metadata_weakened_gate_path="$tmp_dir/toolary-metadata-weakened-gate.json"
/usr/bin/ruby -rjson -e '
  source_path = ARGV.fetch(0)
  output_path = ARGV.fetch(1)
  data = JSON.parse(File.read(source_path))
  data["status"] = "comingSoon"
  data["releaseGate"]["requiresRuntimeMatrix"] = false
  File.write(output_path, JSON.pretty_generate(data))
' "$repo_root/docs/toolary-catalog-metadata.json" "$metadata_weakened_gate_path"

expect_failure \
  metadata-weakened-runtime-matrix-gate \
  "metadata releaseGate.requiresRuntimeMatrix must be true" \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_weakened_gate_path"

expect_success \
  coming-soon-metadata-without-artifact \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$repo_root/docs/toolary-catalog-metadata.json"

expect_success \
  coming-soon-metadata-with-passed-artifact-gate \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$repo_root/docs/toolary-catalog-metadata.json" "$manifest_path" "$matrix_path"

coming_soon_metadata_version_mismatch_path="$tmp_dir/toolary-coming-soon-metadata-version-mismatch.json"
/usr/bin/ruby -rjson -e '
  source_path = ARGV.fetch(0)
  output_path = ARGV.fetch(1)
  data = JSON.parse(File.read(source_path))
  data["version"] = "9.9.9"
  File.write(output_path, JSON.pretty_generate(data))
' "$repo_root/docs/toolary-catalog-metadata.json" "$coming_soon_metadata_version_mismatch_path"

expect_failure \
  coming-soon-metadata-artifact-version-mismatch \
  "metadata version must match manifest Version '0.1.0', got '9.9.9'" \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$coming_soon_metadata_version_mismatch_path" "$manifest_path" "$matrix_path"

metadata_overclaim_path="$tmp_dir/toolary-metadata-overclaim.json"
/usr/bin/ruby -rjson -e '
  source_path = ARGV.fetch(0)
  output_path = ARGV.fetch(1)
  data = JSON.parse(File.read(source_path))
  data["locales"]["pl"]["description"] = "Fermo jest niemożliwe do obejścia."
  File.write(output_path, JSON.pretty_generate(data))
' "$repo_root/docs/toolary-catalog-metadata.json" "$metadata_overclaim_path"

expect_failure \
  metadata-overclaim-polish-accented \
  "metadata contains an overstrong bypass-resistance claim" \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_overclaim_path"

metadata_overclaim_plain_polish_path="$tmp_dir/toolary-metadata-overclaim-plain-polish.json"
/usr/bin/ruby -rjson -e '
  source_path = ARGV.fetch(0)
  output_path = ARGV.fetch(1)
  data = JSON.parse(File.read(source_path))
  data["locales"]["pl"]["description"] = "Fermo nie można obejść."
  File.write(output_path, JSON.pretty_generate(data))
' "$repo_root/docs/toolary-catalog-metadata.json" "$metadata_overclaim_plain_polish_path"

expect_failure \
  metadata-overclaim-polish-cannot-bypass \
  "metadata contains an overstrong bypass-resistance claim" \
  "$scripts_dir/check-toolary-metadata-gate.sh" "$metadata_overclaim_plain_polish_path"

write_app_manifest_fixture
expect_success \
  candidate-manifest-app-match \
  "$scripts_dir/check-candidate-manifest-app.sh" "$app_path" "$manifest_path"

sed "s#- App path: $app_path#- App path: $tmp_dir/Other.app#" "$manifest_path" > "$tmp_dir/app-manifest-path-mismatch.md"
expect_failure \
  candidate-manifest-path-mismatch \
  "manifest App path must match app path" \
  "$scripts_dir/check-candidate-manifest-app.sh" "$app_path" "$tmp_dir/app-manifest-path-mismatch.md"

sed 's/- Version: 0.1.0/- Version: 0.2.0/' "$manifest_path" > "$tmp_dir/app-manifest-version-mismatch.md"
expect_failure \
  candidate-manifest-version-mismatch \
  "manifest Version must match app CFBundleShortVersionString '0.1.0', got '0.2.0'" \
  "$scripts_dir/check-candidate-manifest-app.sh" "$app_path" "$tmp_dir/app-manifest-version-mismatch.md"

write_candidate_app_fixture
expect_failure \
  candidate-preflight-rejects-extra-args \
  "usage:" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/verify-beta-candidate.sh" "$candidate_app_path" "$tmp_dir/extra"

expect_failure \
  candidate-preflight-rejects-unknown-skip-signature-flag \
  "FERMO_SKIP_SIGNATURE_CHECKS must be 0 or 1, got 'true'" \
  env FERMO_SKIP_SIGNATURE_CHECKS=true \
  "$scripts_dir/verify-beta-candidate.sh" "$candidate_app_path"

expect_success \
  candidate-preflight-bundle-id-match \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/verify-beta-candidate.sh" "$candidate_app_path"

write_info_plist "$helper_app_path/Contents/Info.plist" "com.toolary.fermo.badhelper" "APPL"
expect_failure \
  candidate-preflight-helper-bundle-id-mismatch \
  "FermoHelper login item CFBundleIdentifier must be com.toolary.fermo.helper" \
  env FERMO_SKIP_SIGNATURE_CHECKS=1 \
  "$scripts_dir/verify-beta-candidate.sh" "$candidate_app_path"

write_release_copy_fixture
expect_success \
  release-copy-version-match \
  env \
  FERMO_RELEASE_NOTES_PATH="$release_notes_fixture_path" \
  FERMO_TOOLARY_COPY_PATH="$toolary_copy_fixture_path" \
  FERMO_TOOLARY_METADATA_PATH="$metadata_fixture_path" \
  "$scripts_dir/check-release-copy.sh"

cp "$toolary_copy_fixture_path" "$tmp_dir/toolary-copy-overclaim.md"
printf '\nFermo ist umgehungssicher.\n' >> "$tmp_dir/toolary-copy-overclaim.md"
expect_failure \
  release-copy-overclaim-german \
  "Toolary beta copy contains an overstrong bypass-resistance claim" \
  env \
  FERMO_RELEASE_NOTES_PATH="$release_notes_fixture_path" \
  FERMO_TOOLARY_COPY_PATH="$tmp_dir/toolary-copy-overclaim.md" \
  FERMO_TOOLARY_METADATA_PATH="$metadata_fixture_path" \
  "$scripts_dir/check-release-copy.sh"

cp "$toolary_copy_fixture_path" "$tmp_dir/toolary-copy-overclaim-contraction.md"
printf "\nFermo can't be bypassed.\n" >> "$tmp_dir/toolary-copy-overclaim-contraction.md"
expect_failure \
  release-copy-overclaim-english-contraction \
  "Toolary beta copy contains an overstrong bypass-resistance claim" \
  env \
  FERMO_RELEASE_NOTES_PATH="$release_notes_fixture_path" \
  FERMO_TOOLARY_COPY_PATH="$tmp_dir/toolary-copy-overclaim-contraction.md" \
  FERMO_TOOLARY_METADATA_PATH="$metadata_fixture_path" \
  "$scripts_dir/check-release-copy.sh"

sed 's/## 0.1.0 beta candidate draft/## 9.9.9 beta candidate draft/' "$release_notes_fixture_path" > "$tmp_dir/release-notes-version-mismatch.md"
expect_failure \
  release-copy-version-mismatch \
  "release notes missing required copy: ## 0.1.0 beta candidate draft" \
  env \
  FERMO_RELEASE_NOTES_PATH="$tmp_dir/release-notes-version-mismatch.md" \
  FERMO_TOOLARY_COPY_PATH="$toolary_copy_fixture_path" \
  FERMO_TOOLARY_METADATA_PATH="$metadata_fixture_path" \
  "$scripts_dir/check-release-copy.sh"

metadata_short_description_mismatch_path="$tmp_dir/toolary-copy-metadata-short-description-mismatch.json"
/usr/bin/ruby -rjson -e '
  source_path = ARGV.fetch(0)
  output_path = ARGV.fetch(1)
  data = JSON.parse(File.read(source_path))
  data["locales"]["en"]["shortDescription"] = "Changed catalog short description."
  File.write(output_path, JSON.pretty_generate(data))
' "$metadata_fixture_path" "$metadata_short_description_mismatch_path"

expect_failure \
  release-copy-metadata-short-description-mismatch \
  "Toolary beta copy missing required copy: Changed catalog short description." \
  env \
  FERMO_RELEASE_NOTES_PATH="$release_notes_fixture_path" \
  FERMO_TOOLARY_COPY_PATH="$toolary_copy_fixture_path" \
  FERMO_TOOLARY_METADATA_PATH="$metadata_short_description_mismatch_path" \
  "$scripts_dir/check-release-copy.sh"

write_xcode_project_fixture
expect_failure \
  xcode-project-rejects-extra-args \
  "usage:" \
  "$scripts_dir/check-xcode-entitlements.sh" "$xcode_project_fixture_path"

expect_success \
  xcode-project-version-match \
  env FERMO_XCODE_PROJECT_PATH="$xcode_project_fixture_path" \
  "$scripts_dir/check-xcode-entitlements.sh"

awk '
  !changed && /CURRENT_PROJECT_VERSION = 3;/ {
    sub(/CURRENT_PROJECT_VERSION = 3;/, "CURRENT_PROJECT_VERSION = 4;")
    changed = 1
  }
  { print }
' "$xcode_project_fixture_path" > "$tmp_dir/project-version-mismatch.pbxproj"

expect_failure \
  xcode-project-build-version-mismatch \
  "project has inconsistent CURRENT_PROJECT_VERSION values" \
  env FERMO_XCODE_PROJECT_PATH="$tmp_dir/project-version-mismatch.pbxproj" \
  "$scripts_dir/check-xcode-entitlements.sh"

sed 's/PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.appguard;/PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.guard;/g' "$xcode_project_fixture_path" > "$tmp_dir/project-bundle-id-mismatch.pbxproj"
expect_failure \
  xcode-project-appguard-bundle-id-mismatch \
  "FermoAppGuardExtension must use PRODUCT_BUNDLE_IDENTIFIER = com.toolary.fermo.appguard for Debug and Release" \
  env FERMO_XCODE_PROJECT_PATH="$tmp_dir/project-bundle-id-mismatch.pbxproj" \
  "$scripts_dir/check-xcode-entitlements.sh"

printf 'Release guardrails passed\n'
