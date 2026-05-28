import Foundation

public enum RecordingFilter: Hashable {
    case all
    case favorites
    case category(String)
}

public enum RecordingSort: String, CaseIterable, Codable, Equatable {
    case nameAscending
    case modifiedNewest
    case modifiedOldest
    case fileSizeLargest
    case fileExtension

    public var title: String {
        switch self {
        case .nameAscending:
            return "名称"
        case .modifiedNewest:
            return "最新修改"
        case .modifiedOldest:
            return "最早修改"
        case .fileSizeLargest:
            return "文件大小"
        case .fileExtension:
            return "格式"
        }
    }
}

public enum RecordingListQuery {
    public static func visibleRecordings(
        _ recordings: [Recording],
        filter: RecordingFilter,
        searchText: String,
        sort: RecordingSort
    ) -> [Recording] {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = recordings.filter { recording in
            matches(filter: filter, recording: recording)
                && matches(searchText: normalizedSearchText, recording: recording)
        }
        return sortRecordings(filtered, by: sort)
    }

    public static func previousRecording(before id: Recording.ID, in recordings: [Recording]) -> Recording? {
        guard let index = recordings.firstIndex(where: { $0.id == id }), index > recordings.startIndex else {
            return nil
        }
        return recordings[recordings.index(before: index)]
    }

    public static func nextRecording(after id: Recording.ID, in recordings: [Recording]) -> Recording? {
        guard let index = recordings.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let nextIndex = recordings.index(after: index)
        guard nextIndex < recordings.endIndex else {
            return nil
        }
        return recordings[nextIndex]
    }

    public static func initialSelectionAfterImport(
        _ recordings: [Recording],
        sort: RecordingSort
    ) -> Recording? {
        sortRecordings(recordings, by: sort).first
    }

    private static func matches(filter: RecordingFilter, recording: Recording) -> Bool {
        switch filter {
        case .all:
            return true
        case .favorites:
            return recording.isFavorite
        case .category(let category):
            return recording.category == category
        }
    }

    private static func matches(searchText: String, recording: Recording) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }
        return recording.title.localizedCaseInsensitiveContains(searchText)
            || recording.fileExtension.localizedCaseInsensitiveContains(searchText)
            || (recording.category?.localizedCaseInsensitiveContains(searchText) ?? false)
    }

    private static func sortRecordings(_ recordings: [Recording], by sort: RecordingSort) -> [Recording] {
        recordings.sorted { lhs, rhs in
            switch sort {
            case .nameAscending:
                return compareText(lhs.title, rhs.title)
            case .modifiedNewest:
                return compareDate(lhs.modifiedAt, rhs.modifiedAt, newestFirst: true, lhs: lhs, rhs: rhs)
            case .modifiedOldest:
                return compareDate(lhs.modifiedAt, rhs.modifiedAt, newestFirst: false, lhs: lhs, rhs: rhs)
            case .fileSizeLargest:
                if lhs.fileSize != rhs.fileSize {
                    return (lhs.fileSize ?? -1) > (rhs.fileSize ?? -1)
                }
                return compareText(lhs.title, rhs.title)
            case .fileExtension:
                if lhs.fileExtension != rhs.fileExtension {
                    return compareText(lhs.fileExtension, rhs.fileExtension)
                }
                return compareText(lhs.title, rhs.title)
            }
        }
    }

    private static func compareDate(
        _ lhsDate: Date?,
        _ rhsDate: Date?,
        newestFirst: Bool,
        lhs: Recording,
        rhs: Recording
    ) -> Bool {
        if lhsDate != rhsDate {
            let lhsValue = lhsDate ?? .distantPast
            let rhsValue = rhsDate ?? .distantPast
            return newestFirst ? lhsValue > rhsValue : lhsValue < rhsValue
        }
        return compareText(lhs.title, rhs.title)
    }

    private static func compareText(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
}
