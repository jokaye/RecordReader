import Foundation

public enum SherpaThreadCount: Int, CaseIterable, Equatable, Identifiable {
    case one = 1
    case two = 2
    case four = 4

    public static let defaultValue = SherpaThreadCount.two

    public init(rawValueOrDefault rawValue: Int) {
        self = SherpaThreadCount(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: Int {
        rawValue
    }

    public var label: String {
        "\(rawValue)"
    }
}
