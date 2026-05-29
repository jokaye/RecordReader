import Foundation

public enum PlaybackSpeed: Double, CaseIterable, Codable, Equatable {
    case half = 0.5
    case threeQuarters = 0.75
    case normal = 1.0
    case fiveQuarters = 1.25
    case threeHalves = 1.5
    case double = 2.0

    public static let `default`: PlaybackSpeed = .normal

    public var multiplier: Double {
        rawValue
    }

    public var rate: Float {
        Float(rawValue)
    }

    public var label: String {
        let trimmed = String(format: "%g", rawValue)
        return "\(trimmed)x"
    }

    public func next() -> PlaybackSpeed {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else {
            return .normal
        }
        return all[(index + 1) % all.count]
    }
}
