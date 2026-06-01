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
}
