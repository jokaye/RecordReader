import Foundation

public struct RecordingLibraryMetadata: Codable, Equatable {
    public var records: [String: RecordingMetadata]
    public var selectedFolderBookmark: Data?
    public var hiddenRecordingIDs: Set<String>

    public init(
        records: [String: RecordingMetadata],
        selectedFolderBookmark: Data?,
        hiddenRecordingIDs: Set<String> = []
    ) {
        self.records = records
        self.selectedFolderBookmark = selectedFolderBookmark
        self.hiddenRecordingIDs = hiddenRecordingIDs
    }

    public static let empty = RecordingLibraryMetadata(records: [:], selectedFolderBookmark: nil)

    private enum CodingKeys: String, CodingKey {
        case records
        case selectedFolderBookmark
        case hiddenRecordingIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        records = try container.decodeIfPresent([String: RecordingMetadata].self, forKey: .records) ?? [:]
        selectedFolderBookmark = try container.decodeIfPresent(Data.self, forKey: .selectedFolderBookmark)
        hiddenRecordingIDs = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenRecordingIDs) ?? []
    }
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
