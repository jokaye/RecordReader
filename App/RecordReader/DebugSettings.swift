import Foundation
import RecordReaderCore

enum DebugSettings {
    static let sherpaThreadCountKey = "debug.sherpaThreadCount"
    static let transcriptionWindowDurationKey = "debug.transcriptionWindowDuration"

    static var sherpaThreadCount: SherpaThreadCount {
        get {
            guard UserDefaults.standard.object(forKey: sherpaThreadCountKey) != nil else {
                return .defaultValue
            }
            SherpaThreadCount(
                rawValueOrDefault: UserDefaults.standard.integer(forKey: sherpaThreadCountKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sherpaThreadCountKey)
        }
    }

    static var transcriptionWindowDuration: TranscriptionWindowDuration {
        get {
            guard UserDefaults.standard.object(forKey: transcriptionWindowDurationKey) != nil else {
                return .defaultValue
            }
            TranscriptionWindowDuration(
                rawValueOrDefault: UserDefaults.standard.integer(forKey: transcriptionWindowDurationKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: transcriptionWindowDurationKey)
        }
    }
}
