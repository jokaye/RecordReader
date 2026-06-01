import Foundation
import RecordReaderCore
import UIKit

enum DeviceProfile {
    static var identifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let bytes = mirror.children.compactMap { child -> UInt8? in
            guard let value = child.value as? Int8, value != 0 else {
                return nil
            }
            return UInt8(value)
        }
        return String(bytes: bytes, encoding: .utf8) ?? UIDevice.current.model
    }

    static var transcriptionPerformanceTier: TranscriptionPerformanceTier {
        TranscriptionPerformanceTier(deviceIdentifier: identifier)
    }
}
