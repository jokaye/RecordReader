import Foundation
import Combine
import RecordReaderCore

enum RecordingFilter: Hashable {
    case all
    case favorites
    case category(String)
}

@MainActor
final class AudioLibraryViewModel: ObservableObject {
    @Published private(set) var recordings: [Recording] = []
    @Published private(set) var selectedRecording: Recording?
    @Published private(set) var selectedFolder: URL?
    @Published private(set) var filter: RecordingFilter = .all
    @Published private(set) var errorMessage: String?

    private let scanner: RecordingLibraryScanner
    private let store: RecordingMetadataStore
    private let transcriber: SpeechTranscriber
    private var metadata: RecordingLibraryMetadata
    private var selectedSources: [URL] = []
    private var activeSecurityScopedURLs: [URL] = []

    init(
        scanner: RecordingLibraryScanner = RecordingLibraryScanner(),
        store: RecordingMetadataStore = RecordingMetadataStore(fileURL: AppPaths.metadataURL),
        transcriber: SpeechTranscriber = SpeechTranscriber()
    ) {
        self.scanner = scanner
        self.store = store
        self.transcriber = transcriber
        do {
            self.metadata = try store.load()
        } catch {
            self.metadata = .empty
            self.errorMessage = error.localizedDescription
        }
    }

    var filteredRecordings: [Recording] {
        switch filter {
        case .all:
            return recordings
        case .favorites:
            return recordings.filter(\.isFavorite)
        case .category(let category):
            return recordings.filter { $0.category == category }
        }
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
            guard !urls.isEmpty else {
                throw RecordingSelectionError.noFolderSelected
            }
            open(urls: urls, persistFolderBookmarkIfPossible: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard !selectedSources.isEmpty else {
            errorMessage = "刷新前请先选择录音文件夹或音频文件。"
            return
        }
        loadRecordings(from: selectedSources)
    }

    func select(_ recording: Recording) {
        selectedRecording = recording
    }

    func setFilter(_ filter: RecordingFilter) {
        self.filter = filter
        selectedRecording = filteredRecordings.first
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

    func recognizeSubtitleForSelectedRecording() {
        guard let selectedRecording else {
            errorMessage = "请先选择一段录音，再识别字幕。"
            return
        }
        setSubtitle(
            SubtitleDocument(status: .recognizing, segments: [], errorMessage: nil),
            for: selectedRecording.id
        )
        transcriber.transcribe(url: selectedRecording.url) { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }
                switch result {
                case .success(let subtitle):
                    self.setSubtitle(subtitle, for: selectedRecording.id)
                case .failure(let error):
                    self.setSubtitle(
                        SubtitleDocument(status: .failed, segments: [], errorMessage: error.localizedDescription),
                        for: selectedRecording.id
                    )
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func open(folder: URL, persistBookmark: Bool) {
        open(urls: [folder], persistFolderBookmarkIfPossible: persistBookmark)
    }

    private func open(urls: [URL], persistFolderBookmarkIfPossible: Bool) {
        releaseSecurityScopedURLs()
        activeSecurityScopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        selectedSources = urls
        selectedFolder = singleSelectedFolder(from: urls)

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

    private func loadRecordings(from urls: [URL]) {
        do {
            recordings = try scanner.scan(urls: urls, metadata: metadata)
            selectedRecording = preferredSelectionAfterLoad
            errorMessage = nil
        } catch {
            recordings = []
            selectedRecording = nil
            errorMessage = error.localizedDescription
        }
    }

    private var preferredSelectionAfterLoad: Recording? {
        switch filter {
        case .all:
            return recordings.first
        case .favorites, .category(_):
            return filteredRecordings.first
        }
    }

    private func updateMetadata(_ record: RecordingMetadata, for id: String) {
        metadata.records[id] = record
        do {
            try persistMetadata()
            if !selectedSources.isEmpty {
                loadRecordings(from: selectedSources)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setSubtitle(_ subtitle: SubtitleDocument, for id: String) {
        var record = metadata.records[id] ?? RecordingMetadata(
            isFavorite: selectedRecording?.isFavorite ?? false,
            category: selectedRecording?.category,
            subtitle: nil
        )
        record.subtitle = subtitle
        updateMetadata(record, for: id)
    }

    private func persistMetadata() throws {
        try store.save(metadata)
    }

    private func releaseSecurityScopedURLs() {
        activeSecurityScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        activeSecurityScopedURLs = []
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
