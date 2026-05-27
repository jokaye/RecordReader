import Foundation
import RecordReaderCore
import Speech

final class SpeechTranscriber {
    private var recognitionTask: SFSpeechRecognitionTask?

    func transcribe(
        url: URL,
        completion: @escaping (Result<SubtitleDocument, Error>) -> Void
    ) {
        recognitionTask?.cancel()

        SFSpeechRecognizer.requestAuthorization { [weak self] authorizationStatus in
            guard authorizationStatus == .authorized else {
                completion(.failure(SpeechTranscriberError.permissionDenied))
                return
            }
            self?.startRecognition(url: url, completion: completion)
        }
    }

    private func startRecognition(
        url: URL,
        completion: @escaping (Result<SubtitleDocument, Error>) -> Void
    ) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN")) else {
            completion(.failure(SpeechTranscriberError.recognizerUnavailable))
            return
        }
        guard recognizer.isAvailable else {
            completion(.failure(SpeechTranscriberError.recognizerUnavailable))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let result, result.isFinal else {
                return
            }
            let segments = result.bestTranscription.segments.map { segment in
                SubtitleSegment(
                    startTime: segment.timestamp,
                    endTime: segment.timestamp + segment.duration,
                    text: segment.substring
                )
            }
            completion(.success(SubtitleDocument(status: .ready, segments: segments, errorMessage: nil)))
        }
    }
}

enum SpeechTranscriberError: Error, LocalizedError {
    case permissionDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要允许语音识别权限，才能生成中文字幕。"
        case .recognizerUnavailable:
            return "当前手机暂时不可用中文语音识别。"
        }
    }
}
