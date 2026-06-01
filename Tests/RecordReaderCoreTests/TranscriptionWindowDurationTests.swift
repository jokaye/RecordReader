import XCTest
@testable import RecordReaderCore

final class TranscriptionWindowDurationTests: XCTestCase {
    func testSupportedWindowDurationsAreLimitedForDebugTuning() {
        XCTAssertEqual(TranscriptionWindowDuration.allCases.map(\.rawValue), [25, 35, 45])
        XCTAssertEqual(TranscriptionWindowDuration.defaultValue, .twentyFiveSeconds)
    }

    func testInvalidWindowDurationFallsBackToDefault() {
        XCTAssertEqual(TranscriptionWindowDuration(rawValueOrDefault: 20), .twentyFiveSeconds)
        XCTAssertEqual(TranscriptionWindowDuration(rawValueOrDefault: 0), .twentyFiveSeconds)
    }

    func testDurationValueIsUsableByWindowPlanner() {
        let windows = TranscriptionWindowPlanner.fixedWindows(
            sampleCount: 100,
            sampleRate: 10,
            windowDuration: TranscriptionWindowDuration.thirtyFiveSeconds.duration
        )

        XCTAssertEqual(windows.map(\.startSample), [0])
        XCTAssertEqual(windows.map(\.endSample), [100])
    }
}
