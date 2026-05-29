import Foundation

public struct TranscriptionWindow: Equatable {
    public let startSample: Int
    public let endSample: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(startSample: Int, endSample: Int, sampleRate: Int) {
        self.startSample = startSample
        self.endSample = endSample
        self.startTime = TimeInterval(startSample) / TimeInterval(sampleRate)
        self.endTime = TimeInterval(endSample) / TimeInterval(sampleRate)
    }
}

public enum TranscriptionWindowPlanner {
    public static func shouldUseFullCoverage(
        sampleCount: Int,
        sampleRate: Int = 16_000,
        thresholdDuration: TimeInterval = 120
    ) -> Bool {
        guard sampleCount > 0, sampleRate > 0, thresholdDuration > 0 else {
            return false
        }
        return TimeInterval(sampleCount) / TimeInterval(sampleRate) >= thresholdDuration
    }

    public static func fixedWindows(
        sampleCount: Int,
        sampleRate: Int = 16_000,
        windowDuration: TimeInterval = 25
    ) -> [TranscriptionWindow] {
        guard sampleCount > 0, sampleRate > 0, windowDuration > 0 else {
            return []
        }

        let windowSize = max(1, Int(windowDuration * TimeInterval(sampleRate)))
        var windows: [TranscriptionWindow] = []
        var cursor = 0
        while cursor < sampleCount {
            let end = min(cursor + windowSize, sampleCount)
            windows.append(TranscriptionWindow(startSample: cursor, endSample: end, sampleRate: sampleRate))
            cursor = end
        }
        return windows
    }
}
