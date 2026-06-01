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

public struct TranscriptionWindowSamples: Equatable {
    public let window: TranscriptionWindow
    public let samples: [Float]

    public init(window: TranscriptionWindow, samples: [Float]) {
        self.window = window
        self.samples = samples
    }
}

public struct TranscriptionWindowBuffer {
    private let sampleRate: Int
    private let windowSize: Int
    private var nextStartSample = 0
    private var pendingSamples: [Float] = []

    public init(sampleRate: Int = 16_000, windowDuration: TimeInterval = 25) {
        self.sampleRate = sampleRate
        if sampleRate > 0, windowDuration > 0 {
            self.windowSize = max(1, Int(windowDuration * TimeInterval(sampleRate)))
        } else {
            self.windowSize = 0
        }
    }

    public mutating func append(_ samples: [Float]) -> [TranscriptionWindowSamples] {
        guard windowSize > 0, !samples.isEmpty else {
            return []
        }

        pendingSamples.append(contentsOf: samples)
        var windows: [TranscriptionWindowSamples] = []
        while pendingSamples.count >= windowSize {
            let windowSamples = Array(pendingSamples.prefix(windowSize))
            let endSample = nextStartSample + windowSamples.count
            windows.append(
                TranscriptionWindowSamples(
                    window: TranscriptionWindow(
                        startSample: nextStartSample,
                        endSample: endSample,
                        sampleRate: sampleRate
                    ),
                    samples: windowSamples
                )
            )
            nextStartSample = endSample
            pendingSamples.removeFirst(windowSize)
        }
        return windows
    }

    public mutating func finish() -> TranscriptionWindowSamples? {
        guard windowSize > 0, !pendingSamples.isEmpty else {
            return nil
        }

        let windowSamples = pendingSamples
        let endSample = nextStartSample + windowSamples.count
        pendingSamples = []
        defer {
            nextStartSample = endSample
        }
        return TranscriptionWindowSamples(
            window: TranscriptionWindow(
                startSample: nextStartSample,
                endSample: endSample,
                sampleRate: sampleRate
            ),
            samples: windowSamples
        )
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
