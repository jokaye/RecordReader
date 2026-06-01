import Foundation

public enum SherpaThreadCount: Int, CaseIterable, Equatable, Identifiable {
    case auto = 0
    case one = 1
    case two = 2
    case four = 4
    case six = 6
    case eight = 8

    public static let defaultValue = SherpaThreadCount.two

    public init(rawValueOrDefault rawValue: Int) {
        self = SherpaThreadCount(rawValue: rawValue) ?? Self.defaultValue
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
}
