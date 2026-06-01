import XCTest
@testable import RecordReaderCore

final class SubtitleRecognitionProgressTests: XCTestCase {
    func testReadingAudioUsesFriendlyCopyWithoutTechnicalWindowText() {
        let progress = SubtitleRecognitionProgress.readingAudio

        XCTAssertEqual(progress.title, "正在生成字幕")
        XCTAssertEqual(progress.detail, "正在读取音频...")
        XCTAssertNil(progress.fractionCompleted)
    }

    func testRecognizingProgressUsesSegmentCopyAndFraction() {
        let progress = SubtitleRecognitionProgress.recognizing(completedSegments: 7, totalSegments: 27)

        XCTAssertEqual(progress.title, "正在生成字幕")
        XCTAssertEqual(progress.detail, "正在识别第 8 段，共 27 段")
        XCTAssertEqual(progress.fractionCompleted ?? -1, 7.0 / 27.0, accuracy: 0.0001)
        XCTAssertFalse(progress.detail.contains("窗口"))
    }

    func testRecognizingProgressClampsCompletedSegments() {
        let progress = SubtitleRecognitionProgress.recognizing(completedSegments: 40, totalSegments: 27)

        XCTAssertEqual(progress.detail, "正在整理字幕...")
        XCTAssertEqual(progress.fractionCompleted ?? -1, 1)
    }

    func testFallbackProgressExplainsIOSSpeech() {
        let progress = SubtitleRecognitionProgress.fallback

        XCTAssertEqual(progress.title, "正在生成字幕")
        XCTAssertEqual(progress.detail, "本地识别暂不可用，正在改用 iOS 语音识别...")
        XCTAssertNil(progress.fractionCompleted)
    }
}
