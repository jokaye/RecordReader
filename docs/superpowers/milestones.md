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
