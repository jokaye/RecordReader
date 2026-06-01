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
        XCTAssertEqual(
            TranscriptionWorkerCount.auto.effectiveWorkerCount(totalWindows: 19, performanceTier: .standard),
            2
        )
        XCTAssertEqual(
            TranscriptionWorkerCount.auto.effectiveWorkerCount(totalWindows: 19, performanceTier: .high),
            3
        )
        XCTAssertEqual(
            TranscriptionWorkerCount.auto.effectiveWorkerCount(totalWindows: 1, performanceTier: .high),
            1
        )
        XCTAssertEqual(
            TranscriptionWorkerCount.three.effectiveWorkerCount(totalWindows: 2, performanceTier: .standard),
            2
        )
        XCTAssertEqual(
            TranscriptionWorkerCount.two.effectiveWorkerCount(totalWindows: 0, performanceTier: .standard),
            1
        )
    }

    func testDeviceIdentifierMapsToPerformanceTier() {
        XCTAssertEqual(TranscriptionPerformanceTier(deviceIdentifier: "iPhone15,3"), .high)
        XCTAssertEqual(TranscriptionPerformanceTier(deviceIdentifier: "iPhone15,2"), .high)
        XCTAssertEqual(TranscriptionPerformanceTier(deviceIdentifier: "iPhone14,3"), .standard)
        XCTAssertEqual(TranscriptionPerformanceTier(deviceIdentifier: "iPhone16,2"), .high)
    }
}
