#!/bin/bash
# downloads a ggml whisper model, default small.en (medium doesn't fit in memory next to the sidecar)
#
# Usage: ./Tools/download-model.sh [model-name]   (default: small.en)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHISPER_DIR="$ROOT_DIR/vendor/whisper.cpp"
MODEL="${1:-small.en}"

if [ ! -d "$WHISPER_DIR" ]; then
    echo "whisper.cpp not vendored yet — run ./Tools/build-whisper.sh first" >&2
    exit 1
fi

bash "$WHISPER_DIR/models/download-ggml-model.sh" "$MODEL"

echo
echo "Model at: $WHISPER_DIR/models/ggml-$MODEL.bin"
echo "Next (optional, for Core ML acceleration): ./Tools/convert-coreml.sh $MODEL"
