import Foundation

public struct RecordingLibraryMetadata: Codable, Equatable {
    public var records: [String: RecordingMetadata]
    public var selectedFolderBookmark: Data?

    public init(records: [String: RecordingMetadata], selectedFolderBookmark: Data?) {
        self.records = records
        self.selectedFolderBookmark = selectedFolderBookmark
    }

    public static let empty = RecordingLibraryMetadata(records: [:], selectedFolderBookmark: nil)
}

public struct RecordingMetadata: Codable, Equatable {
    public var isFavorite: Bool
    public var category: String?
    public var subtitle: SubtitleDocument?

    public init(isFavorite: Bool, category: String?, subtitle: SubtitleDocument?) {
        self.isFavorite = isFavorite
        self.category = category
        self.subtitle = subtitle
    }
}

public struct SubtitleDocument: Codable, Equatable {
    public var status: SubtitleStatus
    public var segments: [SubtitleSegment]
    public var errorMessage: String?

    public init(status: SubtitleStatus, segments: [SubtitleSegment], errorMessage: String?) {
        self.status = status
        self.segments = segments
        self.errorMessage = errorMessage
    }
}

public enum SubtitleStatus: String, Codable, Equatable {
    case notStarted
    case recognizing
    case ready
    case failed
}

public struct SubtitleSegment: Codable, Equatable, Identifiable {
    public var id: String
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var text: String

    public init(id: String = UUID().uuidString, startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}
