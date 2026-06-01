import XCTest
@testable import RecordReaderCore

final class SherpaThreadCountTests: XCTestCase {
    func testSupportedThreadCountsAreLimitedForDebugTuning() {
        XCTAssertEqual(SherpaThreadCount.allCases.map(\.rawValue), [0, 1, 2, 4, 6, 8])
        XCTAssertEqual(SherpaThreadCount.allCases.map(\.label), ["Auto", "1", "2", "4", "6", "8"])
        XCTAssertEqual(SherpaThreadCount.defaultValue, .two)
    }

    func testInvalidRawValueFallsBackToDefault() {
        XCTAssertEqual(SherpaThreadCount(rawValueOrDefault: 12), .two)
        XCTAssertEqual(SherpaThreadCount(rawValueOrDefault: -1), .two)
    }
}
