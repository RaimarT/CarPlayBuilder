#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Raimar Tasche
# SPDX-License-Identifier: MIT

# Run the same checks locally and on GitHub-hosted macOS runners.
set -euo pipefail
cd "$(dirname "$0")/../.."

check_format() {
  local expected
  expected="$(cat .swiftformat-version)"
  if [[ "$(swiftformat --version)" != "$expected" ]]; then
    echo "SwiftFormat $expected is required; see .swiftformat-version." >&2
    return 1
  fi
  swiftformat --lint Package.swift Sources Tests --cache ignore
}

run_tests() {
  local workspace=".swiftpm/xcode/package.xcworkspace"
  local simulator_id
  mkdir -p "$workspace"
  if [[ ! -f "$workspace/contents.xcworkspacedata" ]]; then
    cat > "$workspace/contents.xcworkspacedata" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
    <FileRef location="self:"></FileRef>
</Workspace>
XML
  fi
  simulator_id="$(xcrun simctl list devices available --json | \
    python3 .github/scripts/select-simulator.py)"
  xcrun simctl bootstatus "$simulator_id" -b
  xcodebuild test \
    -workspace "$workspace" \
    -scheme CarPlayBuilder \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$output/DerivedData" \
    -resultBundlePath "$output/TestResults.xcresult" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO
}

build_docs() {
  local sdk
  sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
  mkdir -p "$output/SymbolGraphs"
  swift build \
    --scratch-path "$output/DocumentationBuild" \
    --triple "$(uname -m)-apple-ios17.0-simulator" \
    --sdk "$sdk" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir \
    -Xswiftc "$output/SymbolGraphs"
  xcrun docc convert Sources/CarPlayBuilder/CarPlayBuilder.docc \
    --additional-symbol-graph-dir "$output/SymbolGraphs" \
    --output-dir "$output/CarPlayBuilder.doccarchive" \
    --warnings-as-errors
  # DocC symbol filenames contain colons, which artifact uploads reject.
  COPYFILE_DISABLE=1 tar -czf "$output/CarPlayBuilder.doccarchive.tar.gz" \
    -C "$output" CarPlayBuilder.doccarchive
}

output="${2:-$(mktemp -d "${TMPDIR:-/tmp}/CarPlayBuilder-CI.XXXXXX")}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
printf 'CI output: %s\n' "$output"

case "${1:-}" in
  format) check_format ;;
  test) run_tests ;;
  docs) build_docs ;;
  *) echo "Usage: bash .github/scripts/ci.sh {format|test|docs} [output-dir]" >&2
     exit 2 ;;
esac
