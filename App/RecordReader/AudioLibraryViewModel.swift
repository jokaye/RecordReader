import Foundation
import Combine
import RecordReaderCore

@MainActor
final class AudioLibraryViewModel: ObservableObject {
    @Published private(set) var recordings: [Recording] = []
    @Published private(set) var selectedRecording: Recording?
    @Published private(set) var selectedFolder: URL?
    @Published private(set) var filter: RecordingFilter = .all
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var subtitleRecognitionProgress: SubtitleRecognitionProgress?
    @Published var searchText = ""
    @Published var sort: RecordingSort = .nameAscending

    private let scanner: RecordingLibraryScanner
    private let store: RecordingMetadataStore
    private let transcriber: SpeechTranscriber
    private let sherpaTranscriber: SherpaOnnxTranscriber
    private var metadata: RecordingLibraryMetadata
    private var selectedSources: [URL] = []
    private var activeSecurityScopedURLs: [URL] = []
    private var activeSubtitleRecognitionID: Recording.ID?
    private var unavailableCoreMLReason: String?

    init(
        scanner: RecordingLibraryScanner = RecordingLibraryScanner(),
        store: RecordingMetadataStore = RecordingMetadataStore(fileURL: AppPaths.metadataURL),
        transcriber: SpeechTranscriber = SpeechTranscriber(),
        sherpaTranscriber: SherpaOnnxTranscriber = SherpaOnnxTranscriber()
    ) {
        self.scanner = scanner
        self.store = store
        self.transcriber = transcriber
        self.sherpaTranscriber = sherpaTranscriber
        do {
            self.metadata = try store.load()
        } catch {
            self.metadata = .empty
            self.errorMessage = error.localizedDescription
        }
    }

    var visibleRecordings: [Recording] {
        RecordingListQuery.visibleRecordings(
            recordings,
            filter: filter,
            searchText: searchText,
            sort: sort
        )
    }

    var categories: [String] {
        Array(Set(recordings.compactMap(\.category))).sorted()
    }

    var currentFilterTitle: String {
        switch filter {
        case .all:
            return "录音"
        case .favorites:
            return "收藏"
        case .category(let category):
            return category
        }
    }

    func restoreLastFolder() {
        guard selectedFolder == nil, let bookmark = metadata.selectedFolderBookmark else {
            return
        }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                metadata.selectedFolderBookmark = nil
                try persistMetadata()
                return
            }
            open(folder: url, persistBookmark: false)
        } catch {
            errorMessage = "无法重新打开上次的录音文件夹，请重新选择。"
        }
    }

    func selectImportedItems(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            DebugLog.shared.log("selectImportedItems：收到 \(urls.count) 个 URL")
            statusMessage = "已选择 \(urls.count) 项"
            guard !urls.isEmpty else {
                throw RecordingSelectionError.noFolderSelected
            }
            open(urls: urls, persistFolderBookmarkIfPossible: true)
        } catch {
            DebugLog.shared.log("selectImportedItems 失败：\(error.localizedDescription)")
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard !selectedSources.isEmpty else {
            errorMessage = "刷新前请先选择录音文件夹或音频文件。"
            return
        }
        loadRecordings(from: selectedSources, preserveSelection: true)
    }

    func select(_ recording: Recording) {
        selectedRecording = recording
        if activeSubtitleRecognitionID != recording.id {
            subtitleRecognitionProgress = nil
        }
    }

    func setFilter(_ filter: RecordingFilter) {
        self.filter = filter
        selectedRecording = visibleRecordings.first
    }

    func setSort(_ sort: RecordingSort) {
        self.sort = sort
        preserveSelectionOrSelectFirstVisible()
    }

    func selectPrevious() -> Recording? {
        guard let selectedRecording else {
            let first = visibleRecordings.first
            self.selectedRecording = first
            return first
        }
        guard let previous = RecordingListQuery.previousRecording(before: selectedRecording.id, in: visibleRecordings) else {
            return nil
        }
        self.selectedRecording = previous
        return previous
    }

    func selectNext() -> Recording? {
        guard let selectedRecording else {
            let first = visibleRecordings.first
            self.selectedRecording = first
            return first
        }
        guard let next = RecordingListQuery.nextRecording(after: selectedRecording.id, in: visibleRecordings) else {
            return nil
        }
        self.selectedRecording = next
        return next
    }

    var hasPreviousRecording: Bool {
        guard let selectedRecording else {
            return false
        }
        return RecordingListQuery.previousRecording(before: selectedRecording.id, in: visibleRecordings) != nil
    }

    var hasNextRecording: Bool {
        guard let selectedRecording else {
            return false
        }
        return RecordingListQuery.nextRecording(after: selectedRecording.id, in: visibleRecordings) != nil
    }

    func toggleFavorite() {
        guard let selectedRecording else {
            errorMessage = "请先选择一段录音，再修改收藏。"
            return
        }
        var record = metadata.records[selectedRecording.id] ?? RecordingMetadata(
            isFavorite: false,
            category: selectedRecording.category,
            subtitle: selectedRecording.subtitle
        )
        record.isFavorite.toggle()
        updateMetadata(record, for: selectedRecording.id)
    }

    func setFavorite(_ isFavorite: Bool, ids: Set<Recording.ID>) {
        updateRecords(ids: ids) { recording, metadata in
            metadata.isFavorite = isFavorite
            metadata.category = metadata.category ?? recording.category
            metadata.subtitle = metadata.subtitle ?? recording.subtitle
        }
    }

    func setCategory(_ category: String?) {
        guard let selectedRecording else {
            errorMessage = "请先选择一段录音，再设置分类。"
            return
        }
        let normalizedCategory = category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        var record = metadata.records[selectedRecording.id] ?? RecordingMetadata(
            isFavorite: selectedRecording.isFavorite,
            category: nil,
            subtitle: selectedRecording.subtitle
        )
        record.category = normalizedCategory
        updateMetadata(record, for: selectedRecording.id)
    }

    func setCategory(_ category: String?, ids: Set<Recording.ID>) {
        let normalizedCategory = category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        updateRecords(ids: ids) { recording, metadata in
            metadata.isFavorite = metadata.isFavorite || recording.isFavorite
            metadata.category = normalizedCategory
            metadata.subtitle = metadata.subtitle ?? recording.subtitle
        }
    }

    func deleteRecordingRecords(ids: Set<Recording.ID>) {
        guard !ids.isEmpty else {
            errorMessage = "请先选择要删除记录的录音。"
            return
        }
        let existingIDs = Set(recordings.map(\.id))
        let removableIDs = ids.intersection(existingIDs)
        guard !removableIDs.isEmpty else {
            errorMessage = "没有找到可删除的播放记录。"
            return
        }

        let selectedID = selectedRecording?.id
        for id in removableIDs {
            metadata.hiddenRecordingIDs.insert(id)
            metadata.records[id] = nil
        }

        do {
            try persistMetadata()
            recordings.removeAll { removableIDs.contains($0.id) }
            preserveSelectionAfterDeleting(selectedID: selectedID, deletedIDs: removableIDs)
            statusMessage = "已删除 \(removableIDs.count) 条播放记录，原始文件未删除"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recognizeSubtitleForSelectedRecording() {
        guard let selectedRecording else {
            errorMessage = "请先选择一段录音，再识别字幕。"
            return
        }
        let id = selectedRecording.id
        let url = selectedRecording.url
        let recognitionProvider = DebugSettings.recognitionProvider
        let threadCount = DebugSettings.sherpaThreadCount
        let windowDuration = DebugSettings.transcriptionWindowDuration
        let workerCount = DebugSettings.transcriptionWorkerCount
        let performanceTier = DeviceProfile.transcriptionPerformanceTier
        activeSubtitleRecognitionID = id
        subtitleRecognitionProgress = .readingAudio
        setSubtitle(
            SubtitleDocument(status: .recognizing, segments: [], errorMessage: nil),
            for: id
        )
        statusMessage = "正在用本地中文模型识别字幕…"
        DebugLog.shared.log("开始 sherpa-onnx Paraformer 识别：\(url.lastPathComponent)，后端=\(recognitionProvider.logLabel)，线程数=\(threadCount.label)，窗口=\(windowDuration.rawValue) 秒，并行=\(workerCount.label)，设备=\(DeviceProfile.identifier)")

        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let result = try await self.transcribeWithSherpaFallback(
                    url: url,
                    id: id,
                    recognitionProvider: recognitionProvider,
                    threadCount: threadCount,
                    windowDuration: windowDuration,
                    workerCount: workerCount,
                    performanceTier: performanceTier
                )
                let segments = result.segments
                DebugLog.shared.log("sherpa-onnx 完成：\(segments.count) 段字幕")
                if segments.isEmpty {
                    self.setSubtitle(
                        SubtitleDocument(status: .failed, segments: [], errorMessage: "没有从这段音频中识别到语音。"),
                        for: id
                    )
                    self.statusMessage = "未识别到语音"
                    self.clearSubtitleRecognitionProgress(for: id)
                } else {
                    self.setSubtitle(
                        SubtitleDocument(status: .ready, segments: segments, errorMessage: nil),
                        for: id
                    )
                    self.statusMessage = "字幕已生成（本地中文模型，\(result.provider.logLabel)）"
                    self.clearSubtitleRecognitionProgress(for: id)
                }
            } catch {
                DebugLog.shared.log("sherpa-onnx 失败：\(error.localizedDescription)，回退到 iOS Speech")
                self.statusMessage = "本地中文识别失败，正在改用 iOS 语音识别…"
                self.recognizeWithAppleSpeech(url: url, id: id, primaryError: error)
            }
        }
    }

    private func transcribeWithSherpaFallback(
        url: URL,
        id: Recording.ID,
        recognitionProvider: RecognitionProvider,
        threadCount: SherpaThreadCount,
        windowDuration: TranscriptionWindowDuration,
        workerCount: TranscriptionWorkerCount,
        performanceTier: TranscriptionPerformanceTier
    ) async throws -> (segments: [SubtitleSegment], provider: RecognitionProvider) {
        if recognitionProvider == .coreML, let unavailableCoreMLReason {
            DebugLog.shared.log("CoreML 本次会话已标记不可用：\(unavailableCoreMLReason)，直接使用 CPU")
            return try await transcribeWithSherpaCPU(
                url: url,
                id: id,
                threadCount: threadCount,
                windowDuration: windowDuration,
                workerCount: workerCount,
                performanceTier: performanceTier
            )
        }

        do {
            let segments = try await sherpaTranscriber.transcribe(
                url: url,
                threadCount: threadCount,
                windowDuration: windowDuration,
                recognitionProvider: recognitionProvider,
                workerCount: workerCount,
                performanceTier: performanceTier
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.setSubtitleRecognitionProgress(progress, for: id)
                }
            }
            if recognitionProvider.shouldRetryCPUWhenRecognitionIsEmpty, segments.isEmpty {
                rememberCPUFallbackIfNeeded(for: recognitionProvider, reason: "CoreML 未产出字幕")
                DebugLog.shared.log("CoreML 后端未产出字幕，正在回退 CPU 重新识别")
                return try await transcribeWithSherpaCPU(
                    url: url,
                    id: id,
                    threadCount: threadCount,
                    windowDuration: windowDuration,
                    workerCount: workerCount,
                    performanceTier: performanceTier
                )
            }
            return (segments, recognitionProvider)
        } catch {
            guard recognitionProvider.shouldRetryCPUOnProviderFailure else {
                throw error
            }
            let reason = coreMLFallbackReason(for: error)
            rememberCPUFallbackIfNeeded(for: recognitionProvider, reason: reason)
            DebugLog.shared.log("\(reason)，正在回退 CPU")
            return try await transcribeWithSherpaCPU(
                url: url,
                id: id,
                threadCount: threadCount,
                windowDuration: windowDuration,
                workerCount: workerCount,
                performanceTier: performanceTier
            )
        }
    }

    private func transcribeWithSherpaCPU(
        url: URL,
        id: Recording.ID,
        threadCount: SherpaThreadCount,
        windowDuration: TranscriptionWindowDuration,
        workerCount: TranscriptionWorkerCount,
        performanceTier: TranscriptionPerformanceTier
    ) async throws -> (segments: [SubtitleSegment], provider: RecognitionProvider) {
        let segments = try await sherpaTranscriber.transcribe(
            url: url,
            threadCount: threadCount,
            windowDuration: windowDuration,
            recognitionProvider: .cpu,
            workerCount: workerCount,
            performanceTier: performanceTier
        ) { [weak self] progress in
            Task { @MainActor in
                self?.setSubtitleRecognitionProgress(progress, for: id)
            }
        }
        return (segments, .cpu)
    }

    private func coreMLFallbackReason(for error: Error) -> String {
        if case SherpaOnnxTranscriberError.noSpeechDetected = error {
            return "CoreML 后端未产出字幕"
        }
        return "CoreML 后端失败：\(error.localizedDescription)"
    }

    private func rememberCPUFallbackIfNeeded(for provider: RecognitionProvider, reason: String) {
        guard provider.shouldRememberCPUFallbackAfterFailure else {
            return
        }
        unavailableCoreMLReason = reason
    }

    private func recognizeWithAppleSpeech(url: URL, id: Recording.ID, primaryError: Error? = nil) {
        setSubtitleRecognitionProgress(.fallback, for: id)
        transcriber.transcribe(url: url) { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }
                switch result {
                case .success(let subtitle):
                    self.setSubtitle(subtitle, for: id)
                    self.statusMessage = "字幕已生成（iOS Speech）"
                    self.clearSubtitleRecognitionProgress(for: id)
                case .failure(let error):
                    let message: String
                    if let primaryError {
                        message = "本地中文识别失败：\(primaryError.localizedDescription)\n\niOS 语音识别兜底也失败：\(error.localizedDescription)"
                    } else {
                        message = error.localizedDescription
                    }
                    self.setSubtitle(
                        SubtitleDocument(status: .failed, segments: [], errorMessage: message),
                        for: id
                    )
                    self.errorMessage = message
                    self.clearSubtitleRecognitionProgress(for: id)
                }
            }
        }
    }

    private func open(folder: URL, persistBookmark: Bool) {
        open(urls: [folder], persistFolderBookmarkIfPossible: persistBookmark)
    }

    private func open(urls: [URL], persistFolderBookmarkIfPossible: Bool) {
        releaseSecurityScopedURLs()
        activeSecurityScopedURLs = urls.filter { url in
            let granted = url.startAccessingSecurityScopedResource()
            DebugLog.shared.log("安全作用域 \(url.lastPathComponent)：\(granted ? "已获取" : "未获取（可能仍可访问）")")
            return granted
        }
        selectedSources = urls
        selectedFolder = singleSelectedFolder(from: urls)
        filter = .all
        searchText = ""

        if persistFolderBookmarkIfPossible, let selectedFolder {
            do {
                metadata.selectedFolderBookmark = try selectedFolder.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try persistMetadata()
            } catch {
                errorMessage = "无法保存录音文件夹权限：\(error.localizedDescription)"
            }
        } else if persistFolderBookmarkIfPossible {
            metadata.selectedFolderBookmark = nil
            do {
                try persistMetadata()
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        loadRecordings(from: urls)
    }

    private func loadRecordings(from urls: [URL], preserveSelection: Bool = false) {
        isLoading = true
        defer {
            isLoading = false
        }
        DebugLog.shared.log("开始扫描 \(urls.count) 个来源")
        for url in urls {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let ext = url.pathExtension.lowercased()
            let reachable = FileManager.default.isReadableFile(atPath: url.path)
            DebugLog.shared.log("  来源 \(url.lastPathComponent) 目录=\(isDir) 扩展名=\(ext.isEmpty ? "无" : ext) POSIX可读=\(reachable)")
        }
        do {
            recordings = try scanner.scan(urls: urls, metadata: metadata)
            DebugLog.shared.log("扫描完成：\(recordings.count) 段录音")
            if preserveSelection,
               let currentID = selectedRecording?.id,
               let stillPresent = recordings.first(where: { $0.id == currentID }) {
                selectedRecording = stillPresent
            } else {
                selectedRecording = preferredSelectionAfterLoad
            }
            statusMessage = "扫描到 \(recordings.count) 段录音"
            errorMessage = recordings.isEmpty ? "没有找到支持的录音文件。请选择包含 MP3、M4A、WAV 等音频的文件夹，或直接选择音频文件。" : nil
        } catch {
            DebugLog.shared.log("扫描失败：\(error.localizedDescription)")
            recordings = []
            selectedRecording = nil
            statusMessage = "扫描失败"
            errorMessage = error.localizedDescription
        }
    }

    private var preferredSelectionAfterLoad: Recording? {
        RecordingListQuery.initialSelectionAfterImport(recordings, sort: sort)
    }

    private enum MetadataRefreshStrategy {
        case reloadSources
        case updateInMemory
    }

    private func updateMetadata(
        _ record: RecordingMetadata,
        for id: String,
        refreshStrategy: MetadataRefreshStrategy = .reloadSources
    ) {
        metadata.records[id] = record
        do {
            try persistMetadata()
            if refreshStrategy == .reloadSources, !selectedSources.isEmpty {
                loadRecordings(from: selectedSources, preserveSelection: true)
            } else {
                applyMetadata(record, for: id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyMetadata(_ record: RecordingMetadata, for id: Recording.ID) {
        recordings = RecordingListQuery.recordingsByApplyingMetadata(record, to: id, in: recordings)
        if let selectedRecording, selectedRecording.id == id {
            self.selectedRecording = RecordingListQuery.recordingByApplyingMetadata(
                record,
                to: selectedRecording
            )
        }
    }

    private func updateRecords(
        ids: Set<Recording.ID>,
        mutate: (Recording, inout RecordingMetadata) -> Void
    ) {
        guard !ids.isEmpty else {
            errorMessage = "请先选择要批量管理的录音。"
            return
        }
        let recordingsByID = Dictionary(uniqueKeysWithValues: recordings.map { ($0.id, $0) })
        for id in ids {
            guard let recording = recordingsByID[id] else {
                continue
            }
            var record = metadata.records[id] ?? RecordingMetadata(
                isFavorite: recording.isFavorite,
                category: recording.category,
                subtitle: recording.subtitle
            )
            mutate(recording, &record)
            metadata.records[id] = record
        }
        do {
            try persistMetadata()
            if !selectedSources.isEmpty {
                loadRecordings(from: selectedSources, preserveSelection: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setSubtitle(_ subtitle: SubtitleDocument, for id: String) {
        let recording = recordings.first { $0.id == id }
        var record = metadata.records[id] ?? RecordingMetadata(
            isFavorite: recording?.isFavorite ?? false,
            category: recording?.category,
            subtitle: nil
        )
        record.subtitle = subtitle
        updateMetadata(record, for: id, refreshStrategy: .updateInMemory)
    }

    private func setSubtitleRecognitionProgress(_ progress: SubtitleRecognitionProgress, for id: Recording.ID) {
        guard activeSubtitleRecognitionID == id else {
            return
        }
        subtitleRecognitionProgress = progress
    }

    private func clearSubtitleRecognitionProgress(for id: Recording.ID) {
        guard activeSubtitleRecognitionID == id else {
            return
        }
        subtitleRecognitionProgress = nil
        activeSubtitleRecognitionID = nil
    }

    private func persistMetadata() throws {
        try store.save(metadata)
    }

    private func releaseSecurityScopedURLs() {
        activeSecurityScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        activeSecurityScopedURLs = []
    }

    private func preserveSelectionOrSelectFirstVisible() {
        guard let selectedRecording else {
            self.selectedRecording = visibleRecordings.first
            return
        }
        if !visibleRecordings.contains(where: { $0.id == selectedRecording.id }) {
            self.selectedRecording = visibleRecordings.first
        }
    }

    private func preserveSelectionAfterDeleting(selectedID: Recording.ID?, deletedIDs: Set<Recording.ID>) {
        guard let selectedID, deletedIDs.contains(selectedID) else {
            preserveSelectionOrSelectFirstVisible()
            return
        }
        selectedRecording = visibleRecordings.first
    }

    private func singleSelectedFolder(from urls: [URL]) -> URL? {
        guard urls.count == 1, let url = urls.first else {
            return nil
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return url
    }
}

private enum RecordingSelectionError: Error, LocalizedError {
    case noFolderSelected

    var errorDescription: String? {
        "没有选择录音文件夹或音频文件。"
    }
}

private enum AppPaths {
    static var metadataURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent("RecordReader", isDirectory: true)
            .appendingPathComponent("metadata.json")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
