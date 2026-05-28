import RecordReaderCore
import SwiftUI

struct RecordingLibrarySheet: View {
    @ObservedObject var library: AudioLibraryViewModel
    let onSelect: (Recording) -> Void
    @State private var isBatchMode = false
    @State private var selectedIDs: Set<Recording.ID> = []
    @State private var isBatchCategoryPresented = false
    @State private var batchCategory = ""

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
                    ForEach(library.visibleRecordings) { recording in
                        recordingRow(recording)
                    }
                } header: {
                    Text(library.currentFilterTitle)
                }
            }
            .navigationTitle("录音")
            .searchable(text: $library.searchText, prompt: "搜索标题、分类或格式")
            .safeAreaInset(edge: .bottom) {
                if isBatchMode {
                    batchToolbar
                }
            }
            .alert("批量设置分类", isPresented: $isBatchCategoryPresented) {
                TextField("分类名称", text: $batchCategory)
                Button("保存") {
                    library.setCategory(batchCategory, ids: selectedIDs)
                    finishBatchMode()
                }
                Button("清除", role: .destructive) {
                    library.setCategory(nil, ids: selectedIDs)
                    finishBatchMode()
                }
                Button("取消", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isBatchMode ? "完成" : "选择") {
                        if isBatchMode {
                            finishBatchMode()
                        } else {
                            isBatchMode = true
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("排序") {
                            ForEach(RecordingSort.allCases, id: \.self) { sort in
                                Button {
                                    library.setSort(sort)
                                } label: {
                                    if library.sort == sort {
                                        Label(sort.title, systemImage: "checkmark")
                                    } else {
                                        Text(sort.title)
                                    }
                                }
                            }
                        }
                        Button {
                            library.refresh()
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    private func recordingRow(_ recording: Recording) -> some View {
        Button {
            if isBatchMode {
                toggleSelection(recording.id)
            } else {
                onSelect(recording)
            }
        } label: {
            HStack(spacing: 12) {
                if isBatchMode {
                    Image(systemName: selectedIDs.contains(recording.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(recording.id) ? .accent : .secondary)
                        .frame(width: 24)
                } else {
                    Image(systemName: recording.isFavorite ? "heart.fill" : "waveform")
                        .foregroundStyle(recording.isFavorite ? .red : .secondary)
                        .frame(width: 24)
                }

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

    private var batchToolbar: some View {
        HStack {
            Button {
                library.setFavorite(true, ids: selectedIDs)
                finishBatchMode()
            } label: {
                Label("收藏", systemImage: "heart.fill")
            }

            Spacer()

            Button {
                library.setFavorite(false, ids: selectedIDs)
                finishBatchMode()
            } label: {
                Label("取消", systemImage: "heart")
            }

            Spacer()

            Button {
                batchCategory = ""
                isBatchCategoryPresented = true
            } label: {
                Label("分类", systemImage: "tag")
            }
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
        .disabled(selectedIDs.isEmpty)
    }

    private func filterButton(_ filter: RecordingFilter, title: String, systemImage: String) -> some View {
        Button {
            library.setFilter(filter)
            selectedIDs = []
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func toggleSelection(_ id: Recording.ID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func finishBatchMode() {
        selectedIDs = []
        isBatchMode = false
    }
}
