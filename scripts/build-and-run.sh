#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MicFirst"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/MicFirst.app"
MODE="${1:---verify}"

case "$MODE" in
  --verify|--preview) ;;
  *) echo "Usage: $0 [--verify|--preview]" >&2; exit 2 ;;
esac

if [[ "$MODE" == "--preview" && "$CONFIGURATION" != "Debug" ]]; then
  echo "The isolated UI preview requires a Debug build." >&2
  exit 2
fi

xcodebuild \
  -project "$ROOT_DIR/MicFirst.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

# Stop the previous product name too, so only one input guardian remains active.
pkill -x AudioInputLocker 2>/dev/null || true
pkill -x MicFirst 2>/dev/null || true
if [[ "$MODE" == "--preview" ]]; then
  open -n "$APP_PATH" --args --priority-preview
else
  open -n "$APP_PATH"
fi

sleep 1
pgrep -x MicFirst
