# M17: sherpa-onnx 端上中文字幕识别

## Goal

RecordReader must generate Chinese subtitles from the selected audio file on the iPhone itself. The primary engine is sherpa-onnx with the Paraformer Chinese int8 model. Apple Speech remains a fallback only when the local engine cannot run or cannot decode the file.

## Scope

- iPhone-only SwiftUI app.
- Selected audio file recognition only; no microphone, speaker, or headphone capture.
- Input files continue to come from the existing document picker and library scanner.
- Supported playback/import formats stay unchanged.
- Subtitles keep using the existing `SubtitleDocument` and `SubtitleSegment` storage model.

Out of scope:

- Server ASR APIs.
- GLM-ASR Python/PyTorch integration.
- Qwen3-ASR high-quality mode.
- SRT/VTT export.
- Batch subtitle jobs.

## Architecture

`SherpaOnnxTranscriber` is an app-target actor. It owns the sherpa-onnx recognizer and VAD instances, validates bundled model resources, decodes the selected file to 16 kHz mono Float PCM with AVFoundation, runs VAD, and maps recognized speech windows to `SubtitleSegment`.

`AudioLibraryViewModel.recognizeSubtitleForSelectedRecording()` sets subtitle state to `recognizing`, calls `SherpaOnnxTranscriber`, and persists `.ready` or `.failed` through the existing metadata path. If sherpa-onnx throws, it calls the existing `SpeechTranscriber` fallback and combines both errors if fallback also fails.

The app target vendors sherpa-onnx's Swift C-API wrapper and uses a bridging header for `sherpa-onnx/c-api/c-api.h`. GitHub Actions runs `scripts/prepare-sherpa-onnx-ios.sh` before `xcodegen generate`; the script downloads the iOS xcframeworks, Paraformer Chinese int8 model, and Silero VAD model. Model binaries are ignored by git and bundled into the IPA during cloud builds.

## Error Handling

The local engine fails fast for missing model resources, unreadable files, empty audio, invalid VAD configuration, audio conversion failure, and no speech detected. User-facing messages remain Chinese and actionable. If Apple Speech fallback also fails, the final subtitle error includes both the local-engine error and the fallback error.

## Verification

- Run `scripts/prepare-sherpa-onnx-ios.sh`.
- Run `xcodegen generate`.
- Run `swift test` where a full Xcode/SDK is available.
- Cloud Actions must build simulator and unsigned device IPA.
- After a successful cloud build, download `RecordReader-unsigned.ipa` into `.build/github-artifacts/`.
- Manual iPhone gate: import MP3/M4A, play it, run subtitle recognition offline, confirm subtitles come from the selected file and Apple Speech permission is only needed when fallback is triggered.
