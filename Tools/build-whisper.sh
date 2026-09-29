#!/bin/bash
# builds whisper.cpp into one static lib for CWhisper. cmake + libtool, no xcodebuild needed
# coreml fallback on so it works w/o the .mlmodelc
#
# Usage: ./Tools/build-whisper.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/Tools/env.sh"

WHISPER_DIR="$ROOT_DIR/vendor/whisper.cpp"
BUILD_DIR="$WHISPER_DIR/build-flow"
LIB_OUT_DIR="$ROOT_DIR/vendor/whisper-libs"
HEADER_OUT_DIR="$ROOT_DIR/Sources/CWhisper/include"

if [ ! -d "$WHISPER_DIR" ]; then
    echo "==> Cloning whisper.cpp..."
    git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
fi

echo "==> Configuring (Core ML enabled with CPU/Metal fallback, Metal on, OpenMP off)..."
cmake -S "$WHISPER_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_COREML=1 \
    -DWHISPER_COREML_ALLOW_FALLBACK=1 \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DGGML_BLAS_DEFAULT=ON \
    -DGGML_OPENMP=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF

echo "==> Building..."
cmake --build "$BUILD_DIR" --config Release -j"$(sysctl -n hw.ncpu)"

echo "==> Combining static libraries..."
mkdir -p "$LIB_OUT_DIR"
STATIC_LIBS=$(find "$BUILD_DIR" -name "*.a")
if [ -z "$STATIC_LIBS" ]; then
    echo "No static libraries found under $BUILD_DIR" >&2
    exit 1
fi
# shellcheck disable=SC2086
libtool -static -o "$LIB_OUT_DIR/libwhisper-combined.a" $STATIC_LIBS
echo "    -> $LIB_OUT_DIR/libwhisper-combined.a"

echo "==> Copying public headers..."
mkdir -p "$HEADER_OUT_DIR"
rm -f "$HEADER_OUT_DIR"/*.h
cp "$WHISPER_DIR/include/whisper.h" "$HEADER_OUT_DIR/whisper.h"
# only whisper.h's includes, ggml-cpp.h etc break the c module build
for h in ggml.h ggml-cpu.h ggml-backend.h ggml-alloc.h; do
    cp "$WHISPER_DIR/ggml/include/$h" "$HEADER_OUT_DIR/$h"
done

echo
echo "Done. Next: ./Tools/download-model.sh small.en"
