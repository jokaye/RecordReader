import Foundation
import RecordReaderCore
import Speech

/// Transcribes the selected audio file itself.
///
/// This deliberately uses `SFSpeechURLRecognitionRequest(url:)`, so subtitle
/// generation reads the imported recording file directly. It does not record
/// microphone input and does not listen to device speaker or headphone output.
final class SpeechTranscriber {
    private let locale = Locale(identifier: "zh_CN")
    private let timeoutInterval: TimeInterval = 120
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutWorkItem: DispatchWorkItem?
    private var currentCompletionID = UUID()
    private var scopedURL: URL?
    private var hasSecurityScope = false

    func transcribe(
        url: URL,
        completion: @escaping (Result<SubtitleDocument, Error>) -> Void
    ) {
        recognitionTask?.cancel()
        timeoutWorkItem?.cancel()
        releaseSecurityScope()
        currentCompletionID = UUID()
        let completionID = currentCompletionID
        scopedURL = url
        hasSecurityScope = url.startAccessingSecurityScopedResource()

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            releaseSecurityScope()
            completion(.failure(SpeechTranscriberError.audioFileUnreadable))
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] authorizationStatus in
            switch authorizationStatus {
            case .authorized:
                self?.startRecognition(url: url, completionID: completionID, completion: completion)
            case .denied:
                self?.releaseSecurityScope()
                completion(.failure(SpeechTranscriberError.permissionDenied))
            case .restricted:
                self?.releaseSecurityScope()
                completion(.failure(SpeechTranscriberError.permissionRestricted))
            case .notDetermined:
                self?.releaseSecurityScope()
                completion(.failure(SpeechTranscriberError.permissionNotDetermined))
            @unknown default:
                self?.releaseSecurityScope()
                completion(.failure(SpeechTranscriberError.unknownAuthorizationStatus))
            }
        }
    }

    private func startRecognition(
        url: URL,
        completionID: UUID,
        completion: @escaping (Result<SubtitleDocument, Error>) -> Void
    ) {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            completion(.failure(SpeechTranscriberError.recognizerUnavailable))
            return
        }
        guard recognizer.isAvailable else {
            completion(.failure(SpeechTranscriberError.recognizerUnavailable))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        scheduleTimeout(completionID: completionID, completion: completion)

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self, self.currentCompletionID == completionID else {
                return
            }
            if let error {
                self.finish(completionID: completionID, result: .failure(SpeechTranscriberError.recognitionFailed(error.localizedDescription)), completion: completion)
                return
            }
            guard let result, result.isFinal else {
                return
            }
            let formattedString = result.bestTranscription.formattedString
            var segments = result.bestTranscription.segments.map { segment in
                SubtitleSegment(
                    startTime: segment.timestamp,
                    endTime: segment.timestamp + segment.duration,
                    text: segment.substring
                )
            }
            if segments.isEmpty, !formattedString.isEmpty {
                segments = [SubtitleSegment(startTime: 0, endTime: 0, text: formattedString)]
            }
            guard !segments.isEmpty else {
                self.finish(completionID: completionID, result: .failure(SpeechTranscriberError.noSpeechDetected), completion: completion)
                return
            }
            self.finish(
                completionID: completionID,
                result: .success(SubtitleDocument(status: .ready, segments: segments, errorMessage: nil)),
                completion: completion
            )
        }
    }

    private func scheduleTimeout(
        completionID: UUID,
        completion: @escaping (Result<SubtitleDocument, Error>) -> Void
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.finish(
                completionID: completionID,
                result: .failure(SpeechTranscriberError.timedOut),
                completion: completion
            )
        }
        timeoutWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutInterval, execute: workItem)
    }

    private func finish(
        completionID: UUID,
        result: Result<SubtitleDocument, Error>,
        completion: @escaping (Result<SubtitleDocument, Error>) -> Void
    ) {
        guard currentCompletionID == completionID else {
            return
        }
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        recognitionTask = nil
        currentCompletionID = UUID()
        releaseSecurityScope()
        completion(result)
    }

    private func releaseSecurityScope() {
        if hasSecurityScope {
            scopedURL?.stopAccessingSecurityScopedResource()
            hasSecurityScope = false
        }
        scopedURL = nil
    }
}

enum SpeechTranscriberError: Error, LocalizedError {
    case audioFileUnreadable
    case permissionDenied
    case permissionRestricted
    case permissionNotDetermined
    case unknownAuthorizationStatus
    case recognizerUnavailable
    case noSpeechDetected
    case timedOut
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioFileUnreadable:
            return "无法读取这个音频文件。请确认文件仍在手机本地、未被移动，并重新选择。"
        case .permissionDenied:
            return "语音识别权限已被拒绝。请到系统设置中允许 RecordReader 使用语音识别。"
        case .permissionRestricted:
            return "当前设备限制了语音识别权限，可能由家长控制、企业配置或系统策略导致。"
        case .permissionNotDetermined:
            return "还没有完成语音识别授权。请重新点击识别，并在系统弹窗中允许权限。"
        case .unknownAuthorizationStatus:
            return "系统返回了未知的语音识别权限状态，请重启 App 后再试。"
        case .recognizerUnavailable:
            return "当前手机暂时不可用中文语音识别。请确认联网状态、系统语音识别服务和中文识别支持。"
        case .noSpeechDetected:
            return "没有从这段音频中识别到中文语音。请确认录音中有人声，且音量清晰。"
        case .timedOut:
            return "中文语音识别超时。请先尝试较短的录音，或确认网络和系统语音识别服务可用。"
        case .recognitionFailed(let message):
            return "中文语音识别失败：\(message)"
        }
    }
}
