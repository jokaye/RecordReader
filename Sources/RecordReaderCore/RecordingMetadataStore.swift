import Foundation

public enum RecordingMetadataStoreError: Error, LocalizedError {
    case invalidMetadataFile(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMetadataFile(let path):
            return "录音元数据文件无效：\(path)"
        }
    }
}

public struct RecordingMetadataStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> RecordingLibraryMetadata {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(RecordingLibraryMetadata.self, from: data)
        } catch {
            throw RecordingMetadataStoreError.invalidMetadataFile(fileURL.path)
        }
    }

    public func save(_ metadata: RecordingLibraryMetadata) throws {
        let folder = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try encoder.encode(metadata)
        try data.write(to: fileURL, options: [.atomic])
    }
}
