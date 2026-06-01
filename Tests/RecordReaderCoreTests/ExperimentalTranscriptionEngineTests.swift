import XCTest
@testable import RecordReaderCore

final class ExperimentalTranscriptionEngineTests: XCTestCase {
    func testWhisperKitCoreMLExperimentIsBundledExperimentDefault() {
        XCTAssertEqual(ExperimentalTranscriptionEngine.defaultValue, .whisperKitCoreML)
        XCTAssertEqual(
            ExperimentalTranscriptionEngine.allCases.map(\.rawValue),
            ["sherpaOnnx", "whisperKitCoreML"]
        )
        XCTAssertEqual(
            ExperimentalTranscriptionEngine.allCases.map(\.title),
            ["sherpa-onnx", "WhisperKit CoreML 实验"]
        )
    }

    func testInvalidEngineRawValueFallsBackToWhisperKitCoreML() {
        XCTAssertEqual(ExperimentalTranscriptionEngine(rawValueOrDefault: ""), .whisperKitCoreML)
        XCTAssertEqual(ExperimentalTranscriptionEngine(rawValueOrDefault: "unknown"), .whisperKitCoreML)
    }

    func testWhisperKitModelVariantsKeepSmallCompressedAsDefault() {
        XCTAssertEqual(WhisperKitModelVariant.defaultValue, .smallCompressed)
        XCTAssertEqual(
            WhisperKitModelVariant.allCases.map(\.rawValue),
            ["tiny", "base", "small_216MB"]
        )
        XCTAssertEqual(
            WhisperKitModelVariant.allCases.map(\.modelName),
            ["whisper-tiny", "whisper-base", "small_216MB"]
        )
        XCTAssertEqual(
            WhisperKitModelVariant.allCases.map(\.estimatedDownloadSize),
            ["约 77MB", "约 147MB", "约 217MB"]
        )
    }

    func testInvalidWhisperKitModelVariantFallsBackToDefault() {
        XCTAssertEqual(WhisperKitModelVariant(rawValueOrDefault: ""), .smallCompressed)
        XCTAssertEqual(WhisperKitModelVariant(rawValueOrDefault: "large-v3"), .smallCompressed)
    }

    func testOnlySmallCompressedIsBundledInTheExperimentBuild() {
        XCTAssertEqual(WhisperKitModelVariant.smallCompressed.bundledModelDirectoryName, "openai_whisper-small_216MB")
        XCTAssertTrue(WhisperKitModelVariant.smallCompressed.isBundledInExperiment)
        XCTAssertFalse(WhisperKitModelVariant.tiny.isBundledInExperiment)
        XCTAssertFalse(WhisperKitModelVariant.base.isBundledInExperiment)
    }

    func testWhisperKitQualityFirstDecodingAvoidsAggressiveChunkingAndFallback() {
        let settings = WhisperKitDecodingSettings.qualityFirstChinese

        XCTAssertEqual(settings.languageCode, "zh")
        XCTAssertEqual(settings.concurrentWorkerCount, 1)
        XCTAssertEqual(settings.temperatureFallbackCount, 0)
        XCTAssertFalse(settings.usesVADChunking)
        XCTAssertTrue(settings.usesPrefillPrompt)
    }

    func testWhisperKitQualityGateRejectsHighCompressionRepetition() {
        let reason = WhisperKitTranscriptionQualityGate.qualityFirstChinese.rejectionReason(
            segmentTexts: Array(repeating: "(小聲點)", count: 12) + ["正常内容"],
            averageLogProbability: -0.42,
            averageCompressionRatio: 9.42
        )

        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.contains("压缩率") == true)
    }

    func testWhisperKitQualityGateRejectsLowAverageLogProbability() {
        let reason = WhisperKitTranscriptionQualityGate.qualityFirstChinese.rejectionReason(
            segmentTexts: ["今天我们讨论录音播放器", "字幕会跟随时间轴显示"],
            averageLogProbability: -1.2,
            averageCompressionRatio: 1.8
        )

        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.contains("可信度") == true)
    }

    func testWhisperKitQualityGateAcceptsVariedReasonableSegments() {
        let reason = WhisperKitTranscriptionQualityGate.qualityFirstChinese.rejectionReason(
            segmentTexts: ["今天我们讨论录音播放器", "字幕会跟随时间轴显示", "后续继续优化识别速度"],
            averageLogProbability: -0.42,
            averageCompressionRatio: 1.8
        )

        XCTAssertNil(reason)
    }
}
