import XCTest
@testable import RecordReaderCore

final class RecordingMetadataStoreTests: XCTestCase {
    func testStorePersistsFavoriteCategoryAndSubtitle() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecordReaderTests")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("metadata.json")
        let store = RecordingMetadataStore(fileURL: storeURL)
        let metadata = RecordingLibraryMetadata(
            records: [
                "recording-a": RecordingMetadata(
                    isFavorite: true,
                    category: "Ideas",
                    subtitle: SubtitleDocument(
                        status: .ready,
                        segments: [
                            SubtitleSegment(startTime: 0, endTime: 1.5, text: "Hello")
                        ],
                        errorMessage: nil
                    )
                )
            ],
            selectedFolderBookmark: Data([1, 2, 3])
        )

        try store.save(metadata)
        let loaded = try store.load()

        XCTAssertEqual(loaded, metadata)
    }

    func testStoreLoadsEmptyMetadataWhenFileDoesNotExist() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecordReaderTests")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("metadata.json")
        let store = RecordingMetadataStore(fileURL: storeURL)

        XCTAssertEqual(try store.load(), .empty)
    }
}
