# RecordReader Milestones

## Checkpoint Log

### 2026-05-27 M0: Repository Baseline

Status: complete.

Evidence:

- Current workspace: `/Users/bytedance/Documents/RecordReader`.
- Repository was empty except `.git`.
- Branch state: `main` with no commits.
- Local Xcode is not installed; `xcodebuild -version` reports that the active developer directory is Command Line Tools.

Continuation:

- Treat this as a greenfield SwiftUI app. There is no previous app code to preserve.

### 2026-05-27 M1: Product Boundary and Design

Status: complete.

Output:

- `docs/superpowers/specs/2026-05-27-record-reader-design.md`

Decision:

- v1 is a lightweight local-first iPhone recording player.
- v1 uses Chinese UI copy.
- v1 uses iOS Speech framework with fixed `zh_CN` recognition for subtitle state and segment generation.
- SmartSub integration, Whisper.cpp/Core ML model management, translation, batch processing, desktop support, iPad-specific layout, and subtitle export are out of scope.
- The provided reference image informs dark player styling, but v1 does not use cover art.

Continuation:

- Preserve the player-first UI. Do not convert the first screen into a generic file manager.
- Preserve the Chinese-only, iPhone-only, lightweight scope unless the user explicitly expands it.

### 2026-05-27 M2: Implementation Plan

Status: complete.

Output:

- `docs/superpowers/plans/2026-05-27-record-reader.md`

Continuation:

- Use the plan's file map to continue. The remaining external gate is cloud build verification.

### 2026-05-27 M3: Core Package

Status: implemented, local compile blocked by environment.

Output:

- `Package.swift`
- `Sources/RecordReaderCore/Recording.swift`
- `Sources/RecordReaderCore/RecordingLibraryMetadata.swift`
- `Sources/RecordReaderCore/RecordingLibraryScanner.swift`
- `Sources/RecordReaderCore/RecordingMetadataStore.swift`
- `Tests/RecordReaderCoreTests/RecordingLibraryScannerTests.swift`
- `Tests/RecordReaderCoreTests/RecordingMetadataStoreTests.swift`

Validation attempted:

```bash
swift test
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk swift test
```

Observed result:

Both commands fail before compiling project code:

```text
xcrun: error: unable to lookup item 'PlatformPath' from command line tools installation
```

Continuation:

- Re-run `swift test` in GitHub Actions or on a Mac with full Xcode selected.

### 2026-05-27 M4: SwiftUI App Shell

Status: implemented, cloud build pending.

Output:

- `App/RecordReader/RecordReaderApp.swift`
- `App/RecordReader/ContentView.swift`
- `App/RecordReader/RecordingLibrarySheet.swift`
- `App/RecordReader/SubtitlePanel.swift`
- `App/RecordReader/AudioLibraryViewModel.swift`
- `App/RecordReader/PlayerController.swift`
- `App/RecordReader/SpeechTranscriber.swift`

Implemented behavior:

- Folder picker.
- Recording list sheet.
- All/favorites/category filters.
- Player-first dark UI.
- Favorite toggle.
- Category editor.
- Playback control.
- Subtitle recognition action and status display.

Continuation:

- First run should be through CI because the local machine cannot build iOS targets.

### 2026-05-27 M5: Cloud Build Setup

Status: implemented, remote execution pending.

Output:

- `project.yml`
- `.github/workflows/ios.yml`
- `.gitignore`

Workflow:

1. Select full Xcode.
2. Install XcodeGen.
3. Run `swift test`.
4. Generate `RecordReader.xcodeproj`.
5. Run simulator `xcodebuild` with signing disabled.

Local validation:

- Installed XcodeGen with `brew install xcodegen`.
- `xcodegen generate` succeeded and created `RecordReader.xcodeproj`.
- Local `xcodebuild` still fails before project compilation because the machine only has Command Line Tools selected, not full Xcode.

Continuation:

- Push to GitHub or trigger Actions manually.
- If CI fails, update this file with the failing step, exact error, and fix.

## Next Checkpoint

Run the GitHub Actions workflow and record the result under a new `M7: Cloud Verification` section.

### 2026-05-27 M6: Lightweight Chinese Scope Tightening

Status: implemented, cloud build pending.

User direction:

- Continue with the lightest phone-only approach.
- Do not require SmartSub's subtitle recognition architecture.
- Chinese support is enough.

Changes:

- UI strings changed to Chinese.
- Speech recognition now only creates `SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))`.
- Removed fallback to the system default speech recognizer.
- Permission strings and docs now describe Chinese-only iPhone scope.

Continuation:

- Keep the app lightweight. Do not add SmartSub, Whisper, translation, server APIs, or desktop targets unless the user explicitly changes scope.

### 2026-05-27 M7: Compile Attempt

Status: blocked by environment for full iOS build; local generation and syntax checks passed.

Commands run:

```bash
xcodegen generate
xcodebuild -project RecordReader.xcodeproj -scheme RecordReader -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
gh auth status
swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift
swiftc -parse App/RecordReader/*.swift
git diff --check
ruby -e 'require "yaml"; YAML.load_file("project.yml"); YAML.load_file(".github/workflows/ios.yml"); puts "yaml ok"'
```

Results:

- `xcodegen generate` succeeded and created `RecordReader.xcodeproj`.
- `swiftc -parse` succeeded for Core, Tests, and App Swift files.
- `git diff --check` succeeded.
- YAML parsing succeeded.
- `xcodebuild` failed before project compilation because this machine only has Command Line Tools selected, not full Xcode.
- `gh auth status` reports no GitHub login.
- `git remote -v` has no configured remote.

Continuation:

- To run cloud compile, add a GitHub remote and authenticate `gh`, then push and trigger `.github/workflows/ios.yml`.
- If a remote is added later, run `gh workflow run iOS` or push to `main`, then record the workflow result under `M8: Cloud Verification`.

### 2026-05-27 M8: Cloud Verification

Status: first cloud compile passed.

Remote:

- `origin`: `git@github.com:jokaye/RecordReader.git`
- Commit: `9d210f0 first commit`
- Workflow run: `iOS #1`

GitHub result:

- Trigger: push to `main`.
- Status: Success.
- Duration: 1m 37s.
- Job: `build`.

Warning:

- GitHub reported `actions/checkout@v4` uses Node.js 20 and should move to a newer runtime before GitHub's Node 20 deprecation takes effect.

Follow-up result:

- Updated `.github/workflows/ios.yml` to use `actions/checkout@v5`, which supports Node.js 24.
- Commit: `628cb1c ci: use node 24 checkout action`
- Workflow run: `iOS #2`
- Status: Success.
- Duration: 1m 19s.
- The Node.js 20 checkout warning did not appear on the second run.

### 2026-05-28 M9: Direct Audio Import Review

Status: implemented and cloud verified.

User report:

- Another IDE completed most UI and feature work.
- iOS recordings and MP3 files still appeared unsupported.
- Subtitle recognition support needed review.

Findings:

- Scanner support for MP3 and common iOS/AVFoundation extensions exists in `RecordingLibraryScanner.defaultSupportedExtensions`.
- The user-facing importer still only accepted `.folder`, so a standalone MP3 or Voice Memos export could not be picked directly.
- Subtitle recognition is wired through `SFSpeechURLRecognitionRequest` with fixed `zh_CN`; it can process recorded audio files available as local file URLs, subject to iOS Speech permission and recognizer availability.

Fix:

- `ContentView.fileImporter` now accepts `.folder` and `.audio`, with multiple selection enabled.
- `AudioLibraryViewModel` now tracks selected source URLs instead of only one selected folder.
- `RecordingLibraryScanner` now exposes `scan(urls:metadata:)` so direct audio file imports and folder imports share the same metadata/playback/subtitle model.
- Added a scanner regression test for direct `.MP3` and `.m4a` selections.

Cloud result:

- Commit `e55e1d4` failed in `swift test`.
- Cause: the new direct-file test asserted a specific Chinese localized sort order. CI returned the same recordings in a different valid localized order.
- Fix: assert direct-file import by sets for titles/extensions, keeping the test focused on MP3/iOS recording support instead of locale-specific sorting.
- Commit `f260adb` passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26559368718`
- Duration: 1m 16s.
- Artifact: `RecordReader-unsigned-ipa`, artifact id `7259423123`, digest `sha256:4507bb43626235323e3e20488af6427157854772e076c2d2f558ee1e7f016b30`.

### 2026-05-28 M10: Device Validation, Seek, and Speech Failure Detail

Status: implemented and cloud verified.

User direction:

- Implement true-device usability validation.
- Add draggable seek on the playback progress bar.
- Make subtitle recognition failure messages more specific.
- The app must recognize subtitles itself; users should not have to provide subtitle files.

Changes:

- Replaced read-only playback progress with a draggable `Slider`.
- Added `PlayerController.seek(toProgress:)`.
- `SpeechTranscriber` now validates file readability before recognition.
- Speech authorization failures now distinguish denied, restricted, not determined, and unknown states.
- Recognition failures now distinguish unavailable recognizer, no speech detected, timeout, and system recognition errors.
- Speech requests use `.dictation` hint and punctuation when available.
- Added `docs/device-validation.md` with iPhone validation steps for MP3, iOS recordings, playback seek, and app-generated Chinese subtitles.

Cloud result:

- Commit `eff3390` passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26559685879`
- Duration: 1m 51s.
- Artifact: `RecordReader-unsigned-ipa`, artifact id `7259555941`, digest `sha256:b2b834bd3e8b54577425f2c1f3f7eb909b7fd4d554ffbf2bc4d1cdd058b86ca3`.

Remaining manual gate:

- Run `docs/device-validation.md` on a real iPhone. CI cannot validate iOS file picker security scope, audio playback hardware behavior, user speech permissions, or live iOS Speech recognition service behavior.

### 2026-05-28 M11: Playback Queue, Search, Sort, and Batch Management

Status: implemented and cloud verified.

User direction:

- Add previous / next / continuous playback.
- Add search, sorting, and batch management.

Changes:

- Added `RecordingListQuery` in Core for visible recording calculation and queue navigation.
- Added Core tests for filtering, search, sorting, and previous/next queue behavior.
- `AudioLibraryViewModel` now exposes `visibleRecordings`, `searchText`, `sort`, `selectPrevious()`, `selectNext()`, batch favorite, and batch category updates.
- Player now supports a finish callback; the app auto-selects and plays the next visible recording when playback ends.
- Main player now has previous and next buttons.
- Recording list now supports search, sort menu, and selection mode.
- Batch actions support favorite, unfavorite, set category, and clear category.

Verification:

- Local `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift && swiftc -parse App/RecordReader/*.swift` passed.
- Local `xcodegen generate` passed.
- Local `git diff --check` passed.
- Local `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud result:

- Commit `874a63d` failed in the iOS app build after Core tests passed.
- Cause: the batch selection checkmark used `.accent`, which is not a valid `ShapeStyle`.
- Fix: commit `cc00bcf` replaced the selection tint with explicit `Color.accentColor` and simplified the playback timer state sync.
- Commit `cc00bcf` passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26562654407`
- Artifact: `RecordReader-unsigned-ipa`, artifact id `7260778818`, digest `sha256:1eeba19c0a119e7d3b28fb84f29714cc5cd3bc60b5d1c633e258c1e21a472cd6`.

Remaining manual gate:

- Re-run `docs/device-validation.md` on a real iPhone after installing the latest unsigned IPA. CI cannot validate real file picker security scope, Bluetooth/speaker playback behavior, iOS Speech service availability, or user permission flows.

### 2026-05-28 M12: Folder Import Loading Fix

Status: implemented and cloud verified.

User report:

- After choosing a folder, the app stayed in loading.

Root-cause analysis:

- The import UI used one `fileImporter` for both `.folder` and `.audio` with multiple selection enabled.
- That mixed mode is fragile on iOS Files for folder selection, and it also made the app unable to show a clear scan/error state after the picker returned.

Changes:

- Split folder import and audio-file import into two dedicated `fileImporter` modifiers.
- Folder import now allows only one `.folder` selection.
- Audio import keeps multiple `.audio` selection.
- Added an import chooser so users explicitly pick "录音文件夹" or "音频文件".
- Added `AudioLibraryViewModel.isLoading` and empty-state loading/error messaging.

Verification:

- Local `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift && swiftc -parse App/RecordReader/*.swift` passed.
- Local `xcodegen generate` passed.
- Local `git diff --check` passed.
- Local `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud result:

- Commit `87ed438` passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26563279973`
- Artifact: `RecordReader-unsigned-ipa`, artifact id `7261047271`, digest `sha256:f1f031fe18e43aaaba89a7cf4d157b9f68b80774ce1f930d5646fa5297dee59b`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-28 16:21:29 +0800`.

Remaining manual gate:

- Re-test folder selection on a real iPhone. CI can compile the importer code but cannot drive the iOS Files folder picker.

### 2026-05-28 M13: Import, Playback, Queue, Volume, and Subtitle Hardening

Status: implemented and cloud verified.

User report:

- Selecting audio and tapping Open still appeared to do nothing.
- The folder import button also appeared to do nothing.
- Re-check file opening, playback, previous/next, volume, and generated subtitles seriously.

Root-cause analysis:

- Import selection after scanning used `visibleRecordings`, so an existing favorites/category filter or stale search text could hide newly imported ordinary audio and make the UI appear unchanged.
- The import chooser introduced in M12 still required one modal presentation to trigger another file importer presentation, which is fragile on iOS.
- Playback did not check `prepareToPlay()` or `play()` return values, so a failed play attempt could look like playback started.
- Speech recognition relied on the library-level security scope, but the transcriber itself did not hold a security-scoped URL while the async recognition task was running.

Changes:

- Removed the import chooser. Folder import and audio import are now direct buttons.
- Added a visible audio import button in the header and a separate "选择音频" button in the empty state.
- Added `RecordingListQuery.initialSelectionAfterImport` and a Core regression test so import selection ignores stale filters/search.
- Import now resets filter to all and clears search text before selecting the first imported recording.
- Empty imports now show a clear "没有找到支持的录音文件" message.
- Playback now sets `AVAudioPlayer.volume = 1.0`, validates `prepareToPlay()`, validates `play()`, and surfaces a clear failure message if playback cannot start.
- Subtitle recognition now starts and releases its own security-scoped URL access around the async speech task.
- If Speech returns only formatted text and no segment timings, the app now still creates a subtitle segment instead of showing an empty ready state.
- Updated `docs/device-validation.md` with direct folder/audio buttons and volume checks.

Verification:

- Local Core typecheck probe for `initialSelectionAfterImport` passed.
- Local `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift && swiftc -parse App/RecordReader/*.swift` passed.
- Local `xcodegen generate` passed.
- Local `git diff --check` passed.
- Local `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud result:

- Commit `ab75a6a` failed in Core tests because the new regression test depended on Chinese localized sort order.
- Commit `ae08f68` fixed the test data and passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26563821232`
- Artifact: `RecordReader-unsigned-ipa`, artifact id `7261272433`, digest `sha256:b8d5d49ee5286528f92571676f13b7ef915c9bf7155e9d9114d3b2a79b942e1e`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-28 16:32:48 +0800`.

Remaining manual gate:

- Re-test on a real iPhone: direct audio import, direct folder import, play with device volume up, previous/next with at least three recordings, continuous playback, and Chinese subtitle recognition. CI validates code/tests/builds but cannot drive the iOS Files picker, physical audio output, or live Speech service.

### 2026-05-28 M14: Direct Audio Open No-Op Fix

Status: implemented and cloud verified.

User report:

- Selecting an audio file and tapping Open still produced no visible result.

Root-cause analysis:

- `ContentView` still mounted two separate `fileImporter` modifiers on the same view. iOS SwiftUI file importer presentation is more reliable when one importer owns the presentation and the app switches its mode before presenting.
- Directly selected iOS Files URLs can come from file providers where `URLResourceValues.isRegularFile` is absent or unreliable. The scanner required `isRegularFile == true`, so selected audio files could be silently skipped even though their extension was supported.

Changes:

- Replaced the two importer modifiers with one `fileImporter` driven by an `ImportMode`.
- Folder mode uses `.folder` with single selection.
- Audio mode uses `.audio` with multiple selection.
- Direct audio-file scans no longer require `isRegularFile == true`; they still reject explicit directories and unsupported extensions.
- Folder scans still require regular files for directory contents.

Verification:

- Local `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift && swiftc -parse App/RecordReader/*.swift` passed.
- Local `xcodegen generate` passed.
- Local `git diff --check` passed.
- Local `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud result:

- Commit `42bf3f1` passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26564636821`
- Artifact: `RecordReader-unsigned-ipa`, artifact id `7261631523`, digest `sha256:02779f8a4e11f6d5361174d07800fe42a5817b72bfd6fe229c4cd1db3dd15216`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-28 16:50:38 +0800`.

Remaining manual gate:

- Re-test direct audio import on a real iPhone with the 16:50 IPA. The expected result is that tapping Open immediately exits the picker and the player shows the selected recording. If it still fails, capture whether the app shows the "没有找到支持的录音文件" message; that distinguishes picker callback failure from scanner rejection.

### 2026-05-29 M15: File-Based Subtitle Recognition Boundary

Status: implemented and cloud verified.

User direction:

- Subtitle recognition must read the selected audio file itself.
- It must not capture device speaker output or microphone input, because users may wear headphones.

Current implementation boundary:

- `SpeechTranscriber` uses `SFSpeechURLRecognitionRequest(url:)` with the selected recording URL.
- There is no `AVAudioEngine`, `inputNode`, or `SFSpeechAudioBufferRecognitionRequest` path.
- Playback volume, speaker output, headphones, or whether the recording is currently playing are not inputs to subtitle recognition.

Changes:

- Removed `INFOPLIST_KEY_NSMicrophoneUsageDescription` from `project.yml`.
- Updated the speech recognition permission text to say the app reads the selected audio file.
- Added a code comment in `SpeechTranscriber` documenting that transcription is file-based and does not listen to microphone, speaker, or headphone output.
- Updated `README.md` and `docs/device-validation.md` to state that subtitles are generated from the audio file itself.
- Updated the device validation checklist to test recognition while wearing headphones or without playing the audio.

Verification:

- Confirm no microphone permission key is present after `xcodegen generate`.
- Confirm no microphone capture APIs are present in app code.
- Local `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift && swiftc -parse App/RecordReader/*.swift` passed.
- Local `xcodegen generate` passed.
- Local `git diff --check` passed.
- Local `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud result:

- Commit `6f740cc` passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26628202315`
- Artifact: `RecordReader-unsigned-ipa`, artifact id `7287002063`, digest `sha256:e9b47b4978063090c9ccaa6dcaa0d490c88066c54cef585bc83ad52742db6900`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-29 17:01:34 +0800`.
- The downloaded IPA `Info.plist` contains `NSSpeechRecognitionUsageDescription` and does not contain `NSMicrophoneUsageDescription`.

Remaining manual gate:

- On a real iPhone, recognize subtitles while wearing headphones or without playing the audio. The expected behavior is that recognition uses the selected audio file content and does not depend on device output.

### 2026-05-29 M16: WhisperKit On-Device Subtitle Engine

Status: implemented and cloud verified.

User direction:

- Replace the Apple Speech subtitle solution with the recommended WhisperKit engine for higher Chinese recognition accuracy.

Implementation:

- Added `App/RecordReader/WhisperKitTranscriber.swift`, an `actor` that lazily loads `WhisperKit(WhisperKitConfig(model: "large-v3-v20240930_626MB"))` and transcribes the selected file via `transcribe(audioPath:decodeOptions:)` with `DecodingOptions(task: .transcribe, language: "zh", wordTimestamps: true, chunkingStrategy: .vad)`. Each `TranscriptionSegment` (`start`/`end`/`text`) maps to a `SubtitleSegment`.
- It reads the selected audio file directly (wrapped in security-scoped access). No microphone or speaker capture.
- `AudioLibraryViewModel.recognizeSubtitleForSelectedRecording()` now runs WhisperKit first and falls back to the existing `SpeechTranscriber` (iOS Speech) if WhisperKit init/transcription throws (e.g. offline before the model is cached).
- Added the `argmax-oss-swift` package (product `WhisperKit`, `from: 0.9.0`) to `project.yml`. The Whisper model is downloaded at runtime from Hugging Face and cached, so the model is not bundled in the IPA.
- `RecordReaderCore` (the SPM package run by `swift test`) does not depend on WhisperKit, so unit tests stay lightweight.

Engine boundary:

- WhisperKit is only added to the app target via XcodeGen; `Package.swift` is unchanged.
- WhisperKit requires Xcode 16 to build, which the `macos-latest` CI runner provides.

Cloud result:

- Commit `61c5b24` passed the full `iOS` workflow (build + unsigned device IPA), with WhisperKit + swift-transformers + swift-crypto resolved and compiled from source.
- The release tag `latest-unsigned-ipa` now points to `61c5b24`.
- The IPA was downloaded to `.build/github-artifacts/RecordReader-unsigned.ipa` (~1.6 MB). It bundles WhisperKit's transitive resources (`swift-transformers_Hub.bundle`, `swift-crypto_Crypto.bundle`) but not the Whisper model, which downloads at runtime.

Remaining manual gate:

- On a real iPhone: recognize a Chinese clip; expect a one-time model download on first use, then WhisperKit-generated subtitles. Force-failure (airplane mode before first download) should fall back to iOS Speech.

### 2026-05-29 M17: sherpa-onnx Paraformer Chinese On-Device Subtitle Engine

Status: implemented and cloud verified.

User direction:

- Use the mature on-device `sherpa-onnx` path.
- Select Paraformer Chinese int8 as the first model.
- Keep Apple Speech as fallback.

Implementation:

- Added `App/RecordReader/SherpaOnnx/SherpaOnnx.swift` from the upstream sherpa-onnx Swift C-API wrapper and `SherpaOnnx-Bridging-Header.h`.
- Added `App/RecordReader/SherpaOnnxTranscriber.swift`, an actor that validates bundled model files, decodes selected MP3/M4A/WAV-style audio files to 16 kHz mono Float PCM with AVFoundation, runs Silero VAD, recognizes each speech segment with sherpa-onnx Paraformer, and maps results to `SubtitleSegment`.
- Updated `AudioLibraryViewModel.recognizeSubtitleForSelectedRecording()` to run sherpa-onnx first and call the existing `SpeechTranscriber` only as Apple Speech fallback. If both fail, the final error message includes both failures.
- Removed the app-target WhisperKit dependency and deleted `WhisperKitTranscriber.swift`.
- Added `scripts/prepare-sherpa-onnx-ios.sh` to download sherpa-onnx iOS xcframeworks, the Paraformer Chinese int8 model, and `silero_vad.onnx`.
- Added `.gitignore` rules so large model binaries are not committed, while cloud builds still bundle them into the IPA.
- Updated README, device validation notes, and the M17 design spec.

Engine boundary:

- Recognition reads the selected audio file directly.
- No microphone, speaker, or headphone output path is used.
- The first cloud-built IPA with this change is expected to be much larger than prior IPA builds because the 232 MB Paraformer int8 model is bundled for offline recognition.

Local verification:

- `scripts/prepare-sherpa-onnx-ios.sh` completed and produced the iOS xcframeworks plus model resources.
- `xcodegen generate` passed and generated framework/resource references.
- `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.
- `xcodebuild` remains blocked locally because only Command Line Tools are selected, not full Xcode.

Cloud verification:

- Commit `fede0b2` passed the full `iOS` workflow.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26629830785`
- Artifact: `RecordReader-unsigned-ipa`, size `222 MB`, digest `sha256:60abeca520a476db855347da2a5cd7ed91836baa128d5d6fa489c42f0d26c84d`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-29 17:39:00 +0800`.
- Local downloaded IPA digest: `sha256:a02de5991f09e0d24d76de2f29d9845762668110bd54d94fc64460c6b7fb1e49`.
- Unzipped IPA contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.
- The downloaded IPA `Info.plist` contains `NSSpeechRecognitionUsageDescription` and does not contain `NSMicrophoneUsageDescription`.

Remaining manual gate:

- On a real iPhone: install the new IPA, import MP3/M4A/iOS recording files, verify playback, run subtitle recognition offline, and confirm Apple Speech permission appears only if sherpa-onnx fails and fallback is triggered.

### 2026-05-29 M18: Security-Scoped Audio Readability Fix for Local ASR

Status: implemented and cloud-verified.

User report:

- The app showed `本地中文模型不可用` after the M17 sherpa-onnx build.

Root cause:

- `SherpaOnnxTranscriber` reintroduced a preflight `FileManager.isReadableFile(atPath:)` check before opening the selected audio file.
- That POSIX-style readability check is unreliable for iOS document picker and security-scoped file-provider URLs. The scanner had already removed the same pattern earlier and relies on real enumeration/open failures instead.
- `SpeechTranscriber` had the same preflight check, so the Apple Speech fallback could also fail before the system recognizer got a chance to read the selected file.

Fix:

- Removed `isReadableFile(atPath:)` as a gate from both sherpa-onnx and Apple Speech transcription paths.
- `SherpaOnnxTranscriber` now lets `AVAudioFile(forReading:)` and `read(into:)` be the real validation point and wraps those failures in a Chinese actionable error.
- Updated the fallback status copy from `本地中文模型不可用` to `本地中文识别失败，正在改用 iOS 语音识别…`, because the failure may be file access/decoding, not model installation.
- Kept the import debug log but renamed its field to `POSIX可读` so future debugging does not treat it as an authoritative accessibility signal.

Local verification:

- `xcodegen generate` passed.
- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `git diff --check` passed.
- `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud verification:

- Commit `20728b0` passed the `iOS` workflow and moved `latest-unsigned-ipa` to `20728b0`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-29 17:53:00 +0800`.
- Local downloaded IPA digest: `sha256:d6ed767386639f55eabb0f8e0418fcf673ecff6248f5c08a789689b2be0ae3f3`.
- Unzipped IPA still contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.
- The downloaded IPA `Info.plist` contains `NSSpeechRecognitionUsageDescription` and does not contain `NSMicrophoneUsageDescription`.

### 2026-05-29 M19: AVAssetReader Decode Path for Compressed Audio ASR

Status: implemented and cloud-verified.

User report:

- Debug log showed `The operation couldn’t be completed. (Foundation._GenericObjCError error 0.)` after the local ASR readability fix.

Root cause:

- The failure is emitted by the sherpa-onnx audio decode layer before model inference.
- `AVAudioFile(forReading:)` can throw the generic Objective-C bridge error for some selected MP3/M4A/container-backed or file-provider audio URLs, which makes the app fall back before sherpa receives PCM samples.

Fix:

- Replaced the sherpa decode path from `AVAudioFile` plus `AVAudioConverter` to `AVURLAsset` plus `AVAssetReaderTrackOutput`.
- The new path asks AVFoundation to decode the selected audio track into 16 kHz, mono, Float32 linear PCM, then feeds those samples to the existing VAD and Paraformer recognizer.
- Added a specific `noAudioTrack` error for files that have no readable audio track.

Local verification:

- `xcodegen generate` passed.
- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `git diff --check` passed.
- `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud verification:

- Commit `70045c1` passed the `iOS` workflow and moved `latest-unsigned-ipa` to `70045c1`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-29 18:04:00 +0800`.
- Local downloaded IPA digest: `sha256:ea65c1f5eea4e1500bbc9d17bd6465d458d75766a4433183ffdcc9d95f2da578`.
- Unzipped IPA still contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.
- The downloaded IPA `Info.plist` contains `NSSpeechRecognitionUsageDescription` and does not contain `NSMicrophoneUsageDescription`.

### 2026-05-29 M20: Player UI Interaction Polish

Status: implemented and cloud-verified.

User direction:

- Continue the previously scoped UI polish work.
- Keep the design direction from the original dark player spec.
- Make the interaction feel smoother without changing import, playback, or ASR behavior.

Changes:

- Replaced the plain status text with a lightweight capsule that animates in and uses context-aware SF Symbols for scan, recognition, success, and failure states.
- Added press feedback styles for header icons, transport controls, speed, empty-state import buttons, and the main play button.
- Added subtle player transitions for selected recording and status changes.
- Added favorite bounce feedback and clearer previous/next disabled opacity.
- Improved the subtitle panel with a recognizing `ProgressView`, status coloring, softer subtitle row transitions, and clearer failed-state border emphasis.
- Improved the recording list with current-recording row highlight, animated batch-mode entry/exit, animated multi-select checkmarks, and selected-count copy in the batch toolbar.

Local verification:

- `xcodegen generate` passed.
- `swiftc -emit-module -parse-as-library -module-name RecordReaderCore Sources/RecordReaderCore/*.swift` passed for the generated core module.
- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `git diff --check` passed.
- `swiftc -typecheck` for app target sources remains blocked on this machine because the local CommandLineTools install cannot locate the iOS SDK, so `UIKit` is unavailable.
- `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud verification:

- Commit `64f6e0e` failed the `iOS` workflow because SwiftUI `symbolEffect` usage was too aggressive for the current build target.
- Commit `4d7df99` failed the `iOS` workflow because `recordingRow(_:)` declared `some View` but had local `let` bindings before the `Button`, so the row needed an explicit `return`.
- Commit `b3dfb51` passed the full `iOS` workflow and moved `latest-unsigned-ipa` to `b3dfb51`.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26631677323`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-29 18:21:25 +0800`.
- Local downloaded IPA digest: `sha256:2a6ef0b29c269ecab2ed60ae5a9b5ef6a2bd3fd2a5bf3c4e3b4bb84abcc47e5d`.
- Unzipped IPA contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.
- The downloaded IPA `Info.plist` is iPhone-only (`UIDeviceFamily` is `1`), contains `NSSpeechRecognitionUsageDescription`, and does not contain `NSMicrophoneUsageDescription`.

### 2026-05-29 M21: Long Audio Subtitle Coverage Fix

Status: implemented and cloud-verified.

User report:

- A 20-minute recording only produced subtitles for part of the audio.
- The question was whether the UI was overriding/hiding subtitles or whether recognition missed audio.

Diagnosis:

- `SubtitlePanel` renders every stored `SubtitleSegment` inside a `ScrollView`; no UI-side `prefix`, paging, replacement, or display cap was found.
- The existing sherpa path decoded the whole selected file, then relied on Silero VAD output as the only recognition input for any file where VAD produced at least one segment.
- That means VAD-missed audio regions were never sent to Paraformer. For long recordings, this can look like subtitles cover only part of the file even when audio decoding succeeded.

Fix:

- Added `TranscriptionWindowPlanner` in `RecordReaderCore` to plan fixed recognition windows that cover the full sample range without gaps.
- Added unit tests for fixed-window full coverage and the long-audio threshold.
- Updated `SherpaOnnxTranscriber` so audio at or above 120 seconds uses fixed 25-second full-coverage windows instead of VAD-only segmentation.
- Kept VAD for short clips to preserve faster, tighter segmentation.
- Added debug log entries for decoded audio duration/sample count, fixed window count, VAD result count, and full-coverage result count.

Local verification:

- `xcodegen generate` passed.
- `swiftc -typecheck Sources/RecordReaderCore/*.swift` passed.
- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `git diff --check` passed.
- `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud verification:

- Commit `b1c73f9` passed the full `iOS` workflow and moved `latest-unsigned-ipa` to `b1c73f9`.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26632013985`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-05-29 18:29:02 +0800`.
- Local downloaded IPA digest: `sha256:79f5242821c33331bcd32e61b5844808a3d3dfb70ce431f2816f257830526f4b`.
- Unzipped IPA contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.
- The downloaded IPA `Info.plist` is iPhone-only, contains `NSSpeechRecognitionUsageDescription`, and does not contain `NSMicrophoneUsageDescription`.

Manual follow-up:

- On the same 20-minute file, rerun subtitle recognition and open the in-app debug log. Expected log shape: decoded duration near the real file length, fixed window count around duration / 25 seconds, and a nonzero subtitle count. If decoded duration is much shorter than the file, the remaining issue is AVFoundation decode/input access; if duration and window count are correct but subtitles are still sparse, the remaining issue is model accuracy or empty text returned for specific windows.

### 2026-06-01 M22: Streaming Long-Audio Subtitle Performance Optimization

Status: implemented and cloud-verified.

User direction:

- Do the subtitle recognition performance optimization work before adding the recognition progress bar.

Problem:

- The M21 long-audio coverage fix decoded the entire selected file into one `[Float]` before recognition.
- For long recordings, this made peak memory scale with total audio duration. At 16 kHz mono Float32, 20 minutes is about 73 MB of PCM before per-window copies and model runtime memory.

Fix:

- Added `TranscriptionWindowBuffer` in `RecordReaderCore`.
- The buffer accepts streaming PCM chunks, emits complete fixed windows, and keeps only the unfinished tail in memory.
- Updated `SherpaOnnxTranscriber` so audio at or above 120 seconds uses streaming fixed-window recognition.
- Short audio still uses the existing VAD path to preserve faster, tighter segmentation.
- Added debug logs for decode duration, decoded sample count, expected duration, completed window count, subtitle count, and total local recognition time.

Expected impact:

- Long-audio peak PCM memory no longer scales with the full file duration. It now scales mainly with the current 25-second recognition window plus the current AVFoundation decode chunk.
- The change does not promise faster model inference by itself. Its main win is lower memory pressure and better diagnostics; speed improvement depends on less allocation and fewer full-file copies on device.

Local verification:

- `xcodegen generate` passed.
- `swiftc -typecheck Sources/RecordReaderCore/*.swift` passed.
- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `git diff --check` passed.
- `swift test` remains blocked on this machine because full Xcode/iOS SDK is unavailable through `xcrun`.

Cloud verification:

- Commit `0db366e` passed the full `iOS` workflow and moved `latest-unsigned-ipa` to `0db366e`.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26733644371`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-06-01 11:35:51 +0800`.
- Local downloaded IPA digest: `sha256:3dc561d40562257a147991a56749be61d4ee5ee3176e2e5f6063c409d1d3771c`.
- Unzipped IPA contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.
- The downloaded IPA `Info.plist` is iPhone-only, contains `NSSpeechRecognitionUsageDescription`, and does not contain `NSMicrophoneUsageDescription`.

Manual follow-up:

- On a real iPhone, rerun the same 20-minute file and compare the debug log against M21. The important signal is lower memory pressure and stable completion. If speed is still insufficient, the next performance step is real-device timing comparison across `numThreads` values and a fast-mode small model A/B test.

### 2026-06-01 M23: Subtitle Recognition Progress and Thread Tuning

Status: implemented and cloud-verified.

User direction:

- Replace technical user-facing copy like `已完成窗口数 / 27` with friendlier wording.
- Add a debug-mode thread count A/B control so real-device runs can compare sherpa-onnx `numThreads` values.

Fix:

- Added `SubtitleRecognitionProgress` in `RecordReaderCore` with user-facing phases for reading audio, recognizing, finalizing, and Apple Speech fallback.
- The normal subtitle UI now says `正在生成字幕` plus copy such as `正在识别第 8 段，共 27 段`; it does not expose the technical word `窗口`.
- `SubtitlePanel` now shows a determinate progress bar when total segment count is known and an indeterminate spinner when the recognizer cannot know the total.
- Added `SherpaThreadCount` with supported values `1`, `2`, and `4`, defaulting to `2`.
- Added a debug log setting labeled `本地识别线程数` with A/B copy and `改动后下次识别生效`.
- `SherpaOnnxTranscriber` now loads the Paraformer recognizer using the selected thread count and rebuilds the cached engine when the selected value changes for a later recognition run.
- Debug logs keep technical details including thread count and fixed-window counts for performance diagnosis.

Local verification:

- `swiftc -typecheck Sources/RecordReaderCore/*.swift` passed.
- `swiftc -emit-module -parse-as-library -module-name RecordReaderCore Sources/RecordReaderCore/*.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `xcodegen generate` passed.
- `git diff --check` passed.
- `swift test` remains blocked on this machine because the local CommandLineTools install cannot resolve `xcrun --sdk macosx --show-sdk-platform-path`.
- Direct local app typecheck remains blocked because this machine does not expose the iOS SDK to `swiftc`, so `UIKit` is unavailable outside cloud Xcode.

Cloud verification:

- Commit `00852cb` passed the full `iOS` workflow and moved `latest-unsigned-ipa` to `00852cb`.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26734606510`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-06-01 12:11:54 +0800`.
- Local downloaded IPA digest: `sha256:899af6b9ea03ff1c83a60e00b2f5a2f2dab09ff0f0952bc19948e7ced135fe59`.
- Local downloaded IPA size: `224M` on disk.
- Unzipped IPA contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.
- The downloaded IPA `Info.plist` is iPhone-only (`UIDeviceFamily` is `1`), contains `NSSpeechRecognitionUsageDescription`, and does not contain `NSMicrophoneUsageDescription`.

Manual follow-up:

- On a real iPhone, run the same 8 MB / 11-minute file with thread counts `1`, `2`, and `4`.
- Record total time, subtitle count, whether the device becomes hot, and whether the app stays responsive.
- Keep `2` as the default unless `4` is consistently faster without noticeably worse heat or responsiveness.

### 2026-06-01 M24: Subtitle Recognition Performance Diagnostics

Status: implemented and cloud-verified.

User direction:

- Add a performance diagnostics package for subtitle recognition.
- Include per-window timing logs.
- Add debug options for thread count `Auto / 1 / 2 / 4 / 6 / 8`.
- Add debug options for long-audio window length `25s / 35s / 45s`.

Fix:

- Extended `SherpaThreadCount` to include `Auto`, `6`, and `8`, while preserving default `2` for users who have not changed settings.
- Added `TranscriptionWindowDuration` in `RecordReaderCore` with supported values `25s`, `35s`, and `45s`.
- Added debug UI controls for local recognition thread count and long-audio window length.
- `AudioLibraryViewModel` now passes both debug settings into `SherpaOnnxTranscriber` when recognition starts.
- `SherpaOnnxTranscriber` now uses the configured long-audio window length for full-coverage fixed-window recognition.
- Added per-window logs with index, time range, recognition time, and whether the window produced subtitle text.
- Added window timing summary logs with average window time, slowest window time, nonempty subtitle window count, and empty window count.

Local verification:

- `swiftc -typecheck Sources/RecordReaderCore/*.swift` passed.
- `swiftc -emit-module -parse-as-library -module-name RecordReaderCore Sources/RecordReaderCore/*.swift` passed.
- `swiftc -typecheck -I /tmp/recordreader-typecheck App/RecordReader/DebugSettings.swift` passed and covers the debug settings getter return issue caught by cloud Xcode.
- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `xcodegen generate` passed.
- `git diff --check` passed.
- `swift test` remains blocked on this machine because the local CommandLineTools install cannot resolve `xcrun --sdk macosx --show-sdk-platform-path`.

Cloud verification:

- Commit `d765aa3` passed core tests but failed `Build iOS app` because `DebugSettings` getters were missing explicit `return`.
- Commit `9d8ecc9` simplified the debug settings SwiftUI view, but still failed on the same getter issue.
- Commit `4861724` passed the full `iOS` workflow and moved `latest-unsigned-ipa` to `4861724`.
- Run: `https://github.com/jokaye/RecordReader/actions/runs/26738137669`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-06-01 14:04:09 +0800`.
- Local downloaded IPA digest: `sha256:7d2e4a5b9b87976e8e381a6a23de99d799687038dbad6ae496e8aa6a4203a70c`.
- Local downloaded IPA size: `222M`.
- Unzipped IPA contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.

Manual follow-up:

- On a real iPhone, test the same 8 MB / 11-minute file with thread count `Auto`, `1`, `2`, `4`, `6`, and `8` while keeping window length at `25s`.
- Then test window lengths `25s`, `35s`, and `45s` with the best thread setting from the first pass.
- Compare debug log fields: total time, average window time, slowest window time, empty window count, subtitle count, heat, and app responsiveness.
- Do not select a new default from one run. Use at least two repeated runs per candidate because iOS thermal state can dominate small performance differences.

### 2026-06-01 M25: CoreML Provider Experimental Switch

Status: implemented and cloud-verified.

User direction:

- Add CoreML provider as an experimental switch.
- Expand the detailed optimization roadmap that follows this experiment.

Fix:

- Added `RecognitionProvider` in `RecordReaderCore` with stable values `cpu` and `coreml`; CPU remains the default.
- Added Debug setting `本地识别后端` with `CPU` and `CoreML(实验)`.
- `AudioLibraryViewModel` now reads the selected provider and includes it in the start log for sherpa-onnx recognition.
- `SherpaOnnxTranscriber` now passes the selected provider into `sherpaOnnxOfflineModelConfig`.
- The cached sherpa-onnx recognizer now includes provider in its cache key, so switching CPU/CoreML rebuilds the engine.
- Engine-load debug logs now include provider and load time.
- If the CoreML provider throws, the app retries sherpa-onnx with CPU before falling back to Apple Speech.
- Added detailed roadmap: `docs/superpowers/roadmaps/2026-06-01-coreml-performance-roadmap.md`.

Local verification:

- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -emit-module -parse-as-library -module-name RecordReaderCore Sources/RecordReaderCore/*.swift` passed.
- `swiftc -typecheck -I /tmp/recordreader-typecheck App/RecordReader/DebugSettings.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `git diff --check` passed.
- `swift test --filter RecordReaderCoreTests.RecognitionProviderTests` remains blocked on this machine because the local CommandLineTools install cannot resolve `xcrun --sdk macosx --show-sdk-platform-path`.
- Full local app typecheck remains blocked because this machine does not expose the iOS SDK to `swiftc`, so `UIKit` is unavailable outside cloud Xcode.

Cloud verification:

- Commit `4b976c7` passed the full `iOS` workflow and moved `latest-unsigned-ipa` to `4b976c7`.
- Latest IPA was downloaded locally to `.build/github-artifacts/RecordReader-unsigned.ipa` at `2026-06-01 15:04:00 +0800`.
- Local downloaded IPA digest: `sha256:ce05190f535d7e7c256eb78710f85402054d0ead7bcc7cea634532cab315e060`.
- Local downloaded IPA size: `222M`.
- Unzipped IPA contains `model.int8.onnx` (232 MB), `tokens.txt` (74 KB), and `silero_vad.onnx` (629 KB) in `Payload/RecordReader.app`.

Manual follow-up:

- On a real iPhone, compare CPU and CoreML with the same file, same thread count, and same window length.
- Record first-run and second-run timings separately because CoreML compile/cache behavior can distort the first run.
- Keep CPU as the product default unless CoreML improves repeat-run total time by at least 15 percent without subtitle quality loss.

### 2026-06-01 M25.1: CoreML Empty Result CPU Retry

Status: implemented locally, awaiting cloud verification.

User report:

- CoreML experimental provider opens normally, but it does not recognize human speech from the audio file.

Diagnosis:

- The CoreML path already retried CPU when the provider threw an error.
- It did not retry CPU when CoreML returned successfully with zero subtitle segments.
- That is a plausible CoreML EP failure mode for this Paraformer ONNX model: the runtime can load and run, but the decoded text may be empty for every window.

Fix:

- Added explicit retry policy to `RecognitionProvider`.
- CoreML now retries CPU both on provider failure and on an empty recognition result.
- CPU remains the default and does not retry itself on empty results.
- Added tests covering the provider retry policy.

Local verification:

- `swiftc -emit-module -parse-as-library -module-name RecordReaderCore Sources/RecordReaderCore/*.swift` passed.
- A focused `swiftc -typecheck` snippet confirmed the new provider retry policy API is available.
- `swiftc -parse Sources/RecordReaderCore/*.swift Tests/RecordReaderCoreTests/*.swift` passed.
- `swiftc -typecheck -I /tmp/recordreader-typecheck App/RecordReader/DebugSettings.swift` passed.
- `swiftc -parse` for the app target sources with the sherpa-onnx bridging header and generated `RecordReaderCore` module passed.
- `xcodegen generate` passed.
- `git diff --check` passed.
- `swift test --filter RecordReaderCoreTests.RecognitionProviderTests` remains blocked on this machine because the local CommandLineTools install cannot resolve `xcrun --sdk macosx --show-sdk-platform-path`.

Cloud verification:

- Pending.
