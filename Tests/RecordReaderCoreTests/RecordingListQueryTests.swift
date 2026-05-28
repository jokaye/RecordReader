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

    private func makeRecording(
        id: String,
        title: String,
        fileExtension: String = "m4a",
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        isFavorite: Bool = false,
        category: String? = nil
    ) -> Recording {
        Recording(
            id: id,
            url: URL(fileURLWithPath: "/tmp/\(title).\(fileExtension)"),
            title: title,
            fileExtension: fileExtension,
            fileSize: fileSize,
            createdAt: nil,
            modifiedAt: modifiedAt,
            isFavorite: isFavorite,
            category: category,
            subtitle: nil
        )
    }
}
