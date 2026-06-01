import Foundation
import RecordReaderCore

enum DebugSettings {
    static let sherpaThreadCountKey = "debug.sherpaThreadCount"

    static var sherpaThreadCount: SherpaThreadCount {
        get {
            SherpaThreadCount(
                rawValueOrDefault: UserDefaults.standard.integer(forKey: sherpaThreadCountKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sherpaThreadCountKey)
        }
    }
}
