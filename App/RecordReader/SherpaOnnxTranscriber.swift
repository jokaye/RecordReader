import AVFoundation
import Foundation
import RecordReaderCore

actor SherpaOnnxTranscriber {
    private static let sampleRate = 16_000
    private static let featureDim = 80
    private static let fullCoverageThresholdDuration: TimeInterval = 120
    private static let fullCoverageWindowDuration: TimeInterval = 25

    private var recognizer: SherpaOnnxOfflineRecognizer?
    private var vad: SherpaOnnxVoiceActivityDetectorWrapper?
    private var vadModelConfig: SherpaOnnxVadModelConfig?

    func transcribe(url: URL) async throws -> [SubtitleSegment] {
        let didStartScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let engine = try loadEngine()
        let samples = try await decodeAudioFile(url)
        guard !samples.isEmpty else {
            throw SherpaOnnxTranscriberError.noDecodableAudio
        }
        let decodedDuration = TimeInterval(samples.count) / TimeInterval(Self.sampleRate)
        DebugLog.shared.log(
            String(format: "sherpa-onnx 解码完成：%.1f 秒，%d 个采样", decodedDuration, samples.count)
        )

        if TranscriptionWindowPlanner.shouldUseFullCoverage(
            sampleCount: samples.count,
            sampleRate: Self.sampleRate,
            thresholdDuration: Self.fullCoverageThresholdDuration
        ) {
            let segments = decodeFixedWindows(samples: samples, recognizer: engine.recognizer)
            DebugLog.shared.log("sherpa-onnx 长音频全覆盖识别完成：\(segments.count) 段字幕")
            if segments.isEmpty {
                throw SherpaOnnxTranscriberError.noSpeechDetected
            }
            return segments
        }

        let windowSize = Int(engine.vadModelConfig.silero_vad.window_size)
        guard windowSize > 0 else {
            throw SherpaOnnxTranscriberError.invalidVadWindow
        }

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
            let fallback = decodeFixedWindows(samples: samples, recognizer: engine.recognizer)
            DebugLog.shared.log("sherpa-onnx VAD 未产出字幕，固定窗口兜底完成：\(fallback.count) 段字幕")
            if fallback.isEmpty {
                throw SherpaOnnxTranscriberError.noSpeechDetected
            }
            return fallback
        }

        DebugLog.shared.log("sherpa-onnx VAD 识别完成：\(segments.count) 段字幕")
        return segments
    }

    private func loadEngine() throws -> SherpaOnnxEngine {
        if let recognizer, let vad, let vadModelConfig {
            return SherpaOnnxEngine(recognizer: recognizer, vad: vad, vadModelConfig: vadModelConfig)
        }

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
        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: tokens.path,
            paraformer: sherpaOnnxOfflineParaformerModelConfig(model: model.path),
            numThreads: 2,
            modelType: "paraformer"
        )
        var recognizerConfig = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig
        )
        let recognizer = SherpaOnnxOfflineRecognizer(config: &recognizerConfig)

        let sileroVadConfig = sherpaOnnxSileroVadModelConfig(model: vadModel.path)
        var vadModelConfig = sherpaOnnxVadModelConfig(sileroVad: sileroVadConfig)
        let vad = SherpaOnnxVoiceActivityDetectorWrapper(
            config: &vadModelConfig,
            buffer_size_in_seconds: 120
        )

        self.recognizer = recognizer
        self.vad = vad
        self.vadModelConfig = vadModelConfig
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

    private func decodeAudioFile(_ url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
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

        var samples: [Float] = []
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            try appendSamples(from: sampleBuffer, to: &samples)
        }

        switch reader.status {
        case .completed:
            return samples
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

    private func appendSamples(from sampleBuffer: CMSampleBuffer, to samples: inout [Float]) throws {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }
        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        guard byteCount > 0 else {
            return
        }
        guard byteCount.isMultiple(of: MemoryLayout<Float>.size) else {
            throw SherpaOnnxTranscriberError.audioConversionFailed("音频 PCM 数据长度异常。")
        }

        let sampleCount = byteCount / MemoryLayout<Float>.size
        let insertionIndex = samples.count
        samples.append(contentsOf: repeatElement(0, count: sampleCount))
        let status = samples.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else {
                return -1
            }
            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: byteCount,
                destination: UnsafeMutableRawPointer(baseAddress.advanced(by: insertionIndex))
            )
        }
        guard status == noErr else {
            throw SherpaOnnxTranscriberError.audioConversionFailed("无法复制 PCM 音频数据（\(status)）。")
        }
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

    private func decodeFixedWindows(samples: [Float], recognizer: SherpaOnnxOfflineRecognizer) -> [SubtitleSegment] {
        let windows = TranscriptionWindowPlanner.fixedWindows(
            sampleCount: samples.count,
            sampleRate: Self.sampleRate,
            windowDuration: Self.fullCoverageWindowDuration
        )
        DebugLog.shared.log("sherpa-onnx 固定窗口识别：\(windows.count) 个窗口")
        var segments: [SubtitleSegment] = []
        for plannedWindow in windows {
            let window = Array(samples[plannedWindow.startSample..<plannedWindow.endSample])
            let result = recognizer.decode(samples: window, sampleRate: Self.sampleRate)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(
                    SubtitleSegment(
                        startTime: plannedWindow.startTime,
                        endTime: plannedWindow.endTime,
                        text: text
                    )
                )
            }
        }
        return segments
    }
}

private struct SherpaOnnxEngine {
    let recognizer: SherpaOnnxOfflineRecognizer
    let vad: SherpaOnnxVoiceActivityDetectorWrapper
    let vadModelConfig: SherpaOnnxVadModelConfig
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
