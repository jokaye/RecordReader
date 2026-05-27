import Foundation

public struct Recording: Identifiable, Equatable {
    public let id: String
    public let url: URL
    public let title: String
    public let fileExtension: String
    public let fileSize: Int64?
    public let createdAt: Date?
    public let modifiedAt: Date?
    public var isFavorite: Bool
    public var category: String?
    public var subtitle: SubtitleDocument?

    public init(
        id: String,
        url: URL,
        title: String,
        fileExtension: String,
        fileSize: Int64?,
        createdAt: Date?,
        modifiedAt: Date?,
        isFavorite: Bool,
        category: String?,
        subtitle: SubtitleDocument?
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isFavorite = isFavorite
        self.category = category
        self.subtitle = subtitle
    }
}

public enum RecordingKey {
    public static func make(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
