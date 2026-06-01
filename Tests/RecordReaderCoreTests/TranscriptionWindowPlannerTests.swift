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

    func testStreamingWindowBufferEmitsCompleteWindowsAcrossChunks() {
        var buffer = TranscriptionWindowBuffer(sampleRate: 10, windowDuration: 0.5)

        XCTAssertTrue(buffer.append([0, 1]).isEmpty)

        let firstBatch = buffer.append([2, 3, 4, 5, 6])
        XCTAssertEqual(firstBatch.count, 1)
        XCTAssertEqual(firstBatch[0].window.startSample, 0)
        XCTAssertEqual(firstBatch[0].window.endSample, 5)
        XCTAssertEqual(firstBatch[0].samples, [0, 1, 2, 3, 4])

        let secondBatch = buffer.append([7, 8, 9])
        XCTAssertEqual(secondBatch.count, 1)
        XCTAssertEqual(secondBatch[0].window.startSample, 5)
        XCTAssertEqual(secondBatch[0].window.endSample, 10)
        XCTAssertEqual(secondBatch[0].samples, [5, 6, 7, 8, 9])

        XCTAssertNil(buffer.finish())
    }

    func testStreamingWindowBufferFlushesPartialFinalWindow() {
        var buffer = TranscriptionWindowBuffer(sampleRate: 10, windowDuration: 0.5)

        let completeWindows = buffer.append([0, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(completeWindows.count, 1)

        let finalWindow = buffer.finish()
        XCTAssertEqual(finalWindow?.window.startSample, 5)
        XCTAssertEqual(finalWindow?.window.endSample, 7)
        XCTAssertEqual(finalWindow?.samples, [5, 6])
        XCTAssertNil(buffer.finish())
    }
}
