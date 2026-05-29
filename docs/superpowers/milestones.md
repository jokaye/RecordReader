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

Status: implemented locally; cloud verification pending.

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

Status: implemented locally; cloud verification pending.

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
