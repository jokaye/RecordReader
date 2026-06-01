import Foundation

public enum TranscriptionWindowDuration: Int, CaseIterable, Equatable, Identifiable {
    case twentyFiveSeconds = 25
    case thirtyFiveSeconds = 35
    case fortyFiveSeconds = 45

    public static let defaultValue = TranscriptionWindowDuration.twentyFiveSeconds

    public init(rawValueOrDefault rawValue: Int) {
        self = TranscriptionWindowDuration(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: Int {
        rawValue
    }

    public var duration: TimeInterval {
        TimeInterval(rawValue)
    }

    public var label: String {
        "\(rawValue)s"
    }
}
