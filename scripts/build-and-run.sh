#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MicFirst"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/MicFirst.app"
MODE="${1:---verify}"
HUD_OPTION="${2:-}"

case "$MODE" in
  --verify|--preview|--menu-symbol-review|--hud-preview|--diagnostics) ;;
  *) echo "Usage: $0 [--verify|--preview|--menu-symbol-review|--diagnostics|--hud-preview [--diagnostics]]" >&2; exit 2 ;;
esac

if [[ $# -gt 2 || ( -n "$HUD_OPTION" && ( "$MODE" != "--hud-preview" || "$HUD_OPTION" != "--diagnostics" ) ) ]]; then
  echo "HUD options are only available with --hud-preview." >&2
  exit 2
fi

if [[ "$MODE" != "--verify" && "$CONFIGURATION" != "Debug" ]]; then
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
# Do not mistake an exiting instance's PID for the app being launched below.
for ((attempt = 0; attempt < 100; attempt++)); do
  if ! pgrep -x MicFirst >/dev/null; then break; fi
  sleep 0.1
done
if pgrep -x MicFirst >/dev/null; then
  echo "The previous MicFirst instance did not exit within 10 seconds." >&2
  exit 1
fi
if [[ "$MODE" == "--hud-preview" ]]; then
  HUD_ARGS=(--priority-preview --hud-preview)
  if [[ "$HUD_OPTION" == "--diagnostics" ]]; then
    HUD_ARGS+=(--hud-diagnostics)
  fi
  open -n "$APP_PATH" --args "${HUD_ARGS[@]}"
elif [[ "$MODE" == "--preview" ]]; then
  open -n "$APP_PATH" --args --priority-preview
elif [[ "$MODE" == "--menu-symbol-review" ]]; then
  open -n "$APP_PATH" --args --priority-preview --menu-symbol-review
elif [[ "$MODE" == "--diagnostics" ]]; then
  open -n "$APP_PATH" --args --hud-diagnostics
else
  open -n "$APP_PATH"
fi

APP_PID=""
for ((attempt = 0; attempt < 100; attempt++)); do
  APP_PID="$(pgrep -x MicFirst | head -n 1 || true)"
  [[ -n "$APP_PID" ]] && break
  sleep 0.1
done
if [[ -z "$APP_PID" ]]; then
  echo "MicFirst did not start within 10 seconds." >&2
  exit 1
fi
printf '%s\n' "$APP_PID"
