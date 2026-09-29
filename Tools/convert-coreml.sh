#!/bin/bash
# converts encoder to coreml (ANE). needs py3.11 venv, default python is too new for coremltools
# prebuilt models on HF 401 now
#
# Usage: ./Tools/convert-coreml.sh [model-name]   (default: small.en)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHISPER_DIR="$ROOT_DIR/vendor/whisper.cpp"
MODEL="${1:-small.en}"
VENV_DIR="$ROOT_DIR/.coreml-venv"
PYTHON311="/opt/homebrew/bin/python3.11"

if [ ! -d "$WHISPER_DIR" ]; then
    echo "whisper.cpp not vendored yet — run ./Tools/build-whisper.sh first" >&2
    exit 1
fi
if [ ! -x "$PYTHON311" ]; then
    echo "python3.11 not found at $PYTHON311 — run: brew install python@3.11" >&2
    exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
    echo "==> Creating Python 3.11 venv at $VENV_DIR..."
    "$PYTHON311" -m venv "$VENV_DIR"
fi

echo "==> Installing conversion dependencies (torch, coremltools, openai-whisper, ane_transformers)..."
"$VENV_DIR/bin/pip" install --upgrade pip -q
"$VENV_DIR/bin/pip" install -r "$WHISPER_DIR/models/requirements-coreml.txt" -q

echo "==> Converting $MODEL encoder to Core ML (this can take several minutes)..."
cd "$WHISPER_DIR"
PATH="$VENV_DIR/bin:$PATH" ./models/generate-coreml-model.sh "$MODEL"

echo
echo "Done. Core ML encoder at: $WHISPER_DIR/models/ggml-$MODEL-encoder.mlmodelc"
echo "whisper.cpp picks it up automatically next time the app loads the model — no code change needed."
