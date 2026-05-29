import XCTest
@testable import RecordReaderCore

final class PlaybackSpeedTests: XCTestCase {
    func testDefaultIsNormal() {
        XCTAssertEqual(PlaybackSpeed.default, .normal)
        XCTAssertEqual(PlaybackSpeed.normal.multiplier, 1.0)
    }

    func testLabelsStripTrailingZeros() {
        XCTAssertEqual(PlaybackSpeed.half.label, "0.5x")
        XCTAssertEqual(PlaybackSpeed.threeQuarters.label, "0.75x")
        XCTAssertEqual(PlaybackSpeed.normal.label, "1x")
        XCTAssertEqual(PlaybackSpeed.fiveQuarters.label, "1.25x")
        XCTAssertEqual(PlaybackSpeed.threeHalves.label, "1.5x")
        XCTAssertEqual(PlaybackSpeed.double.label, "2x")
    }

    func testNextCyclesThroughAllSpeedsInOrder() {
        XCTAssertEqual(PlaybackSpeed.half.next(), .threeQuarters)
        XCTAssertEqual(PlaybackSpeed.threeQuarters.next(), .normal)
        XCTAssertEqual(PlaybackSpeed.normal.next(), .fiveQuarters)
        XCTAssertEqual(PlaybackSpeed.fiveQuarters.next(), .threeHalves)
        XCTAssertEqual(PlaybackSpeed.threeHalves.next(), .double)
    }

    func testNextWrapsFromFastestToSlowest() {
        XCTAssertEqual(PlaybackSpeed.double.next(), .half)
    }

    func testCyclingVisitsEverySpeedExactlyOnce() {
        var visited: [PlaybackSpeed] = []
        var speed = PlaybackSpeed.normal
        for _ in PlaybackSpeed.allCases {
            visited.append(speed)
            speed = speed.next()
        }
        XCTAssertEqual(Set(visited), Set(PlaybackSpeed.allCases))
        XCTAssertEqual(speed, .normal)
    }
}
