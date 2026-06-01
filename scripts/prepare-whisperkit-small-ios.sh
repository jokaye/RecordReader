#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCE_DIR="$ROOT_DIR/App/RecordReader/Resources/WhisperKitModels"
MODEL_DIR="$RESOURCE_DIR/openai_whisper-small_216MB"

MODEL_REPO_URL="https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main/openai_whisper-small_216MB"
TOKENIZER_REPO_URL="https://huggingface.co/openai/whisper-small/resolve/main"

download() {
  local url="$1"
  local output="$2"
  if [[ -f "$output" ]]; then
    return
  fi
  mkdir -p "$(dirname "$output")"
  curl --fail --location --retry 3 --retry-delay 2 "$url" --output "$output"
}

download_model_file() {
  local relative_path="$1"
  download "$MODEL_REPO_URL/$relative_path" "$MODEL_DIR/$relative_path"
}

download_tokenizer_file() {
  local relative_path="$1"
  download "$TOKENIZER_REPO_URL/$relative_path" "$MODEL_DIR/$relative_path"
}

rm -rf "$MODEL_DIR"

model_files=(
  "AudioEncoder.mlmodelc/analytics/coremldata.bin"
  "AudioEncoder.mlmodelc/coremldata.bin"
  "AudioEncoder.mlmodelc/metadata.json"
  "AudioEncoder.mlmodelc/model.mil"
  "AudioEncoder.mlmodelc/model.mlmodel"
  "AudioEncoder.mlmodelc/weights/weight.bin"
  "MelSpectrogram.mlmodelc/analytics/coremldata.bin"
  "MelSpectrogram.mlmodelc/coremldata.bin"
  "MelSpectrogram.mlmodelc/metadata.json"
  "MelSpectrogram.mlmodelc/model.mil"
  "MelSpectrogram.mlmodelc/weights/weight.bin"
  "TextDecoder.mlmodelc/analytics/coremldata.bin"
  "TextDecoder.mlmodelc/coremldata.bin"
  "TextDecoder.mlmodelc/metadata.json"
  "TextDecoder.mlmodelc/model.mil"
  "TextDecoder.mlmodelc/model.mlmodel"
  "TextDecoder.mlmodelc/weights/weight.bin"
  "config.json"
  "generation_config.json"
)

tokenizer_files=(
  "added_tokens.json"
  "merges.txt"
  "normalizer.json"
  "special_tokens_map.json"
  "tokenizer.json"
  "tokenizer_config.json"
  "vocab.json"
)

for relative_path in "${model_files[@]}"; do
  download_model_file "$relative_path"
done

for relative_path in "${tokenizer_files[@]}"; do
  download_tokenizer_file "$relative_path"
done

echo "WhisperKit Small 216MB CoreML model and tokenizer resources are ready."
