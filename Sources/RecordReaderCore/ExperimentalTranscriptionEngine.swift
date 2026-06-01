import Foundation

public enum ExperimentalTranscriptionEngine: String, CaseIterable, Equatable, Identifiable {
    case sherpaOnnx
    case whisperKitCoreML

    public static let defaultValue = ExperimentalTranscriptionEngine.sherpaOnnx

    public init(rawValueOrDefault rawValue: String) {
        self = ExperimentalTranscriptionEngine(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .sherpaOnnx:
            return "sherpa-onnx"
        case .whisperKitCoreML:
            return "WhisperKit CoreML 实验"
        }
    }
}

public enum WhisperKitModelVariant: String, CaseIterable, Equatable, Identifiable {
    case tiny
    case base
    case smallCompressed = "small_216MB"

    public static let defaultValue = WhisperKitModelVariant.smallCompressed

    public init(rawValueOrDefault rawValue: String) {
        self = WhisperKitModelVariant(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .base:
            return "Base"
        case .smallCompressed:
            return "Small 216MB"
        }
    }

    public var modelName: String {
        switch self {
        case .tiny:
            return "whisper-tiny"
        case .base:
            return "whisper-base"
        case .smallCompressed:
            return rawValue
        }
    }

    public var estimatedDownloadSize: String {
        switch self {
        case .tiny:
            return "约 77MB"
        case .base:
            return "约 147MB"
        case .smallCompressed:
            return "约 217MB"
        }
    }
}
