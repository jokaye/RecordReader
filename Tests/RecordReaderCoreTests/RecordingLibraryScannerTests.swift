import XCTest
@testable import RecordReaderCore

final class RecordingLibraryScannerTests: XCTestCase {
    func testScannerReturnsOnlySupportedAudioFilesSortedByName() throws {
        let folder = try makeTemporaryFolder()
        try Data("voice".utf8).write(to: folder.appendingPathComponent("Meeting.m4a"))
        try Data("note".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        try Data("call".utf8).write(to: folder.appendingPathComponent("call.WAV"))

        let scanner = RecordingLibraryScanner()
        let recordings = try scanner.scan(folder: folder, metadata: .empty)

        XCTAssertEqual(recordings.map(\.title), ["call", "Meeting"])
        XCTAssertEqual(recordings.map(\.fileExtension), ["wav", "m4a"])
    }

    func testScannerIncludesCommonIOSRecordingAndAVFoundationAudioContainers() throws {
        let folder = try makeTemporaryFolder()
        let supportedExtensions = [
            "3g2",
            "3gp",
            "3gp2",
            "3gpp",
            "aac",
            "aif",
            "aiff",
            "aifc",
            "amr",
            "caf",
            "flac",
            "m4a",
            "mp3",
            "wav"
        ]
        XCTAssertEqual(RecordingLibraryScanner.defaultSupportedExtensions, Set(supportedExtensions))

        for fileExtension in supportedExtensions {
            try Data("audio".utf8).write(to: folder.appendingPathComponent("sample.\(fileExtension)"))
        }
        try Data("text".utf8).write(to: folder.appendingPathComponent("sample.txt"))

        let recordings = try RecordingLibraryScanner().scan(folder: folder, metadata: .empty)

        XCTAssertEqual(Set(recordings.map(\.fileExtension)), Set(supportedExtensions))
    }

    func testScannerAcceptsDirectAudioFileSelections() throws {
        let folder = try makeTemporaryFolder()
        let mp3URL = folder.appendingPathComponent("课堂录音.MP3")
        let m4aURL = folder.appendingPathComponent("语音备忘录.m4a")
        let textURL = folder.appendingPathComponent("说明.txt")
        try Data("mp3".utf8).write(to: mp3URL)
        try Data("m4a".utf8).write(to: m4aURL)
        try Data("text".utf8).write(to: textURL)

        let recordings = try RecordingLibraryScanner().scan(urls: [mp3URL, textURL, m4aURL], metadata: .empty)

        XCTAssertEqual(Set(recordings.map(\.title)), ["课堂录音", "语音备忘录"])
        XCTAssertEqual(Set(recordings.map(\.fileExtension)), ["mp3", "m4a"])
    }

    func testScannerFailsForMissingFolderWithActionableError() throws {
        let scanner = RecordingLibraryScanner()
        let missingFolder = URL(fileURLWithPath: "/tmp/record-reader-missing-\(UUID().uuidString)")

        XCTAssertThrowsError(try scanner.scan(folder: missingFolder, metadata: .empty)) { error in
            XCTAssertEqual(error as? RecordingLibraryError, .folderNotFound(missingFolder.path))
        }
    }

    func testScannerAppliesFavoriteAndCategoryMetadata() throws {
        let folder = try makeTemporaryFolder()
        let audioURL = folder.appendingPathComponent("Interview.mp3")
        try Data("audio".utf8).write(to: audioURL)
        let key = RecordingKey.make(for: audioURL)
        let metadata = RecordingLibraryMetadata(
            records: [
                key: RecordingMetadata(isFavorite: true, category: "Work", subtitle: nil)
            ],
            selectedFolderBookmark: nil
        )

        let recording = try XCTUnwrap(try scannerResult(folder: folder, metadata: metadata).first)

        XCTAssertTrue(recording.isFavorite)
        XCTAssertEqual(recording.category, "Work")
    }

    func testScannerSkipsDeletedRecordingRecordsWithoutDeletingFiles() throws {
        let folder = try makeTemporaryFolder()
        let hiddenURL = folder.appendingPathComponent("Hidden.mp3")
        let visibleURL = folder.appendingPathComponent("Visible.mp3")
        try Data("hidden".utf8).write(to: hiddenURL)
        try Data("visible".utf8).write(to: visibleURL)
        let metadata = RecordingLibraryMetadata(
            records: [:],
            selectedFolderBookmark: nil,
            hiddenRecordingIDs: [RecordingKey.make(for: hiddenURL)]
        )

        let recordings = try scannerResult(folder: folder, metadata: metadata)

        XCTAssertEqual(recordings.map(\.title), ["Visible"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: hiddenURL.path))
    }

    private func scannerResult(
        folder: URL,
        metadata: RecordingLibraryMetadata
    ) throws -> [Recording] {
        try RecordingLibraryScanner().scan(folder: folder, metadata: metadata)
    }

    private func makeTemporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecordReaderTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
