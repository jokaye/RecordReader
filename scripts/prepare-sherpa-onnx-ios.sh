#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/sherpa-onnx-ios"
MODEL_BUILD_DIR="$ROOT_DIR/.build/sherpa-onnx-models"
RESOURCE_DIR="$ROOT_DIR/App/RecordReader/Resources/SherpaOnnxModels"
INCLUDE_SHERPA_MODELS="${INCLUDE_SHERPA_MODELS:-0}"

SHERPA_VERSION="1.12.36"
SHERPA_IOS_ARCHIVE="sherpa-onnx-v${SHERPA_VERSION}-ios.tar.bz2"
SHERPA_IOS_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/v${SHERPA_VERSION}/${SHERPA_IOS_ARCHIVE}"

PARAFORMER_ARCHIVE="sherpa-onnx-paraformer-zh-2023-09-14.tar.bz2"
PARAFORMER_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${PARAFORMER_ARCHIVE}"
PARAFORMER_DIR="sherpa-onnx-paraformer-zh-2023-09-14"

VAD_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx"

download() {
  local url="$1"
  local output="$2"
  if [[ -f "$output" ]]; then
    return
  fi
  curl --fail --location --retry 3 --retry-delay 2 "$url" --output "$output"
}

mkdir -p "$BUILD_DIR" "$MODEL_BUILD_DIR" "$RESOURCE_DIR"

if [[ ! -f "$BUILD_DIR/build-ios/sherpa-onnx.xcframework/Info.plist" ]]; then
  download "$SHERPA_IOS_URL" "$BUILD_DIR/$SHERPA_IOS_ARCHIVE"
  tar -xjf "$BUILD_DIR/$SHERPA_IOS_ARCHIVE" -C "$BUILD_DIR"
fi

if [[ "$INCLUDE_SHERPA_MODELS" == "1" ]]; then
  mkdir -p "$RESOURCE_DIR/paraformer-zh" "$RESOURCE_DIR/vad"

  if [[ ! -f "$RESOURCE_DIR/paraformer-zh/model.int8.onnx" || ! -f "$RESOURCE_DIR/paraformer-zh/tokens.txt" ]]; then
    download "$PARAFORMER_URL" "$MODEL_BUILD_DIR/$PARAFORMER_ARCHIVE"
    rm -rf "$MODEL_BUILD_DIR/$PARAFORMER_DIR"
    tar -xjf "$MODEL_BUILD_DIR/$PARAFORMER_ARCHIVE" -C "$MODEL_BUILD_DIR"
    cp "$MODEL_BUILD_DIR/$PARAFORMER_DIR/model.int8.onnx" "$RESOURCE_DIR/paraformer-zh/model.int8.onnx"
    cp "$MODEL_BUILD_DIR/$PARAFORMER_DIR/tokens.txt" "$RESOURCE_DIR/paraformer-zh/tokens.txt"
  fi

  if [[ ! -f "$RESOURCE_DIR/vad/silero_vad.onnx" ]]; then
    download "$VAD_URL" "$RESOURCE_DIR/vad/silero_vad.onnx"
  fi

  echo "sherpa-onnx iOS libraries and Chinese model resources are ready."
else
  rm -rf "$RESOURCE_DIR/paraformer-zh" "$RESOURCE_DIR/vad"
  echo "sherpa-onnx iOS libraries are ready; Chinese model resources are excluded."
fi
