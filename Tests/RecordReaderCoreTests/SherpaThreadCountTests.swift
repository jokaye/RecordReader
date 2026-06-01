import XCTest
@testable import RecordReaderCore

final class SherpaThreadCountTests: XCTestCase {
    func testSupportedThreadCountsAreLimitedForDebugTuning() {
        XCTAssertEqual(SherpaThreadCount.allCases.map(\.rawValue), [1, 2, 4])
        XCTAssertEqual(SherpaThreadCount.defaultValue, .two)
    }

    func testInvalidRawValueFallsBackToDefault() {
        XCTAssertEqual(SherpaThreadCount(rawValueOrDefault: 8), .two)
        XCTAssertEqual(SherpaThreadCount(rawValueOrDefault: 0), .two)
    }
}
