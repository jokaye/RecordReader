import RecordReaderCore
import SwiftUI

struct RecordingLibrarySheet: View {
    @ObservedObject var library: AudioLibraryViewModel
    let onSelect: (Recording) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterButton(.all, title: "全部录音", systemImage: "tray.full")
                    filterButton(.favorites, title: "收藏", systemImage: "heart")
                    ForEach(library.categories, id: \.self) { category in
                        filterButton(.category(category), title: category, systemImage: "tag")
                    }
                }

                Section {
                    ForEach(library.filteredRecordings) { recording in
                        Button {
                            onSelect(recording)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: recording.isFavorite ? "heart.fill" : "waveform")
                                    .foregroundStyle(recording.isFavorite ? .red : .secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recording.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(recording.category ?? "未分类")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(recording.fileExtension.uppercased())
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(library.currentFilterTitle)
                }
            }
            .navigationTitle("录音")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        library.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func filterButton(_ filter: RecordingFilter, title: String, systemImage: String) -> some View {
        Button {
            library.setFilter(filter)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}
