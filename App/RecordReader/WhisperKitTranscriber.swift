import CoreML
import Foundation
import RecordReaderCore
@preconcurrency import WhisperKit

actor WhisperKitTranscriber {
    private var engine: WhisperKit?
    private var loadedModelVariant: WhisperKitModelVariant?

    func transcribe(
        url: URL,
        modelVariant: WhisperKitModelVariant,
        progress: @escaping @Sendable (SubtitleRecognitionProgress) -> Void
    ) async throws -> [SubtitleSegment] {
        progress(.readingAudio)
        let startedAt = Date()
        let engine = try await loadEngine(modelVariant: modelVariant)
        progress(.recognizing(completedSegments: 0, totalSegments: nil))

        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "zh",
            temperature: 0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            wordTimestamps: false,
            concurrentWorkerCount: 2,
            chunkingStrategy: .vad
        )
        let results = try await engine.transcribe(
            audioPath: url.path,
            decodeOptions: options
        )
        let segments = Self.subtitleSegments(from: results)
        DebugLog.shared.log(
            String(
                format: "WhisperKit CoreML 实验完成：模型=%@，结果=%d，字幕=%d，用时 %.2f 秒",
                modelVariant.title,
                results.count,
                segments.count,
                Date().timeIntervalSince(startedAt)
            )
        )
        guard !segments.isEmpty else {
            throw WhisperKitTranscriberError.noSpeechDetected
        }
        progress(.finalizing)
        return segments
    }

    private func loadEngine(modelVariant: WhisperKitModelVariant) async throws -> WhisperKit {
        if let engine, loadedModelVariant == modelVariant {
            return engine
        }

        let modelCacheURL = try Self.modelCacheURL()
        try FileManager.default.createDirectory(
            at: modelCacheURL,
            withIntermediateDirectories: true
        )
        let computeOptions = ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine
        )
        let config = WhisperKitConfig(
            model: modelVariant.modelName,
            downloadBase: modelCacheURL,
            computeOptions: computeOptions,
            verbose: false,
            prewarm: true,
            load: true,
            download: true,
            useBackgroundDownloadSession: false
        )
        DebugLog.shared.log("开始加载 WhisperKit CoreML 实验模型：\(modelVariant.title)（\(modelVariant.estimatedDownloadSize)）")
        let startedAt = Date()
        let nextEngine = try await WhisperKit(config)
        nextEngine.transcriptionStateCallback = { state in
            DebugLog.shared.log("WhisperKit 状态：\(state.description)")
        }
        engine = nextEngine
        loadedModelVariant = modelVariant
        DebugLog.shared.log(
            String(
                format: "WhisperKit CoreML 实验模型已加载：%@，用时 %.2f 秒",
                modelVariant.title,
                Date().timeIntervalSince(startedAt)
            )
        )
        return nextEngine
    }

    private static func subtitleSegments(from results: [TranscriptionResult]) -> [SubtitleSegment] {
        results
            .flatMap(\.segments)
            .compactMap { segment -> SubtitleSegment? in
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    return nil
                }
                return SubtitleSegment(
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(max(segment.end, segment.start)),
                    text: text
                )
            }
            .sorted { lhs, rhs in
                lhs.startTime < rhs.startTime
            }
    }

    private static func modelCacheURL() throws -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent("RecordReader", isDirectory: true)
            .appendingPathComponent("WhisperKitModels", isDirectory: true)
    }
}

enum WhisperKitTranscriberError: Error, LocalizedError {
    case noSpeechDetected

    var errorDescription: String? {
        switch self {
        case .noSpeechDetected:
            return "WhisperKit 没有从这段音频中识别到中文语音。"
        }
    }
}
