import AVFoundation
import Foundation
import RecordReaderCore

actor SherpaOnnxTranscriber {
    private static let sampleRate = 16_000
    private static let featureDim = 80
    private static let fullCoverageThresholdDuration: TimeInterval = 120

    private var recognizer: SherpaOnnxOfflineRecognizer?
    private var vad: SherpaOnnxVoiceActivityDetectorWrapper?
    private var vadModelConfig: SherpaOnnxVadModelConfig?
    private var loadedThreadCount: SherpaThreadCount?
    private var loadedRecognitionProvider: RecognitionProvider?

    func transcribe(
        url: URL,
        threadCount: SherpaThreadCount = .defaultValue,
        windowDuration: TranscriptionWindowDuration = .defaultValue,
        recognitionProvider: RecognitionProvider = .defaultValue,
        progress: @escaping @Sendable (SubtitleRecognitionProgress) -> Void = { _ in }
    ) async throws -> [SubtitleSegment] {
        let startedAt = Date()
        let didStartScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        progress(.readingAudio)
        let engine = try loadEngine(threadCount: threadCount, recognitionProvider: recognitionProvider)
        let asset = AVURLAsset(url: url)
        let assetDuration = try await audioDuration(for: asset)
        if assetDuration >= Self.fullCoverageThresholdDuration {
            return try await transcribeLongAudio(
                asset: asset,
                recognizer: engine.recognizer,
                startedAt: startedAt,
                expectedDuration: assetDuration,
                windowDuration: windowDuration,
                progress: progress
            )
        }

        let decodeStartedAt = Date()
        let samples = try await decodeAudioFile(asset)
        guard !samples.isEmpty else {
            throw SherpaOnnxTranscriberError.noDecodableAudio
        }
        let decodedDuration = TimeInterval(samples.count) / TimeInterval(Self.sampleRate)
        DebugLog.shared.log(
            String(
                format: "sherpa-onnx 解码完成：%.1f 秒，%d 个采样，用时 %.2f 秒",
                decodedDuration,
                samples.count,
                Date().timeIntervalSince(decodeStartedAt)
            )
        )

        if TranscriptionWindowPlanner.shouldUseFullCoverage(
            sampleCount: samples.count,
            sampleRate: Self.sampleRate,
            thresholdDuration: Self.fullCoverageThresholdDuration
        ) {
            let segments = decodeFixedWindows(
                samples: samples,
                recognizer: engine.recognizer,
                windowDuration: windowDuration,
                progress: progress
            )
            DebugLog.shared.log("sherpa-onnx 长音频全覆盖识别完成：\(segments.count) 段字幕")
            if segments.isEmpty {
                throw SherpaOnnxTranscriberError.noSpeechDetected
            }
            progress(.finalizing)
            return segments
        }

        let windowSize = Int(engine.vadModelConfig.silero_vad.window_size)
        guard windowSize > 0 else {
            throw SherpaOnnxTranscriberError.invalidVadWindow
        }

        progress(.recognizing(completedSegments: 0, totalSegments: nil))
        engine.vad.reset()
        var cursor = 0
        var segments: [SubtitleSegment] = []
        while cursor < samples.count {
            let end = min(cursor + windowSize, samples.count)
            engine.vad.acceptWaveform(samples: Array(samples[cursor..<end]))
            drainVad(engine: engine, into: &segments)
            cursor = end
        }

        engine.vad.flush()
        drainVad(engine: engine, into: &segments)

        if segments.isEmpty {
            let fallback = decodeFixedWindows(
                samples: samples,
                recognizer: engine.recognizer,
                windowDuration: windowDuration,
                progress: progress
            )
            DebugLog.shared.log("sherpa-onnx VAD 未产出字幕，固定窗口兜底完成：\(fallback.count) 段字幕")
            if fallback.isEmpty {
                throw SherpaOnnxTranscriberError.noSpeechDetected
            }
            progress(.finalizing)
            return fallback
        }

        progress(.finalizing)
        DebugLog.shared.log(
            String(
                format: "sherpa-onnx VAD 识别完成：%d 段字幕，总用时 %.2f 秒",
                segments.count,
                Date().timeIntervalSince(startedAt)
            )
        )
        return segments
    }

    private func loadEngine(
        threadCount: SherpaThreadCount,
        recognitionProvider: RecognitionProvider
    ) throws -> SherpaOnnxEngine {
        if let recognizer,
           let vad,
           let vadModelConfig,
           loadedThreadCount == threadCount,
           loadedRecognitionProvider == recognitionProvider {
            return SherpaOnnxEngine(recognizer: recognizer, vad: vad, vadModelConfig: vadModelConfig)
        }
        let loadStartedAt = Date()

        let model = try bundledResource(
            name: "model.int8",
            extension: "onnx",
            subdirectory: "SherpaOnnxModels/paraformer-zh"
        )
        let tokens = try bundledResource(
            name: "tokens",
            extension: "txt",
            subdirectory: "SherpaOnnxModels/paraformer-zh"
        )
        let vadModel = try bundledResource(
            name: "silero_vad",
            extension: "onnx",
            subdirectory: "SherpaOnnxModels/vad"
        )

        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: Self.sampleRate,
            featureDim: Self.featureDim
        )
        if recognitionProvider.runtimeDebugValue > 0 {
            DebugLog.shared.log("CoreML 运行时诊断已开启；请在设备系统日志中查看 ONNX Runtime/CoreML 节点分配信息")
        }
        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: tokens.path,
            paraformer: sherpaOnnxOfflineParaformerModelConfig(model: model.path),
            numThreads: threadCount.rawValue,
            provider: recognitionProvider.rawValue,
            debug: recognitionProvider.runtimeDebugValue,
            modelType: "paraformer"
        )
        var recognizerConfig = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig
        )
        let recognizer = try SherpaOnnxOfflineRecognizer(config: &recognizerConfig)

        let sileroVadConfig = sherpaOnnxSileroVadModelConfig(model: vadModel.path)
        var vadModelConfig = sherpaOnnxVadModelConfig(sileroVad: sileroVadConfig)
        let vad = SherpaOnnxVoiceActivityDetectorWrapper(
            config: &vadModelConfig,
            buffer_size_in_seconds: 120
        )

        self.recognizer = recognizer
        self.vad = vad
        self.vadModelConfig = vadModelConfig
        self.loadedThreadCount = threadCount
        self.loadedRecognitionProvider = recognitionProvider
        DebugLog.shared.log(
            String(
                format: "sherpa-onnx 引擎已加载：线程数=%@，后端=%@，用时 %.2f 秒",
                threadCount.label,
                recognitionProvider.logLabel,
                Date().timeIntervalSince(loadStartedAt)
            )
        )
        return SherpaOnnxEngine(recognizer: recognizer, vad: vad, vadModelConfig: vadModelConfig)
    }

    private func bundledResource(name: String, extension fileExtension: String, subdirectory: String) throws -> URL {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        ) ?? Bundle.main.url(
            forResource: name,
            withExtension: fileExtension
        ) else {
            throw SherpaOnnxTranscriberError.missingModelResource("\(subdirectory)/\(name).\(fileExtension)")
        }
        return url
    }

    private func audioDuration(for asset: AVURLAsset) async throws -> TimeInterval {
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            guard seconds.isFinite, seconds > 0 else {
                return 0
            }
            return seconds
        } catch {
            throw SherpaOnnxTranscriberError.audioFileUnreadable("无法读取音频时长：\(error.localizedDescription)")
        }
    }

    private func decodeAudioFile(_ asset: AVURLAsset) async throws -> [Float] {
        var samples: [Float] = []
        _ = try await decodeAudioFile(asset) { chunk in
            samples.append(contentsOf: chunk)
        }
        return samples
    }

    @discardableResult
    private func decodeAudioFile(_ asset: AVURLAsset, onSamples: ([Float]) throws -> Void) async throws -> Int {
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw SherpaOnnxTranscriberError.audioFileUnreadable("无法读取音轨：\(error.localizedDescription)")
        }
        guard let track = tracks.first else {
            throw SherpaOnnxTranscriberError.noAudioTrack
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw SherpaOnnxTranscriberError.audioFileUnreadable("无法创建音频读取器：\(error.localizedDescription)")
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else {
            throw SherpaOnnxTranscriberError.audioConversionFailed("无法添加音频解码输出。")
        }
        reader.add(readerOutput)

        guard reader.startReading() else {
            throw SherpaOnnxTranscriberError.audioConversionFailed(
                reader.error?.localizedDescription ?? "无法开始读取音频。"
            )
        }

        var decodedSampleCount = 0
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            let samples = try samples(from: sampleBuffer)
            decodedSampleCount += samples.count
            try onSamples(samples)
        }

        switch reader.status {
        case .completed:
            return decodedSampleCount
        case .failed:
            throw SherpaOnnxTranscriberError.audioConversionFailed(
                reader.error?.localizedDescription ?? "音频解码失败。"
            )
        case .cancelled:
            throw SherpaOnnxTranscriberError.audioConversionFailed("音频解码被取消。")
        case .reading, .unknown:
            throw SherpaOnnxTranscriberError.audioConversionFailed("音频解码未正常完成。")
        @unknown default:
            throw SherpaOnnxTranscriberError.audioConversionFailed("音频解码返回未知状态。")
        }
    }

    private func samples(from sampleBuffer: CMSampleBuffer) throws -> [Float] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return []
        }
        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        guard byteCount > 0 else {
            return []
        }
        guard byteCount.isMultiple(of: MemoryLayout<Float>.size) else {
            throw SherpaOnnxTranscriberError.audioConversionFailed("音频 PCM 数据长度异常。")
        }

        let sampleCount = byteCount / MemoryLayout<Float>.size
        var samples = Array(repeating: Float(0), count: sampleCount)
        let status = samples.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else {
                return -1
            }
            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: byteCount,
                destination: UnsafeMutableRawPointer(baseAddress)
            )
        }
        guard status == noErr else {
            throw SherpaOnnxTranscriberError.audioConversionFailed("无法复制 PCM 音频数据（\(status)）。")
        }
        return samples
    }

    private func drainVad(engine: SherpaOnnxEngine, into segments: inout [SubtitleSegment]) {
        while !engine.vad.isEmpty() {
            let speech = engine.vad.front()
            engine.vad.pop()
            let result = engine.recognizer.decode(samples: speech.samples, sampleRate: Self.sampleRate)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                continue
            }
            let start = TimeInterval(speech.start) / TimeInterval(Self.sampleRate)
            let duration = TimeInterval(speech.samples.count) / TimeInterval(Self.sampleRate)
            segments.append(
                SubtitleSegment(
                    startTime: start,
                    endTime: start + duration,
                    text: text
                )
            )
        }
    }

    private func decodeFixedWindows(
        samples: [Float],
        recognizer: SherpaOnnxOfflineRecognizer,
        windowDuration: TranscriptionWindowDuration,
        progress: @escaping @Sendable (SubtitleRecognitionProgress) -> Void = { _ in }
    ) -> [SubtitleSegment] {
        let windows = TranscriptionWindowPlanner.fixedWindows(
            sampleCount: samples.count,
            sampleRate: Self.sampleRate,
            windowDuration: windowDuration.duration
        )
        DebugLog.shared.log("sherpa-onnx 固定窗口识别：\(windows.count) 个窗口，窗口长度=\(windowDuration.rawValue) 秒")
        progress(.recognizing(completedSegments: 0, totalSegments: windows.count))
        var segments: [SubtitleSegment] = []
        var timingRecords: [TranscriptionWindowTiming] = []
        for (index, plannedWindow) in windows.enumerated() {
            let window = Array(samples[plannedWindow.startSample..<plannedWindow.endSample])
            let windowStartedAt = Date()
            let producedSubtitle: Bool
            if let segment = decodeWindow(samples: window, window: plannedWindow, recognizer: recognizer) {
                segments.append(segment)
                producedSubtitle = true
            } else {
                producedSubtitle = false
            }
            let elapsed = Date().timeIntervalSince(windowStartedAt)
            timingRecords.append(TranscriptionWindowTiming(elapsed: elapsed, producedSubtitle: producedSubtitle))
            logWindowTiming(
                index: index + 1,
                total: windows.count,
                window: plannedWindow,
                elapsed: elapsed,
                producedSubtitle: producedSubtitle
            )
            progress(.recognizing(completedSegments: index + 1, totalSegments: windows.count))
        }
        logWindowTimingSummary(timingRecords)
        return segments
    }

    private func transcribeLongAudio(
        asset: AVURLAsset,
        recognizer: SherpaOnnxOfflineRecognizer,
        startedAt: Date,
        expectedDuration: TimeInterval,
        windowDuration: TranscriptionWindowDuration,
        progress: @escaping @Sendable (SubtitleRecognitionProgress) -> Void
    ) async throws -> [SubtitleSegment] {
        let decodeStartedAt = Date()
        var buffer = TranscriptionWindowBuffer(
            sampleRate: Self.sampleRate,
            windowDuration: windowDuration.duration
        )
        var segments: [SubtitleSegment] = []
        var windowCount = 0
        var timingRecords: [TranscriptionWindowTiming] = []
        let expectedWindowCount = max(1, Int(ceil(expectedDuration / windowDuration.duration)))
        progress(.recognizing(completedSegments: 0, totalSegments: expectedWindowCount))

        let decodedSampleCount = try await decodeAudioFile(asset) { chunk in
            for windowSamples in buffer.append(chunk) {
                windowCount += 1
                let windowStartedAt = Date()
                let producedSubtitle: Bool
                if let segment = decodeWindow(
                    samples: windowSamples.samples,
                    window: windowSamples.window,
                    recognizer: recognizer
                ) {
                    segments.append(segment)
                    producedSubtitle = true
                } else {
                    producedSubtitle = false
                }
                let elapsed = Date().timeIntervalSince(windowStartedAt)
                timingRecords.append(TranscriptionWindowTiming(elapsed: elapsed, producedSubtitle: producedSubtitle))
                logWindowTiming(
                    index: windowCount,
                    total: expectedWindowCount,
                    window: windowSamples.window,
                    elapsed: elapsed,
                    producedSubtitle: producedSubtitle
                )
                progress(.recognizing(completedSegments: windowCount, totalSegments: expectedWindowCount))
            }
        }

        if let finalWindow = buffer.finish() {
            windowCount += 1
            let windowStartedAt = Date()
            let producedSubtitle: Bool
            if let segment = decodeWindow(
                samples: finalWindow.samples,
                window: finalWindow.window,
                recognizer: recognizer
            ) {
                segments.append(segment)
                producedSubtitle = true
            } else {
                producedSubtitle = false
            }
            let elapsed = Date().timeIntervalSince(windowStartedAt)
            timingRecords.append(TranscriptionWindowTiming(elapsed: elapsed, producedSubtitle: producedSubtitle))
            logWindowTiming(
                index: windowCount,
                total: expectedWindowCount,
                window: finalWindow.window,
                elapsed: elapsed,
                producedSubtitle: producedSubtitle
            )
            progress(.recognizing(completedSegments: windowCount, totalSegments: expectedWindowCount))
        }
        logWindowTimingSummary(timingRecords)

        let decodedDuration = TimeInterval(decodedSampleCount) / TimeInterval(Self.sampleRate)
        DebugLog.shared.log(
            String(
                format: "sherpa-onnx 流式长音频识别完成：预估 %.1f 秒，解码 %.1f 秒，窗口长度 %d 秒，%d 个窗口，%d 段字幕，解码+识别用时 %.2f 秒，总用时 %.2f 秒",
                expectedDuration,
                decodedDuration,
                windowDuration.rawValue,
                windowCount,
                segments.count,
                Date().timeIntervalSince(decodeStartedAt),
                Date().timeIntervalSince(startedAt)
            )
        )

        guard decodedSampleCount > 0 else {
            throw SherpaOnnxTranscriberError.noDecodableAudio
        }
        if segments.isEmpty {
            throw SherpaOnnxTranscriberError.noSpeechDetected
        }
        progress(.finalizing)
        return segments
    }

    private func decodeWindow(
        samples: [Float],
        window: TranscriptionWindow,
        recognizer: SherpaOnnxOfflineRecognizer
    ) -> SubtitleSegment? {
        let result = recognizer.decode(samples: samples, sampleRate: Self.sampleRate)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }
        return SubtitleSegment(
            startTime: window.startTime,
            endTime: window.endTime,
            text: text
        )
    }

    private func logWindowTiming(
        index: Int,
        total: Int,
        window: TranscriptionWindow,
        elapsed: TimeInterval,
        producedSubtitle: Bool
    ) {
        DebugLog.shared.log(
            String(
                format: "sherpa-onnx 窗口 %d/%d：%.1f-%.1f 秒，用时 %.2f 秒，字幕=%@",
                index,
                total,
                window.startTime,
                window.endTime,
                elapsed,
                producedSubtitle ? "有" : "无"
            )
        )
    }

    private func logWindowTimingSummary(_ timingRecords: [TranscriptionWindowTiming]) {
        guard !timingRecords.isEmpty else {
            return
        }
        let totalElapsed = timingRecords.reduce(0) { $0 + $1.elapsed }
        let averageElapsed = totalElapsed / Double(timingRecords.count)
        let maxElapsed = timingRecords.map(\.elapsed).max() ?? 0
        let subtitleCount = timingRecords.filter(\.producedSubtitle).count
        DebugLog.shared.log(
            String(
                format: "sherpa-onnx 窗口耗时汇总：%d 个窗口，平均 %.2f 秒，最慢 %.2f 秒，有字幕 %d 个，空窗口 %d 个",
                timingRecords.count,
                averageElapsed,
                maxElapsed,
                subtitleCount,
                timingRecords.count - subtitleCount
            )
        )
    }
}

private struct SherpaOnnxEngine {
    let recognizer: SherpaOnnxOfflineRecognizer
    let vad: SherpaOnnxVoiceActivityDetectorWrapper
    let vadModelConfig: SherpaOnnxVadModelConfig
}

private struct TranscriptionWindowTiming {
    let elapsed: TimeInterval
    let producedSubtitle: Bool
}

enum SherpaOnnxTranscriberError: Error, LocalizedError {
    case missingModelResource(String)
    case audioFileUnreadable(String)
    case noAudioTrack
    case noDecodableAudio
    case invalidVadWindow
    case audioConversionFailed(String)
    case noSpeechDetected

    var errorDescription: String? {
        switch self {
        case .missingModelResource(let path):
            return "本地中文识别模型缺失：\(path)。请安装包含 sherpa-onnx 中文模型的最新版本。"
        case .audioFileUnreadable(let message):
            return "无法读取这个音频文件：\(message)。请确认文件仍在手机本地、未被移动，并重新选择。"
        case .noAudioTrack:
            return "这个文件没有可识别的音频轨道。请确认它是有效的 MP3、M4A、WAV 或录音文件。"
        case .noDecodableAudio:
            return "这个文件没有可识别的音频数据。请确认它是有效的 MP3、M4A、WAV 或录音文件。"
        case .invalidVadWindow:
            return "本地语音活动检测模型配置异常。请安装最新版本后重试。"
        case .audioConversionFailed(let message):
            return "音频解码失败：\(message)"
        case .noSpeechDetected:
            return "没有从这段音频中识别到中文语音。请确认录音中有人声，且音量清晰。"
        }
    }
}
