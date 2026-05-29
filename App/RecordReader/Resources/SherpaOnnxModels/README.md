Sherpa-onnx model files are prepared by `scripts/prepare-sherpa-onnx-ios.sh`.

The generated app bundle expects:

- `paraformer-zh/model.int8.onnx`
- `paraformer-zh/tokens.txt`
- `vad/silero_vad.onnx`

These binary model files are downloaded during cloud builds and are intentionally
not committed to git.
