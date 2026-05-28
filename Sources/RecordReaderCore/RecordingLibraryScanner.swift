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
        supportedExtensions: Set<String> = Self.defaultSupportedExtensions
    ) {
        self.fileManager = fileManager
        self.supportedExtensions = supportedExtensions
    }

    public static let defaultSupportedExtensions: Set<String> = [
        "aac",
        "aif",
        "aiff",
        "aifc",
        "amr",
        "caf",
        "flac",
        "m4a",
        "mp3",
        "wav",
        "3g2",
        "3gp",
        "3gp2",
        "3gpp"
    ]

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

        return try recordings(from: urls, metadata: metadata, requireRegularFile: true)
    }

    public func scan(urls: [URL], metadata: RecordingLibraryMetadata) throws -> [Recording] {
        var recordingsByID: [String: Recording] = [:]

        for url in urls {
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard exists else {
                throw RecordingLibraryError.folderNotFound(url.path)
            }

            let recordings: [Recording]
            if isDirectory.boolValue {
                recordings = try scan(folder: url, metadata: metadata)
            } else {
                recordings = try self.recordings(from: [url], metadata: metadata, requireRegularFile: false)
            }

            for recording in recordings {
                recordingsByID[recording.id] = recording
            }
        }

        return sort(Array(recordingsByID.values))
    }

    private func recordings(
        from urls: [URL],
        metadata: RecordingLibraryMetadata,
        requireRegularFile: Bool
    ) throws -> [Recording] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        let recordings = try urls.compactMap { url -> Recording? in
            let values = try url.resourceValues(forKeys: keys)
            if requireRegularFile, values.isRegularFile != true {
                return nil
            }
            if !requireRegularFile, values.isRegularFile == false {
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

        return sort(recordings)
    }

    private func sort(_ recordings: [Recording]) -> [Recording] {
        recordings.sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
