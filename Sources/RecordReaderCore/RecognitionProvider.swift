import Foundation

public enum RecognitionProvider: String, CaseIterable, Equatable, Identifiable {
    case cpu
    case coreML = "coreml"

    public static let defaultValue = RecognitionProvider.cpu

    public init(rawValueOrDefault rawValue: String) {
        self = RecognitionProvider(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .cpu:
            return "CPU"
        case .coreML:
            return "CoreML"
        }
    }

    public var logLabel: String {
        switch self {
        case .cpu:
            return "CPU"
        case .coreML:
            return "CoreML(实验)"
        }
    }

    public var shouldRetryCPUWhenRecognitionIsEmpty: Bool {
        self == .coreML
    }

    public var shouldRetryCPUOnProviderFailure: Bool {
        self == .coreML
    }

    public var runtimeDebugValue: Int {
        switch self {
        case .cpu:
            return 0
        case .coreML:
            return 1
        }
    }
}
