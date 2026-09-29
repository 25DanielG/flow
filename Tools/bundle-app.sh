#!/bin/bash
# builds FlowApp into a signed Flow.app. needs a real bundle id for TCC to keep grants
# builds in $FLOW_SCRATCH_PATH, not here. icloud re-tags files and codesign chokes
#
# Usage:
#   ./Tools/bundle-app.sh            # debug
#   ./Tools/bundle-app.sh --release

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/Tools/env.sh"

CONFIG="debug"
if [[ "${1:-}" == "--release" ]]; then
    CONFIG="release"
fi

IDENTITY_NAME="Flow Dev Signing"
APP_NAME="Flow"
BUNDLE_ID="com.flow.dictation"
APP_DIR="$FLOW_SCRATCH_PATH/$APP_NAME.app"
BINARY_NAME="FlowApp"

echo "==> Building ($CONFIG)..."
if [[ "$CONFIG" == "release" ]]; then
    swift build -c release --product FlowApp --scratch-path "$FLOW_SCRATCH_PATH"
    BUILT_BINARY="$FLOW_SCRATCH_PATH/release/$BINARY_NAME"
else
    swift build --product FlowApp --scratch-path "$FLOW_SCRATCH_PATH"
    BUILT_BINARY="$FLOW_SCRATCH_PATH/debug/$BINARY_NAME"
fi

echo "==> Assembling $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILT_BINARY" "$APP_DIR/Contents/MacOS/$BINARY_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "==> Signing..."
xattr -cr "$APP_DIR"
ENTITLEMENTS="$ROOT_DIR/Resources/Flow.entitlements"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    # hardened runtime needs the audio-input entitlement or mic prompt never shows
    codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY_NAME" "$APP_DIR"
    echo "Signed with stable identity '$IDENTITY_NAME' — TCC grants will survive rebuilds."
else
    codesign --force --deep --entitlements "$ENTITLEMENTS" --sign - "$APP_DIR"
    echo "WARNING: '$IDENTITY_NAME' not found — signed ad-hoc instead."
    echo "         TCC grants (Accessibility/Input Monitoring/Microphone) will NOT persist"
    echo "         across rebuilds until you run Tools/create-signing-identity.sh once."
fi

echo
echo "==> Built: $APP_DIR"
echo "    Bundle ID: $BUNDLE_ID"
echo "    Run:  open \"$APP_DIR\""
echo "    Or:   \"$APP_DIR/Contents/MacOS/$BINARY_NAME\"  (to see stdout/stderr in-terminal)"
