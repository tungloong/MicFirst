#!/usr/bin/env bash
# Build a universal Developer ID app, notarize it, then produce a notarized DMG.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: SIGNING_IDENTITY='Developer ID Application: …' NOTARY_PROFILE=… ./scripts/package-signed-release.sh 1.0.0 [BUILD_NUMBER]}"
BUILD_NUMBER="${2:-1}"
: "${SIGNING_IDENTITY:?Set a Developer ID Application signing identity}"
: "${NOTARY_PROFILE:?Set the name of a notarytool keychain profile}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version must be numeric MAJOR.MINOR.PATCH' >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'Build number must be a positive integer' >&2; exit 1; }
[[ "$SIGNING_IDENTITY" == 'Developer ID Application: '* ]] || { echo 'Direct distribution requires Developer ID Application' >&2; exit 1; }
security find-identity -v -p codesigning | grep -F -- "\"$SIGNING_IDENTITY\"" >/dev/null || { echo 'Signing identity and private key are not available' >&2; exit 1; }
# Validate stored credentials before spending time on the build. Never print secrets.
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
DIST_DIR="$ROOT_DIR/dist/$VERSION"
[[ ! -e "$DIST_DIR" ]] || { echo "Output already exists: $DIST_DIR" >&2; exit 1; }
mkdir -p "$DIST_DIR" "$ROOT_DIR/build"
STAGING="$(mktemp -d "$ROOT_DIR/build/release-staging.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/MicFirst.app"
DERIVED_DATA="$ROOT_DIR/build/DerivedData-SignedRelease"
xcodebuild -project "$ROOT_DIR/MicFirst.xcodeproj" -scheme MicFirst \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS='--timestamp' build

ditto "$DERIVED_DATA/Build/Products/Release/MicFirst.app" "$APP"
lipo "$APP/Contents/MacOS/MicFirst" -verify_arch arm64 x86_64
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --verbose=4 "$APP" 2> "$DIST_DIR/signature.txt"
grep -F "Authority=$SIGNING_IDENTITY" "$DIST_DIR/signature.txt" >/dev/null
grep -F '(runtime)' "$DIST_DIR/signature.txt" >/dev/null
ditto -c -k --keepParent "$APP" "$STAGING/notarization.zip"
xcrun notarytool submit "$STAGING/notarization.zip" --keychain-profile "$NOTARY_PROFILE" \
  --wait --output-format json > "$DIST_DIR/app-notarization.json"
plutil -extract status raw "$DIST_DIR/app-notarization.json" | grep -x Accepted
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

PAYLOAD="$STAGING/payload"
mkdir "$PAYLOAD"
ditto "$APP" "$PAYLOAD/MicFirst.app"
ln -s /Applications "$PAYLOAD/Applications"
DMG="$DIST_DIR/MicFirst-$VERSION-macos-universal.dmg"
hdiutil create -volname "MicFirst $VERSION" -srcfolder "$PAYLOAD" -format UDZO "$DMG"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" \
  --wait --output-format json > "$DIST_DIR/dmg-notarization.json"
plutil -extract status raw "$DIST_DIR/dmg-notarization.json" | grep -x Accepted
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
hdiutil verify "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
ditto -c -k --keepParent "$APP" "$DIST_DIR/MicFirst-$VERSION-macos-universal.zip"
(cd "$DIST_DIR" && shasum -a 256 ./*.dmg ./*.zip > SHA256SUMS)
echo "Verified artifacts are ready in $DIST_DIR; this script does not upload them."
