import Foundation

public enum TranscriptionPerformanceTier: Equatable {
    case standard
    case high

    public init(deviceIdentifier: String) {
        guard deviceIdentifier.hasPrefix("iPhone") else {
            self = .standard
            return
        }

        let version = deviceIdentifier
            .dropFirst("iPhone".count)
            .split(separator: ",")
            .compactMap { Int($0) }
        guard let generation = version.first else {
            self = .standard
            return
        }

        if generation > 15 {
            self = .high
        } else if generation == 15, let variant = version.dropFirst().first, variant >= 2 {
            self = .high
        } else {
            self = .standard
        }
    }
}

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

    public func effectiveWorkerCount(
        totalWindows: Int,
        performanceTier: TranscriptionPerformanceTier = .standard
    ) -> Int {
        let requested: Int
        switch self {
        case .auto:
            requested = 1
        case .one, .two, .three:
            requested = rawValue
        }
        return min(max(1, requested), max(1, totalWindows))
    }
}
