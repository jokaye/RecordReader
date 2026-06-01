import CoreML
import Foundation
import RecordReaderCore
@preconcurrency import WhisperKit

actor WhisperKitTranscriber {
    private var engine: WhisperKit?
    private var loadedModelVariant: WhisperKitModelVariant?

    func preload(modelVariant: WhisperKitModelVariant) async throws {
        _ = try await loadEngine(modelVariant: modelVariant)
    }

    func transcribe(
        url: URL,
        modelVariant: WhisperKitModelVariant,
        progress: @escaping @Sendable (SubtitleRecognitionProgress) -> Void
    ) async throws -> [SubtitleSegment] {
        progress(.readingAudio)
        let startedAt = Date()
        let didStartScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let preparedAudio = try PathBasedAudioInputPreparer.prepareStableReadableFile(
            from: url,
            in: Self.temporaryAudioInputDirectory()
        )
        defer {
            try? FileManager.default.removeItem(at: preparedAudio.url)
        }
        DebugLog.shared.log("WhisperKit 输入已准备：源=\(url.lastPathComponent)，临时文件=\(preparedAudio.url.lastPathComponent)，securityScope=\(didStartScope ? "已获取" : "未获取")")

        let engine = try await loadEngine(modelVariant: modelVariant)
        progress(.recognizing(completedSegments: 0, totalSegments: nil))

        let decodingSettings = WhisperKitDecodingSettings.qualityFirstChinese
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: decodingSettings.languageCode,
            temperature: 0,
            temperatureFallbackCount: decodingSettings.temperatureFallbackCount,
            usePrefillPrompt: decodingSettings.usesPrefillPrompt,
            detectLanguage: false,
            skipSpecialTokens: true,
            wordTimestamps: false,
            concurrentWorkerCount: decodingSettings.concurrentWorkerCount,
            chunkingStrategy: decodingSettings.usesVADChunking ? .vad : nil
        )
        DebugLog.shared.log("WhisperKit 解码配置：language=\(decodingSettings.languageCode)，worker=\(decodingSettings.concurrentWorkerCount)，fallback=\(decodingSettings.temperatureFallbackCount)，VAD=\(decodingSettings.usesVADChunking ? "开" : "关")")
        let results = try await engine.transcribe(
            audioPath: preparedAudio.url.path,
            decodeOptions: options
        )
        let segments = Self.subtitleSegments(from: results)
        Self.logTranscriptionDiagnostics(results, modelVariant: modelVariant)
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
        try FileManager.default.createDirectory(at: modelCacheURL, withIntermediateDirectories: true)
        let computeOptions = ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine
        )
        let bundledModelFolder = Self.bundledModelFolder(for: modelVariant)
        let config: WhisperKitConfig
        if let bundledModelFolder {
            config = WhisperKitConfig(
                model: modelVariant.modelName,
                downloadBase: modelCacheURL,
                modelFolder: bundledModelFolder.path,
                tokenizerFolder: bundledModelFolder,
                computeOptions: computeOptions,
                verbose: false,
                prewarm: true,
                load: true,
                download: false,
                useBackgroundDownloadSession: false
            )
        } else {
            config = WhisperKitConfig(
                model: modelVariant.modelName,
                downloadBase: modelCacheURL,
                computeOptions: computeOptions,
                verbose: false,
                prewarm: true,
                load: true,
                download: true,
                useBackgroundDownloadSession: false
            )
        }
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

    private static func logTranscriptionDiagnostics(
        _ results: [TranscriptionResult],
        modelVariant: WhisperKitModelVariant
    ) {
        let segments = results.flatMap(\.segments)
        let preview = segments
            .prefix(3)
            .map { segment in
                segment.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
            }
            .joined(separator: " / ")
        let languages = Set(results.map(\.language)).sorted().joined(separator: ",")
        let avgLogProb = segments.isEmpty ? nil : segments.map(\.avgLogprob).reduce(0, +) / Float(segments.count)
        let avgCompressionRatio = segments.isEmpty ? nil : segments.map(\.compressionRatio).reduce(0, +) / Float(segments.count)
        DebugLog.shared.log(
            String(
                format: "WhisperKit 诊断：模型=%@，results=%d，segments=%d，language=%@，avgLogProb=%@，avgCompression=%@，预览=%@",
                modelVariant.title,
                results.count,
                segments.count,
                languages.isEmpty ? "无" : languages,
                avgLogProb.map { String(format: "%.2f", $0) } ?? "无",
                avgCompressionRatio.map { String(format: "%.2f", $0) } ?? "无",
                preview.isEmpty ? "无" : preview
            )
        )
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

    private static func bundledModelFolder(for modelVariant: WhisperKitModelVariant) -> URL? {
        guard let directoryName = modelVariant.bundledModelDirectoryName else {
            return nil
        }
        if let modelFolder = Bundle.main.url(
            forResource: directoryName,
            withExtension: nil,
            subdirectory: "WhisperKitModels"
        ) {
            return modelFolder
        }

        let requiredRootResources = [
            Bundle.main.url(forResource: "AudioEncoder", withExtension: "mlmodelc"),
            Bundle.main.url(forResource: "MelSpectrogram", withExtension: "mlmodelc"),
            Bundle.main.url(forResource: "TextDecoder", withExtension: "mlmodelc"),
            Bundle.main.url(forResource: "tokenizer", withExtension: "json")
        ]
        guard requiredRootResources.allSatisfy({ $0 != nil }) else {
            return nil
        }
        return Bundle.main.resourceURL
    }

    private static func temporaryAudioInputDirectory() -> URL {
        FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("RecordReader", isDirectory: true)
        .appendingPathComponent("WhisperKitAudioInputs", isDirectory: true)
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
