import XCTest
@testable import RecordReaderCore

final class ExperimentalTranscriptionEngineTests: XCTestCase {
    func testWhisperKitCoreMLExperimentIsAvailableButNotDefault() {
        XCTAssertEqual(ExperimentalTranscriptionEngine.defaultValue, .sherpaOnnx)
        XCTAssertEqual(
            ExperimentalTranscriptionEngine.allCases.map(\.rawValue),
            ["sherpaOnnx", "whisperKitCoreML"]
        )
        XCTAssertEqual(
            ExperimentalTranscriptionEngine.allCases.map(\.title),
            ["sherpa-onnx", "WhisperKit CoreML 实验"]
        )
    }
}
