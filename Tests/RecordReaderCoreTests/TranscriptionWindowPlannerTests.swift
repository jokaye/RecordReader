import XCTest
@testable import RecordReaderCore

final class TranscriptionWindowPlannerTests: XCTestCase {
    func testFixedWindowsCoverEntireSampleRangeWithoutGaps() {
        let windows = TranscriptionWindowPlanner.fixedWindows(
            sampleCount: 1_000,
            sampleRate: 100,
            windowDuration: 3
        )

        XCTAssertEqual(windows.map(\.startSample), [0, 300, 600, 900])
        XCTAssertEqual(windows.map(\.endSample), [300, 600, 900, 1_000])
        XCTAssertEqual(windows.first?.startTime, 0)
        XCTAssertEqual(windows.last?.endTime, 10)
    }

    func testFixedWindowsRejectInvalidInputs() {
        XCTAssertTrue(TranscriptionWindowPlanner.fixedWindows(sampleCount: 0).isEmpty)
        XCTAssertTrue(TranscriptionWindowPlanner.fixedWindows(sampleCount: 100, sampleRate: 0).isEmpty)
        XCTAssertTrue(TranscriptionWindowPlanner.fixedWindows(sampleCount: 100, windowDuration: 0).isEmpty)
    }

    func testLongAudioThresholdUsesFullCoverageAtThreshold() {
        XCTAssertFalse(
            TranscriptionWindowPlanner.shouldUseFullCoverage(
                sampleCount: 1_199,
                sampleRate: 10,
                thresholdDuration: 120
            )
        )
        XCTAssertTrue(
            TranscriptionWindowPlanner.shouldUseFullCoverage(
                sampleCount: 1_200,
                sampleRate: 10,
                thresholdDuration: 120
            )
        )
    }
}
