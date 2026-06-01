import XCTest
@testable import RecordReaderCore

final class RecognitionProviderTests: XCTestCase {
    func testSupportedProvidersKeepCPUDefaultAndExposeCoreMLExperiment() {
        XCTAssertEqual(RecognitionProvider.allCases.map(\.rawValue), ["cpu", "coreml"])
        XCTAssertEqual(RecognitionProvider.allCases.map(\.label), ["CPU", "CoreML"])
        XCTAssertEqual(RecognitionProvider.defaultValue, .cpu)
    }

    func testInvalidRawValueFallsBackToDefault() {
        XCTAssertEqual(RecognitionProvider(rawValueOrDefault: "metal"), .cpu)
        XCTAssertEqual(RecognitionProvider(rawValueOrDefault: ""), .cpu)
    }

    func testProviderLogLabelsMarkCoreMLAsExperimental() {
        XCTAssertEqual(RecognitionProvider.cpu.logLabel, "CPU")
        XCTAssertEqual(RecognitionProvider.coreML.logLabel, "CoreML(实验)")
    }
}
