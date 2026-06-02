import RecordReaderCore
import SwiftUI

struct RecordingLibrarySheet: View {
    @ObservedObject var library: AudioLibraryViewModel
    let onSelect: (Recording) -> Void
    @Environment(\.appTheme) private var theme
    @State private var isBatchMode = false
    @State private var selectedIDs: Set<Recording.ID> = []
    @State private var isBatchCategoryPresented = false
    @State private var batchCategory = ""
    @State private var pendingDeleteIDs: Set<Recording.ID> = []
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterStrip
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(library.visibleRecordings) { recording in
                        recordingRow(recording)
                            .listRowBackground(rowBackground(for: recording))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    requestDelete(ids: [recording.id])
                                } label: {
                                    Label("删除记录", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(library.currentFilterTitle)
                }
            }
            .navigationTitle("录音")
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundGradient)
            .tint(theme.accent)
            .searchable(text: $library.searchText, prompt: "搜索标题、分类或格式")
            .safeAreaInset(edge: .bottom) {
                if isBatchMode {
                    batchToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            .confirmationDialog("删除播放记录？", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
                Button("删除记录", role: .destructive) {
                    library.deleteRecordingRecords(ids: pendingDeleteIDs)
                    finishBatchMode()
                    pendingDeleteIDs = []
                }
                Button("取消", role: .cancel) {
                    pendingDeleteIDs = []
                }
            } message: {
                Text("只会从播放列表移除记录，不会删除原始音频文件。")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isBatchMode ? "完成" : "选择") {
                        withAnimation(.easeOut(duration: 0.18)) {
                            if isBatchMode {
                                finishBatchMode()
                            } else {
                                isBatchMode = true
                            }
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
            .animation(.easeOut(duration: 0.18), value: isBatchMode)
            .animation(.easeOut(duration: 0.18), value: selectedIDs)
        }
        .preferredColorScheme(theme.mode.colorScheme)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(.all, title: "全部", systemImage: "tray.full")
                filterChip(.favorites, title: "收藏", systemImage: "heart")
                ForEach(library.categories, id: \.self) { category in
                    filterChip(.category(category), title: category, systemImage: "tag")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func recordingRow(_ recording: Recording) -> some View {
        let isSelected = library.selectedRecording?.id == recording.id
        let isChecked = selectedIDs.contains(recording.id)

        return Button {
            if isBatchMode {
                toggleSelection(recording.id)
            } else {
                onSelect(recording)
            }
        } label: {
            HStack(spacing: 12) {
                if isBatchMode {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isChecked ? theme.accent : theme.mutedText)
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: isSelected ? "play.circle.fill" : (recording.isFavorite ? "heart.fill" : "waveform"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(recording.isFavorite ? theme.accent : theme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(theme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text(recording.category ?? "未分类")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                Text(recording.fileExtension.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.mutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.subtleFill, in: Capsule())
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
    }

    private var batchToolbar: some View {
        VStack(spacing: 10) {
            Text(selectedIDs.isEmpty ? "选择要批量管理的录音" : "已选择 \(selectedIDs.count) 段录音")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

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

                Spacer()

                Button(role: .destructive) {
                    requestDelete(ids: selectedIDs)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(theme.elevatedCard)
        .overlay(
            Rectangle()
                .fill(theme.cardStroke)
                .frame(height: 1),
            alignment: .top
        )
        .shadow(color: theme.cardShadow, radius: 18, y: -6)
        .disabled(selectedIDs.isEmpty)
        .opacity(selectedIDs.isEmpty ? 0.58 : 1)
    }

    private func filterChip(_ filter: RecordingFilter, title: String, systemImage: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                library.setFilter(filter)
                selectedIDs = []
            }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(chipBackground(for: filter), in: Capsule())
                .foregroundStyle(chipForeground(for: filter))
        }
        .buttonStyle(.plain)
    }

    private func requestDelete(ids: Set<Recording.ID>) {
        guard !ids.isEmpty else {
            return
        }
        pendingDeleteIDs = ids
        isDeleteConfirmationPresented = true
    }

    private func rowBackground(for recording: Recording) -> Color {
        guard library.selectedRecording?.id == recording.id else {
            return theme.elevatedCard
        }
        return theme.softAccent.opacity(0.78)
    }

    private func chipBackground(for filter: RecordingFilter) -> Color {
        library.filter == filter ? theme.accent : theme.elevatedCard
    }

    private func chipForeground(for filter: RecordingFilter) -> Color {
        library.filter == filter ? Color.white : theme.secondaryText
    }

    private func toggleSelection(_ id: Recording.ID) {
        withAnimation(.easeOut(duration: 0.16)) {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
        }
    }

    private func finishBatchMode() {
        withAnimation(.easeOut(duration: 0.18)) {
            selectedIDs = []
            isBatchMode = false
        }
    }
}
