import XCTest
@testable import RecordReaderCore

final class SubtitleTimelineTests: XCTestCase {
    func testActiveSegmentMatchesCurrentPlaybackTime() {
        let segments = [
            SubtitleSegment(id: "a", startTime: 0, endTime: 3, text: "第一句"),
            SubtitleSegment(id: "b", startTime: 3, endTime: 7, text: "第二句")
        ]

        XCTAssertEqual(SubtitleTimeline.activeSegment(in: segments, at: 3.2)?.id, "b")
    }

    func testActiveSegmentFallsBackToNearestPreviousSegmentBetweenGaps() {
        let segments = [
            SubtitleSegment(id: "a", startTime: 0, endTime: 2, text: "第一句"),
            SubtitleSegment(id: "b", startTime: 5, endTime: 7, text: "第二句")
        ]

        XCTAssertEqual(SubtitleTimeline.activeSegment(in: segments, at: 3.5)?.id, "a")
    }

    func testDisplayModesExposeFollowAndAllLabels() {
        XCTAssertEqual(SubtitleDisplayMode.allCases.map(\.title), ["跟随播放", "全部字幕"])
    }
}
