import RecordReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var library = AudioLibraryViewModel()
    @StateObject private var player = PlayerController()
    @State private var isFolderImporterPresented = false
    @State private var isLibraryPresented = false
    @State private var isCategoryEditorPresented = false
    @State private var pendingCategory = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.playerBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    header

                    if let recording = library.selectedRecording {
                        playerContent(
                            recording,
                            subtitlePanelHeight: subtitlePanelHeight(for: geometry.size.height)
                        )
                    } else {
                        emptyState
                    }

                    Spacer(minLength: 12)
                    bottomBar
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: 430, maxHeight: .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(.white)
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder, .audio],
            allowsMultipleSelection: true
        ) { result in
            library.selectImportedItems(result)
        }
        .sheet(isPresented: $isLibraryPresented) {
            RecordingLibrarySheet(library: library) { recording in
                library.select(recording)
                player.load(url: recording.url)
                isLibraryPresented = false
            }
        }
        .alert("设置分类", isPresented: $isCategoryEditorPresented) {
            TextField("分类名称", text: $pendingCategory)
            Button("保存") {
                library.setCategory(pendingCategory)
            }
            Button("清除", role: .destructive) {
                library.setCategory(nil)
            }
            Button("取消", role: .cancel) {}
        }
        .task {
            library.restoreLastFolder()
        }
        .onChange(of: library.selectedRecording?.id) { _, _ in
            if let selected = library.selectedRecording {
                player.load(url: selected.url)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                isFolderImporterPresented = true
            } label: {
                Image(systemName: "folder")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("选择录音文件夹或音频文件")

            Spacer()

            Text(library.currentFilterTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))

            Spacer()

            Button {
                isLibraryPresented = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("显示录音列表")
        }
        .buttonStyle(.plain)
    }

    private func playerContent(_ recording: Recording, subtitlePanelHeight: CGFloat) -> some View {
        VStack(spacing: 24) {
            SubtitlePanel(recording: recording, errorMessage: library.errorMessage)
                .frame(maxWidth: .infinity)
                .frame(height: subtitlePanelHeight)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(recording.title)
                            .font(.title2.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(recording.category ?? "未分类")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    Button {
                        library.toggleFavorite()
                    } label: {
                        Image(systemName: recording.isFavorite ? "heart.fill" : "heart")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(recording.isFavorite ? .white : .white.opacity(0.72))
                    }
                    .accessibilityLabel(recording.isFavorite ? "取消收藏" : "收藏录音")

                    Menu {
                        Button("识别中文字幕") {
                            library.recognizeSubtitleForSelectedRecording()
                        }
                        Button("编辑分类") {
                            pendingCategory = recording.category ?? ""
                            isCategoryEditorPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2.weight(.bold))
                    }
                    .accessibilityLabel("更多操作")
                }

                ProgressView(value: player.progress)
                    .tint(.white)
                    .background(.white.opacity(0.18))

                HStack {
                    Text(player.currentTimeLabel)
                    Spacer()
                    Text(player.durationLabel)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 36) {
                Button {
                    player.seek(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                }

                Button {
                    player.playPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 74, height: 74)
                        .background(.white)
                        .clipShape(Circle())
                }
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

                Button {
                    player.seek(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                }
            }
            .font(.title.weight(.semibold))
            .buttonStyle(.plain)

            if let playbackError = player.errorMessage {
                Text(playbackError)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
            Text("选择录音文件夹或音频文件")
                .font(.title2.weight(.bold))
            Text("扫描手机可访问的录音文件，支持播放、收藏、分类和中文语音转字幕。")
                .font(.body)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Button {
                isFolderImporterPresented = true
            } label: {
                Label("选择录音", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                library.setFilter(.all)
            } label: {
                Image(systemName: "tray.full")
            }

            Spacer()

            Button {
                library.setFilter(.favorites)
            } label: {
                Image(systemName: "heart")
            }

            Spacer()

            Button {
                isLibraryPresented = true
            } label: {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
            }

            Spacer()

            Button {
                pendingCategory = library.selectedRecording?.category ?? ""
                isCategoryEditorPresented = true
            } label: {
                Image(systemName: "tag")
            }
            .disabled(library.selectedRecording == nil)
        }
        .font(.title2.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.82))
    }

    private func subtitlePanelHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.42, 260), 430)
    }
}

private extension Color {
    static let playerBackground = Color(red: 0.07, green: 0.055, blue: 0.07)
}
