#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: ./scripts/package-preview-release.sh VERSION}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData-Release}"
DIST_DIR="${DIST_DIR:-dist}"
APP_PATH="$DERIVED_DATA/Build/Products/Release/MicFirst.app"
ZIP_PATH="$DIST_DIR/MicFirst-$VERSION-macos-arm64.zip"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project MicFirst.xcodeproj \
  -scheme MicFirst \
  -configuration Release \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "Created $ZIP_PATH"
echo "Created $ZIP_PATH.sha256"
