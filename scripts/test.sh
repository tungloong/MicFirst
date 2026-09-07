#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xcodebuild \
  -project "$ROOT_DIR/MicFirst.xcodeproj" \
  -scheme MicFirst \
  -configuration Debug \
  -destination "${DESTINATION:-platform=macOS,arch=arm64}" \
  -derivedDataPath "$ROOT_DIR/build/DerivedData" \
  test
