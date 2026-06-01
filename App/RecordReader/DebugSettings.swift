import Foundation
import RecordReaderCore

enum DebugSettings {
    static let recognitionProviderKey = "debug.recognitionProvider"
    static let experimentalTranscriptionEngineKey = "debug.experimentalTranscriptionEngine"
    static let whisperKitModelVariantKey = "debug.whisperKitModelVariant"
    static let sherpaThreadCountKey = "debug.sherpaThreadCount"
    static let transcriptionWindowDurationKey = "debug.transcriptionWindowDuration"
    static let transcriptionWorkerCountKey = "debug.transcriptionWorkerCount"

    static var recognitionProvider: RecognitionProvider {
        get {
            guard let value = UserDefaults.standard.string(forKey: recognitionProviderKey) else {
                return .defaultValue
            }
            let provider = RecognitionProvider(rawValueOrDefault: value)
            guard provider.isSupportedByBundledModel else {
                return .defaultValue
            }
            return provider
        }
        set {
            let provider = newValue.isSupportedByBundledModel ? newValue : .defaultValue
            UserDefaults.standard.set(provider.rawValue, forKey: recognitionProviderKey)
        }
    }

    static var experimentalTranscriptionEngine: ExperimentalTranscriptionEngine {
        get {
            guard let value = UserDefaults.standard.string(forKey: experimentalTranscriptionEngineKey) else {
                return .defaultValue
            }
            return ExperimentalTranscriptionEngine(rawValueOrDefault: value)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: experimentalTranscriptionEngineKey)
        }
    }

    static var whisperKitModelVariant: WhisperKitModelVariant {
        get {
            guard let value = UserDefaults.standard.string(forKey: whisperKitModelVariantKey) else {
                return .defaultValue
            }
            return WhisperKitModelVariant(rawValueOrDefault: value)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: whisperKitModelVariantKey)
        }
    }

    static var sherpaThreadCount: SherpaThreadCount {
        get {
            guard UserDefaults.standard.object(forKey: sherpaThreadCountKey) != nil else {
                return .defaultValue
            }
            return SherpaThreadCount(
                rawValueOrDefault: UserDefaults.standard.integer(forKey: sherpaThreadCountKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sherpaThreadCountKey)
        }
    }

    static var transcriptionWindowDuration: TranscriptionWindowDuration {
        get {
            guard UserDefaults.standard.object(forKey: transcriptionWindowDurationKey) != nil else {
                return .defaultValue
            }
            return TranscriptionWindowDuration(
                rawValueOrDefault: UserDefaults.standard.integer(forKey: transcriptionWindowDurationKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: transcriptionWindowDurationKey)
        }
    }

    static var transcriptionWorkerCount: TranscriptionWorkerCount {
        get {
            guard UserDefaults.standard.object(forKey: transcriptionWorkerCountKey) != nil else {
                return .defaultValue
            }
            return TranscriptionWorkerCount(
                rawValueOrDefault: UserDefaults.standard.integer(forKey: transcriptionWorkerCountKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: transcriptionWorkerCountKey)
        }
    }
}
