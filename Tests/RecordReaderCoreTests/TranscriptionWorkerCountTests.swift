import XCTest
@testable import RecordReaderCore

final class TranscriptionWorkerCountTests: XCTestCase {
    func testSupportedWorkerCountsAreLimitedForLongAudioTuning() {
        XCTAssertEqual(TranscriptionWorkerCount.allCases.map(\.rawValue), [0, 1, 2, 3])
        XCTAssertEqual(TranscriptionWorkerCount.allCases.map(\.label), ["Auto", "1", "2", "3"])
        XCTAssertEqual(TranscriptionWorkerCount.defaultValue, .auto)
    }

    func testInvalidRawValueFallsBackToDefault() {
        XCTAssertEqual(TranscriptionWorkerCount(rawValueOrDefault: 4), .auto)
        XCTAssertEqual(TranscriptionWorkerCount(rawValueOrDefault: -1), .auto)
    }

    func testEffectiveWorkerCountIsBoundedByAvailableWindows() {
        XCTAssertEqual(TranscriptionWorkerCount.auto.effectiveWorkerCount(totalWindows: 19), 2)
        XCTAssertEqual(TranscriptionWorkerCount.auto.effectiveWorkerCount(totalWindows: 1), 1)
        XCTAssertEqual(TranscriptionWorkerCount.three.effectiveWorkerCount(totalWindows: 2), 2)
        XCTAssertEqual(TranscriptionWorkerCount.two.effectiveWorkerCount(totalWindows: 0), 1)
    }
}
