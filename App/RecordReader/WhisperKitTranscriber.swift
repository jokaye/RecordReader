import Foundation
import RecordReaderCore
import WhisperKit

/// On-device Whisper transcription via WhisperKit (Core ML).
///
/// Reads the selected audio file directly and produces timed subtitle
/// segments. The model is downloaded from Hugging Face on first use and
/// cached on device; everything after that runs fully offline. No microphone
/// or speaker capture is involved.
actor WhisperKitTranscriber {
    private var pipe: WhisperKit?
    private let modelName: String

    /// `large-v3-v20240930_626MB` is Argmax's recommended model for maximum
    /// multilingual (incl. Chinese) accuracy.
    init(modelName: String = "large-v3-v20240930_626MB") {
        self.modelName = modelName
    }

    func transcribe(url: URL) async throws -> [SubtitleSegment] {
        let didStartScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let pipe = try await loadPipe()

        let options = DecodingOptions(
            task: .transcribe,
            language: "zh",
            wordTimestamps: true,
            chunkingStrategy: .vad
        )

        let results = try await pipe.transcribe(audioPath: url.path, decodeOptions: options)

        return results
            .flatMap { $0.segments }
            .map { segment in
                SubtitleSegment(
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end),
                    text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.text.isEmpty }
    }

    private func loadPipe() async throws -> WhisperKit {
        if let pipe {
            return pipe
        }
        let created = try await WhisperKit(WhisperKitConfig(model: modelName))
        pipe = created
        return created
    }
}
