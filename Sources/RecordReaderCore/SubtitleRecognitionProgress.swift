import Foundation

public enum SubtitleRecognitionPhase: Equatable {
    case readingAudio
    case recognizing
    case finalizing
    case fallback
}

public struct SubtitleRecognitionProgress: Equatable {
    public var phase: SubtitleRecognitionPhase
    public var completedSegments: Int
    public var totalSegments: Int?

    public init(phase: SubtitleRecognitionPhase, completedSegments: Int = 0, totalSegments: Int? = nil) {
        self.phase = phase
        self.completedSegments = max(0, completedSegments)
        self.totalSegments = totalSegments.flatMap { $0 > 0 ? $0 : nil }
    }

    public static let readingAudio = SubtitleRecognitionProgress(phase: .readingAudio)
    public static let finalizing = SubtitleRecognitionProgress(phase: .finalizing)
    public static let fallback = SubtitleRecognitionProgress(phase: .fallback)

    public static func recognizing(completedSegments: Int, totalSegments: Int?) -> SubtitleRecognitionProgress {
        SubtitleRecognitionProgress(
            phase: .recognizing,
            completedSegments: completedSegments,
            totalSegments: totalSegments
        )
    }

    public var title: String {
        "正在生成字幕"
    }

    public var detail: String {
        switch phase {
        case .readingAudio:
            return "正在读取音频..."
        case .recognizing:
            guard let totalSegments else {
                return "正在识别音频内容..."
            }
            guard completedSegments < totalSegments else {
                return "正在整理字幕..."
            }
            return "正在识别第 \(completedSegments + 1) 段，共 \(totalSegments) 段"
        case .finalizing:
            return "正在整理字幕..."
        case .fallback:
            return "本地识别暂不可用，正在改用 iOS 语音识别..."
        }
    }

    public var fractionCompleted: Double? {
        guard let totalSegments else {
            return nil
        }
        let clampedCompleted = min(max(0, completedSegments), totalSegments)
        return Double(clampedCompleted) / Double(totalSegments)
    }
}
