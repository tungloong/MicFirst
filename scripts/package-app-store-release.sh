#!/usr/bin/env bash
# Archive MicFirst for the Mac App Store and export a local installer package.
# This does not upload the package or submit it for review.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED_BUNDLE_ID="com.tenglong.MicFirst"
TEAM_ID="25U9Y73TKD"
PROFILE_NAME="MicFirst Mac App Store"
DISTRIBUTION_IDENTITY="Apple Distribution: TENGLONG LI (${TEAM_ID})"
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: TENGLONG LI (${TEAM_ID})"
VERSION="${1:?Usage: ./scripts/package-app-store-release.sh 1.0.0 [BUILD_NUMBER]}"
BUILD_NUMBER="${2:-1}"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version must be numeric MAJOR.MINOR.PATCH' >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'Build number must be a positive integer' >&2; exit 1; }
[[ "$EXPECTED_BUNDLE_ID" != *AudioInputLocker* ]] || { echo 'Refusing the retired AudioInputLocker bundle ID.' >&2; exit 1; }

security find-identity -v -p codesigning | grep -F -- "\"$DISTRIBUTION_IDENTITY\"" >/dev/null \
  || { echo "No $DISTRIBUTION_IDENTITY identity with a private key is available" >&2; exit 1; }
security find-identity -v | grep -F -- "\"$INSTALLER_IDENTITY\"" >/dev/null \
  || { echo "No $INSTALLER_IDENTITY identity with a private key is available" >&2; exit 1; }

BUNDLE_ID="$(xcodebuild -project "$ROOT_DIR/MicFirst.xcodeproj" -scheme MicFirst -configuration Release -showBuildSettings 2>/dev/null | awk -F ' = ' '/PRODUCT_BUNDLE_IDENTIFIER =/ { print $2; exit }')"
[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || { echo "Refusing to package bundle ID '$BUNDLE_ID'. MicFirst uses $EXPECTED_BUNDLE_ID." >&2; exit 1; }

profile_matches() {
  local file="$1"
  local decoded
  decoded="$(security cms -D -i "$file" 2>/dev/null)" || return 1
  [[ "$decoded" == *"<string>${PROFILE_NAME}</string>"* ]] || return 1
  [[ "$decoded" == *"<string>${TEAM_ID}.${EXPECTED_BUNDLE_ID}</string>"* ]]
}

PROFILE_FILE=""
for dir in \
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
  "$HOME/Library/MobileDevice/Provisioning Profiles"
do
  [[ -d "$dir" ]] || continue
  for file in "$dir"/*; do
    [[ -f "$file" ]] || continue
    if profile_matches "$file"; then
      PROFILE_FILE="$file"
      break 2
    fi
  done
done
[[ -n "$PROFILE_FILE" ]] || { echo "Install the '$PROFILE_NAME' provisioning profile for $EXPECTED_BUNDLE_ID before packaging." >&2; exit 1; }

DIST_DIR="$ROOT_DIR/dist/$VERSION"
[[ ! -e "$DIST_DIR" ]] || { echo "Output already exists: $DIST_DIR" >&2; exit 1; }
mkdir -p "$DIST_DIR" "$ROOT_DIR/build"
ARCHIVE_PATH="$ROOT_DIR/build/appstore/MicFirst.xcarchive"
EXPORT_OPTIONS="$ROOT_DIR/packaging/ExportOptions-AppStore.plist"
rm -rf "$ARCHIVE_PATH"

echo "==> Archiving MicFirst $VERSION ($BUILD_NUMBER)"
xcodebuild \
  -project "$ROOT_DIR/MicFirst.xcodeproj" \
  -scheme MicFirst \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$ROOT_DIR/build/DerivedData-AppStore" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$DISTRIBUTION_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  "PROVISIONING_PROFILE_SPECIFIER=$PROFILE_NAME" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS='--timestamp' \
  archive

APP="$ARCHIVE_PATH/Products/Applications/MicFirst.app"
ARCHIVED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
[[ "$ARCHIVED_BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || { echo "Archive bundle ID is $ARCHIVED_BUNDLE_ID" >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --verbose=4 "$APP" 2> "$DIST_DIR/signature.txt"
grep -F "Authority=$DISTRIBUTION_IDENTITY" "$DIST_DIR/signature.txt" >/dev/null
grep -F '(runtime)' "$DIST_DIR/signature.txt" >/dev/null
codesign -d --entitlements :- "$APP" 2>/dev/null | grep -F 'com.apple.security.app-sandbox' >/dev/null
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -F 'com.apple.security.get-task-allow' >/dev/null; then
  echo 'Archive includes the development get-task-allow entitlement' >&2
  exit 1
fi

echo "==> Exporting a local installer package"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$DIST_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

PKG="$(find "$DIST_DIR" -maxdepth 1 -name '*.pkg' -print -quit)"
[[ -n "$PKG" ]] || { echo 'Export did not produce a package' >&2; exit 1; }
pkgutil --check-signature "$PKG" > "$DIST_DIR/pkg-signature.txt"
grep -F "$INSTALLER_IDENTITY" "$DIST_DIR/pkg-signature.txt" >/dev/null
echo "Local App Store package: $PKG"
echo "This script does not upload it."
