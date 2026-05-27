import Foundation

public enum RecordingLibraryError: Error, Equatable, LocalizedError {
    case folderNotFound(String)
    case folderUnreadable(String)

    public var errorDescription: String? {
        switch self {
        case .folderNotFound(let path):
            return "录音文件夹不存在：\(path)"
        case .folderUnreadable(let path):
            return "无法读取录音文件夹：\(path)"
        }
    }
}

public struct RecordingLibraryScanner {
    private let fileManager: FileManager
    private let supportedExtensions: Set<String>

    public init(
        fileManager: FileManager = .default,
        supportedExtensions: Set<String> = ["aac", "aif", "aiff", "caf", "flac", "m4a", "mp3", "wav"]
    ) {
        self.fileManager = fileManager
        self.supportedExtensions = supportedExtensions
    }

    public func scan(folder: URL, metadata: RecordingLibraryMetadata) throws -> [Recording] {
        let folderPath = folder.path
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RecordingLibraryError.folderNotFound(folderPath)
        }
        guard fileManager.isReadableFile(atPath: folderPath) else {
            throw RecordingLibraryError.folderUnreadable(folderPath)
        }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        let urls = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        return try urls.compactMap { url in
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else {
                return nil
            }
            let fileExtension = url.pathExtension.lowercased()
            guard supportedExtensions.contains(fileExtension) else {
                return nil
            }

            let key = RecordingKey.make(for: url)
            let recordMetadata = metadata.records[key]
            return Recording(
                id: key,
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                fileExtension: fileExtension,
                fileSize: values.fileSize.map(Int64.init),
                createdAt: values.creationDate,
                modifiedAt: values.contentModificationDate,
                isFavorite: recordMetadata?.isFavorite ?? false,
                category: recordMetadata?.category,
                subtitle: recordMetadata?.subtitle
            )
        }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
