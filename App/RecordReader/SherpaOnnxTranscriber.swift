import AVFoundation
import Foundation
import RecordReaderCore

actor SherpaOnnxTranscriber {
    private static let sampleRate = 16_000
    private static let featureDim = 80
    private static let readFrameCapacity: AVAudioFrameCount = 16_384

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

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw SherpaOnnxTranscriberError.audioFileUnreadable
        }

        let engine = try loadEngine()
        let samples = try decodeAudioFile(url)
        guard !samples.isEmpty else {
            throw SherpaOnnxTranscriberError.noDecodableAudio
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
            if fallback.isEmpty {
                throw SherpaOnnxTranscriberError.noSpeechDetected
            }
            return fallback
        }

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

    private func decodeAudioFile(_ url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(Self.sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            throw SherpaOnnxTranscriberError.audioConversionFailed("无法创建 16kHz 单声道 PCM 格式。")
        }
        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat) else {
            throw SherpaOnnxTranscriberError.audioConversionFailed("无法初始化音频格式转换器。")
        }

        var output: [Float] = []
        let inputCapacity = Self.readFrameCapacity
        let outputCapacity = AVAudioFrameCount(
            ceil(Double(inputCapacity) * targetFormat.sampleRate / audioFile.processingFormat.sampleRate)
        ) + 512

        while true {
            guard let inputBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: inputCapacity
            ) else {
                throw SherpaOnnxTranscriberError.audioConversionFailed("无法分配输入缓冲区。")
            }
            try audioFile.read(into: inputBuffer, frameCount: inputCapacity)
            if inputBuffer.frameLength == 0 {
                break
            }

            var inputConsumed = false
            while true {
                guard let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: outputCapacity
                ) else {
                    throw SherpaOnnxTranscriberError.audioConversionFailed("无法分配输出缓冲区。")
                }

                var conversionError: NSError?
                let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                    if inputConsumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return inputBuffer
                }

                if let conversionError {
                    throw SherpaOnnxTranscriberError.audioConversionFailed(conversionError.localizedDescription)
                }
                appendSamples(from: outputBuffer, to: &output)

                switch status {
                case .haveData:
                    continue
                case .inputRanDry, .endOfStream:
                    break
                case .error:
                    throw SherpaOnnxTranscriberError.audioConversionFailed("音频转换失败。")
                @unknown default:
                    throw SherpaOnnxTranscriberError.audioConversionFailed("音频转换返回未知状态。")
                }
                break
            }
        }

        return output
    }

    private func appendSamples(from buffer: AVAudioPCMBuffer, to output: inout [Float]) {
        guard buffer.frameLength > 0, let channelData = buffer.floatChannelData?[0] else {
            return
        }
        let count = Int(buffer.frameLength)
        output.append(contentsOf: UnsafeBufferPointer(start: channelData, count: count))
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
        let windowSize = Self.sampleRate * 30
        var segments: [SubtitleSegment] = []
        var cursor = 0
        while cursor < samples.count {
            let end = min(cursor + windowSize, samples.count)
            let window = Array(samples[cursor..<end])
            let result = recognizer.decode(samples: window, sampleRate: Self.sampleRate)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(
                    SubtitleSegment(
                        startTime: TimeInterval(cursor) / TimeInterval(Self.sampleRate),
                        endTime: TimeInterval(end) / TimeInterval(Self.sampleRate),
                        text: text
                    )
                )
            }
            cursor = end
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
    case audioFileUnreadable
    case noDecodableAudio
    case invalidVadWindow
    case audioConversionFailed(String)
    case noSpeechDetected

    var errorDescription: String? {
        switch self {
        case .missingModelResource(let path):
            return "本地中文识别模型缺失：\(path)。请安装包含 sherpa-onnx 中文模型的最新版本。"
        case .audioFileUnreadable:
            return "无法读取这个音频文件。请确认文件仍在手机本地、未被移动，并重新选择。"
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
