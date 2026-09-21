#!/usr/bin/env bash
# Build a Mac App Store package for MicFirst and upload it to App Store Connect.
#
# Requires an existing App Store Connect app record for the bundle ID and a
# logged-in asc session with an API key. The app record cannot be created
# through the public API; see docs/app-store/release-plan.md.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_ID="${APP_ID:?Set APP_ID to the App Store Connect app ID}"
VERSION="${1:?Usage: APP_ID=123456789 ./scripts/package-app-store-release.sh 1.0.0 [BUILD_NUMBER]}"
BUILD_NUMBER="${2:-1}"
TEAM_ID="${TEAM_ID:-25U9Y73TKD}"
SUBMIT="${SUBMIT:-0}"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version must be numeric MAJOR.MINOR.PATCH' >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'Build number must be a positive integer' >&2; exit 1; }

# Fail before building if the signing identity is missing. The App Store
# identity is Apple Distribution, not Developer ID Application.
SIGNING_IDENTITY="Apple Distribution"
security find-identity -v -p codesigning | grep -F -- "$SIGNING_IDENTITY" >/dev/null \
  || { echo "No $SIGNING_IDENTITY identity with a private key is available" >&2; exit 1; }

WORK_DIR="build/appstore"
ARCHIVE_PATH="$WORK_DIR/MicFirst.xcarchive"
PKG_PATH="$WORK_DIR/MicFirst.pkg"
OPTIONS_PATH="$WORK_DIR/ExportOptions.plist"
mkdir -p "$WORK_DIR"

echo "==> Archiving MicFirst $VERSION ($BUILD_NUMBER)"
asc xcode archive \
  --project MicFirst.xcodeproj \
  --scheme MicFirst \
  --configuration Release \
  --archive-path "$ARCHIVE_PATH" \
  --overwrite \
  --xcodebuild-flag=MARKETING_VERSION="$VERSION" \
  --xcodebuild-flag=CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

echo "==> Generating App Store export options"
asc xcode export-options generate \
  --archive-path "$ARCHIVE_PATH" \
  --method app-store-connect \
  --destination upload \
  --signing-style manual \
  --team-id "$TEAM_ID" \
  --output-path "$OPTIONS_PATH" \
  --overwrite

echo "==> Exporting an installer package"
asc xcode export \
  --archive-path "$ARCHIVE_PATH" \
  --export-options "$OPTIONS_PATH" \
  --pkg-path "$PKG_PATH" \
  --overwrite

echo "==> Uploading"
PUBLISH_ARGS=(--app "$APP_ID" --pkg "$PKG_PATH" --version "$VERSION" --build-number "$BUILD_NUMBER" --platform MAC_OS --wait)
if [[ "$SUBMIT" == "1" ]]; then
  PUBLISH_ARGS+=(--submit --confirm)
fi
asc publish appstore "${PUBLISH_ARGS[@]}"

echo "Uploaded MicFirst $VERSION ($BUILD_NUMBER) to app $APP_ID."
echo "Check submission readiness with: asc validate --app $APP_ID --version $VERSION"
