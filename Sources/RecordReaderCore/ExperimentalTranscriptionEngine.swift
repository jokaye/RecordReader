import Foundation

public enum ExperimentalTranscriptionEngine: String, CaseIterable, Equatable, Identifiable {
    case sherpaOnnx
    case whisperKitCoreML

    public static let defaultValue = ExperimentalTranscriptionEngine.whisperKitCoreML

    public init(rawValueOrDefault rawValue: String) {
        self = ExperimentalTranscriptionEngine(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .sherpaOnnx:
            return "sherpa-onnx"
        case .whisperKitCoreML:
            return "WhisperKit CoreML 实验"
        }
    }
}

public enum WhisperKitModelVariant: String, CaseIterable, Equatable, Identifiable {
    case tiny
    case base
    case smallCompressed = "small_216MB"

    public static let defaultValue = WhisperKitModelVariant.smallCompressed

    public init(rawValueOrDefault rawValue: String) {
        self = WhisperKitModelVariant(rawValue: rawValue) ?? Self.defaultValue
    }

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .base:
            return "Base"
        case .smallCompressed:
            return "Small 216MB"
        }
    }

    public var modelName: String {
        switch self {
        case .tiny:
            return "whisper-tiny"
        case .base:
            return "whisper-base"
        case .smallCompressed:
            return rawValue
        }
    }

    public var estimatedDownloadSize: String {
        switch self {
        case .tiny:
            return "约 77MB"
        case .base:
            return "约 147MB"
        case .smallCompressed:
            return "约 217MB"
        }
    }

    public var isBundledInExperiment: Bool {
        self == .smallCompressed
    }

    public var bundledModelDirectoryName: String? {
        switch self {
        case .smallCompressed:
            return "openai_whisper-small_216MB"
        case .tiny, .base:
            return nil
        }
    }
}

public struct WhisperKitDecodingSettings: Equatable {
    public let languageCode: String
    public let concurrentWorkerCount: Int
    public let temperatureFallbackCount: Int
    public let usesVADChunking: Bool
    public let usesPrefillPrompt: Bool

    public init(
        languageCode: String,
        concurrentWorkerCount: Int,
        temperatureFallbackCount: Int,
        usesVADChunking: Bool,
        usesPrefillPrompt: Bool
    ) {
        self.languageCode = languageCode
        self.concurrentWorkerCount = concurrentWorkerCount
        self.temperatureFallbackCount = temperatureFallbackCount
        self.usesVADChunking = usesVADChunking
        self.usesPrefillPrompt = usesPrefillPrompt
    }

    public static let qualityFirstChinese = WhisperKitDecodingSettings(
        languageCode: "zh",
        concurrentWorkerCount: 1,
        temperatureFallbackCount: 0,
        usesVADChunking: false,
        usesPrefillPrompt: true
    )
}

public struct WhisperKitTranscriptionQualityGate: Equatable {
    public let maximumAverageCompressionRatio: Float
    public let minimumAverageLogProbability: Float
    public let maximumRepeatedTextRatio: Double
    public let minimumSegmentsForRepetitionCheck: Int

    public init(
        maximumAverageCompressionRatio: Float,
        minimumAverageLogProbability: Float,
        maximumRepeatedTextRatio: Double,
        minimumSegmentsForRepetitionCheck: Int
    ) {
        self.maximumAverageCompressionRatio = maximumAverageCompressionRatio
        self.minimumAverageLogProbability = minimumAverageLogProbability
        self.maximumRepeatedTextRatio = maximumRepeatedTextRatio
        self.minimumSegmentsForRepetitionCheck = minimumSegmentsForRepetitionCheck
    }

    public static let qualityFirstChinese = WhisperKitTranscriptionQualityGate(
        maximumAverageCompressionRatio: 2.4,
        minimumAverageLogProbability: -1.0,
        maximumRepeatedTextRatio: 0.35,
        minimumSegmentsForRepetitionCheck: 6
    )

    public func rejectionReason(
        segmentTexts: [String],
        averageLogProbability: Float?,
        averageCompressionRatio: Float?
    ) -> String? {
        if let averageCompressionRatio,
           averageCompressionRatio > maximumAverageCompressionRatio {
            return String(
                format: "WhisperKit 输出疑似重复幻觉：平均压缩率 %.2f 超过阈值 %.2f。",
                averageCompressionRatio,
                maximumAverageCompressionRatio
            )
        }

        if let averageLogProbability,
           averageLogProbability < minimumAverageLogProbability {
            return String(
                format: "WhisperKit 输出可信度过低：平均 log probability %.2f 低于阈值 %.2f。",
                averageLogProbability,
                minimumAverageLogProbability
            )
        }

        let normalizedTexts = segmentTexts
            .map(normalize)
            .filter { !$0.isEmpty }
        guard normalizedTexts.count >= minimumSegmentsForRepetitionCheck else {
            return nil
        }

        var counts: [String: Int] = [:]
        for text in normalizedTexts {
            counts[text, default: 0] += 1
        }
        guard let mostRepeated = counts.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let repeatedRatio = Double(mostRepeated.value) / Double(normalizedTexts.count)
        if repeatedRatio > maximumRepeatedTextRatio {
            return String(
                format: "WhisperKit 输出疑似重复幻觉：同一句“%@”占比 %.0f%%。",
                mostRepeated.key,
                repeatedRatio * 100
            )
        }
        return nil
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
}
