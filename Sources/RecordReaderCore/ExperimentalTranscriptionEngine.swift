import Foundation

public enum ExperimentalTranscriptionEngine: String, CaseIterable, Equatable, Identifiable {
    case sherpaOnnx
    case whisperKitCoreML

    public static let defaultValue = ExperimentalTranscriptionEngine.sherpaOnnx

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
