import Foundation

public enum SubtitleDisplayMode: String, CaseIterable, Equatable, Identifiable {
    case follow
    case all

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .follow:
            return "跟随播放"
        case .all:
            return "全部字幕"
        }
    }
}

public enum SubtitleTimeline {
    public static func activeSegment(
        in segments: [SubtitleSegment],
        at currentTime: TimeInterval
    ) -> SubtitleSegment? {
        if let exact = segments.first(where: { segment in
            currentTime >= segment.startTime && currentTime < segment.endTime
        }) {
            return exact
        }
        return segments.last(where: { segment in
            segment.startTime <= currentTime
        })
    }
}
