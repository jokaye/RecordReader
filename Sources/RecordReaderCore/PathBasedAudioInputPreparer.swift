import Foundation

public enum PathBasedAudioInputPreparerError: Error, LocalizedError, Equatable {
    case sourceMissing(String)
    case sourceIsDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .sourceMissing(let path):
            return "音频文件不存在或已不可访问：\(path)"
        case .sourceIsDirectory(let path):
            return "选择的是文件夹，不是音频文件：\(path)"
        }
    }
}

public struct PreparedPathBasedAudioInput: Equatable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

public enum PathBasedAudioInputPreparer {
    public static func prepareStableReadableFile(
        from sourceURL: URL,
        in workingDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> PreparedPathBasedAudioInput {
        let sourcePath = sourceURL.path
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
            throw PathBasedAudioInputPreparerError.sourceMissing(sourcePath)
        }
        guard !isDirectory.boolValue else {
            throw PathBasedAudioInputPreparerError.sourceIsDirectory(sourcePath)
        }

        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.nilIfEmpty ?? "audio"
        let destinationURL = workingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return PreparedPathBasedAudioInput(url: destinationURL)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
