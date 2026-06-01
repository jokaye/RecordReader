import Foundation

public enum TranscriptionWorkerCount: Int, CaseIterable, Equatable, Identifiable {
    case auto = 0
    case one = 1
    case two = 2
    case three = 3

    public static let defaultValue = TranscriptionWorkerCount.auto

    public init(rawValueOrDefault rawValue: Int) {
        self = TranscriptionWorkerCount(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: Int {
        rawValue
    }

    public var label: String {
        guard self != .auto else {
            return "Auto"
        }
        return "\(rawValue)"
    }

    public func effectiveWorkerCount(totalWindows: Int) -> Int {
        let requested: Int
        switch self {
        case .auto:
            requested = 2
        case .one, .two, .three:
            requested = rawValue
        }
        return min(max(1, requested), max(1, totalWindows))
    }
}
