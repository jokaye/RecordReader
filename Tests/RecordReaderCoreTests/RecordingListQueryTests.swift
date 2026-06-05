import XCTest
@testable import RecordReaderCore

final class RecordingListQueryTests: XCTestCase {
    func testVisibleRecordingsFiltersSearchesAndSortsByNewestModifiedDate() {
        let recordings = [
            makeRecording(id: "a", title: "会议记录", fileExtension: "m4a", modifiedAt: Date(timeIntervalSince1970: 10), isFavorite: true, category: "工作"),
            makeRecording(id: "b", title: "课堂录音", fileExtension: "mp3", modifiedAt: Date(timeIntervalSince1970: 30), isFavorite: true, category: "学习"),
            makeRecording(id: "c", title: "购物清单", fileExtension: "wav", modifiedAt: Date(timeIntervalSince1970: 20), isFavorite: false, category: "生活")
        ]

        let visible = RecordingListQuery.visibleRecordings(
            recordings,
            filter: .favorites,
            searchText: "录音",
            sort: .modifiedNewest
        )

        XCTAssertEqual(visible.map(\.id), ["b"])
    }

    func testVisibleRecordingsSearchesCategoryAndExtension() {
        let recordings = [
            makeRecording(id: "a", title: "会议记录", fileExtension: "m4a", modifiedAt: nil, category: "工作"),
            makeRecording(id: "b", title: "课堂录音", fileExtension: "mp3", modifiedAt: nil, category: "学习")
        ]

        XCTAssertEqual(
            RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "工作", sort: .nameAscending).map(\.id),
            ["a"]
        )
        XCTAssertEqual(
            RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "MP3", sort: .nameAscending).map(\.id),
            ["b"]
        )
    }

    func testVisibleRecordingsSortsByNameSizeAndExtension() {
        let recordings = [
            makeRecording(id: "a", title: "B", fileExtension: "wav", fileSize: 30),
            makeRecording(id: "b", title: "A", fileExtension: "mp3", fileSize: 10),
            makeRecording(id: "c", title: "C", fileExtension: "m4a", fileSize: 20)
        ]

        XCTAssertEqual(RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "", sort: .nameAscending).map(\.id), ["b", "a", "c"])
        XCTAssertEqual(RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "", sort: .fileSizeLargest).map(\.id), ["a", "c", "b"])
        XCTAssertEqual(RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "", sort: .fileExtension).map(\.id), ["c", "b", "a"])
    }

    func testVisibleRecordingsFiltersRecentRecordingsByModifiedOrCreatedDate() {
        let newestDate = Date(timeIntervalSince1970: 1_700_000_000)
        let recentImportedDate = newestDate.addingTimeInterval(-2 * 24 * 60 * 60)
        let oldDate = newestDate.addingTimeInterval(-8 * 24 * 60 * 60)
        let recordings = [
            makeRecording(id: "new", title: "New", createdAt: newestDate, modifiedAt: newestDate),
            makeRecording(id: "imported", title: "Imported", createdAt: recentImportedDate, modifiedAt: nil),
            makeRecording(id: "old", title: "Old", createdAt: oldDate, modifiedAt: oldDate),
            makeRecording(id: "unknown", title: "Unknown", createdAt: nil, modifiedAt: nil)
        ]

        XCTAssertEqual(
            RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "", sort: .modifiedNewest, quickFilter: .recent).map(\.id),
            ["new", "imported"]
        )
    }

    func testVisibleRecordingsFiltersBySubtitleAvailability() {
        let recordings = [
            makeRecording(id: "ready", title: "Ready", subtitle: SubtitleDocument(status: .ready, segments: [], errorMessage: nil)),
            makeRecording(id: "missing", title: "Missing", subtitle: nil),
            makeRecording(id: "failed", title: "Failed", subtitle: SubtitleDocument(status: .failed, segments: [], errorMessage: "识别失败")),
            makeRecording(id: "recognizing", title: "Recognizing", subtitle: SubtitleDocument(status: .recognizing, segments: [], errorMessage: nil))
        ]

        XCTAssertEqual(
            RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "", sort: .nameAscending, quickFilter: .withSubtitles).map(\.id),
            ["ready"]
        )
        XCTAssertEqual(
            RecordingListQuery.visibleRecordings(recordings, filter: .all, searchText: "", sort: .nameAscending, quickFilter: .withoutSubtitles).map(\.id),
            ["failed", "missing", "recognizing"]
        )
    }

    func testQueueNavigationFindsPreviousAndNextInsideVisibleRecordings() {
        let recordings = [
            makeRecording(id: "a", title: "A"),
            makeRecording(id: "b", title: "B"),
            makeRecording(id: "c", title: "C")
        ]

        XCTAssertEqual(RecordingListQuery.previousRecording(before: "b", in: recordings)?.id, "a")
        XCTAssertEqual(RecordingListQuery.nextRecording(after: "b", in: recordings)?.id, "c")
        XCTAssertNil(RecordingListQuery.previousRecording(before: "a", in: recordings))
        XCTAssertNil(RecordingListQuery.nextRecording(after: "c", in: recordings))
    }

    func testInitialImportSelectionIgnoresExistingFiltersAndSearchText() {
        let recordings = [
            makeRecording(id: "a", title: "A Imported Recording", fileExtension: "mp3", modifiedAt: Date(timeIntervalSince1970: 10)),
            makeRecording(id: "b", title: "B Other Recording", fileExtension: "m4a", modifiedAt: Date(timeIntervalSince1970: 20))
        ]

        let currentlyVisible = RecordingListQuery.visibleRecordings(
            recordings,
            filter: .favorites,
            searchText: "不存在",
            sort: .nameAscending
        )

        XCTAssertTrue(currentlyVisible.isEmpty)
        XCTAssertEqual(
            RecordingListQuery.initialSelectionAfterImport(recordings, sort: .nameAscending)?.id,
            "a"
        )
    }

    func testApplyingMetadataUpdatesOnlyLibraryFieldsAndKeepsFileIdentity() {
        let subtitle = SubtitleDocument(
            status: .failed,
            segments: [],
            errorMessage: "识别失败"
        )
        let recordings = [
            makeRecording(id: "a", title: "会议记录", fileExtension: "mp3", fileSize: 1024, modifiedAt: Date(timeIntervalSince1970: 10)),
            makeRecording(id: "b", title: "课堂录音", fileExtension: "m4a", fileSize: 2048, modifiedAt: Date(timeIntervalSince1970: 20), isFavorite: true, category: "学习")
        ]

        let updated = RecordingListQuery.recordingsByApplyingMetadata(
            RecordingMetadata(isFavorite: true, category: "工作", subtitle: subtitle),
            to: "a",
            in: recordings
        )

        XCTAssertEqual(updated[0].id, recordings[0].id)
        XCTAssertEqual(updated[0].url, recordings[0].url)
        XCTAssertEqual(updated[0].title, recordings[0].title)
        XCTAssertEqual(updated[0].fileSize, recordings[0].fileSize)
        XCTAssertEqual(updated[0].modifiedAt, recordings[0].modifiedAt)
        XCTAssertTrue(updated[0].isFavorite)
        XCTAssertEqual(updated[0].category, "工作")
        XCTAssertEqual(updated[0].subtitle, subtitle)
        XCTAssertEqual(updated[1], recordings[1])
    }

    private func makeRecording(
        id: String,
        title: String,
        fileExtension: String = "m4a",
        fileSize: Int64? = nil,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        isFavorite: Bool = false,
        category: String? = nil,
        subtitle: SubtitleDocument? = nil
    ) -> Recording {
        Recording(
            id: id,
            url: URL(fileURLWithPath: "/tmp/\(title).\(fileExtension)"),
            title: title,
            fileExtension: fileExtension,
            fileSize: fileSize,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            isFavorite: isFavorite,
            category: category,
            subtitle: subtitle
        )
    }
}
