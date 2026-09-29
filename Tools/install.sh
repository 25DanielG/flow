#!/bin/bash
# builds Flow.app, installs to /Applications and relaunches
# TCC grants carry over if same signing identity
#
# Usage: ./Tools/install.sh [--release]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./Tools/bundle-app.sh "$@"
source "$ROOT_DIR/Tools/env.sh"

SOURCE_APP="$FLOW_SCRATCH_PATH/Flow.app"
DEST_APP="/Applications/Flow.app"

echo "==> Stopping any running copy..."
pkill -f "Flow.app/Contents/MacOS/FlowApp" 2>/dev/null || true
sleep 1

echo "==> Installing to $DEST_APP..."
rm -rf "$DEST_APP"
cp -R "$SOURCE_APP" "$DEST_APP"

echo "==> Launching $DEST_APP..."
open "$DEST_APP"

echo
echo "Done. Flow is running from $DEST_APP — look for the soundwave icon in your Dock."
