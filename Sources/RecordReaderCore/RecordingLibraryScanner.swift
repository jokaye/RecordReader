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

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            // POSIX readability checks are unreliable for security-scoped URLs
            // returned by the iOS file picker, so surface real enumeration
            // failures here instead of pre-gating with isReadableFile.
            throw RecordingLibraryError.folderUnreadable(folderPath)
        }

        return recordings(from: urls, metadata: metadata, requireRegularFile: true)
    }

    public func scan(urls: [URL], metadata: RecordingLibraryMetadata) throws -> [Recording] {
        var recordingsByID: [String: Recording] = [:]

        for url in urls {
            let recordings: [Recording]
            if isDirectory(url) {
                recordings = try scan(folder: url, metadata: metadata)
            } else {
                recordings = self.recordings(from: [url], metadata: metadata, requireRegularFile: false)
            }

            for recording in recordings {
                recordingsByID[recording.id] = recording
            }
        }

        return sort(Array(recordingsByID.values))
    }

    private func isDirectory(_ url: URL) -> Bool {
        if let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory {
            return isDirectory
        }
        var isDirectory: ObjCBool = false
        _ = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private func recordings(
        from urls: [URL],
        metadata: RecordingLibraryMetadata,
        requireRegularFile: Bool
    ) -> [Recording] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        let recordings = urls.compactMap { url -> Recording? in
            let values = try? url.resourceValues(forKeys: keys)
            if requireRegularFile, values?.isRegularFile != true {
                return nil
            }
            if !requireRegularFile, values?.isRegularFile == false {
                return nil
            }
            let fileExtension = url.pathExtension.lowercased()
            guard supportedExtensions.contains(fileExtension) else {
                return nil
            }

            let key = RecordingKey.make(for: url)
            guard !metadata.hiddenRecordingIDs.contains(key) else {
                return nil
            }
            let recordMetadata = metadata.records[key]
            return Recording(
                id: key,
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                fileExtension: fileExtension,
                fileSize: values?.fileSize.map(Int64.init),
                createdAt: values?.creationDate,
                modifiedAt: values?.contentModificationDate,
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
