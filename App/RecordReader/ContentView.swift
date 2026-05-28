import RecordReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var library = AudioLibraryViewModel()
    @StateObject private var player = PlayerController()
    @State private var isImporterPresented = false
    @State private var importMode: ImportMode = .audio
    @State private var isLibraryPresented = false
    @State private var isCategoryEditorPresented = false
    @State private var pendingCategory = ""
    @State private var seekDraftProgress: Double?

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
            isPresented: $isImporterPresented,
            allowedContentTypes: importMode.allowedContentTypes,
            allowsMultipleSelection: importMode.allowsMultipleSelection
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
            player.onFinish = {
                if let next = library.selectNext() {
                    player.load(url: next.url)
                    player.play()
                }
            }
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
                presentImporter(.folder)
            } label: {
                Image(systemName: "folder")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("选择录音文件夹")

            Button {
                presentImporter(.audio)
            } label: {
                Image(systemName: "waveform.badge.plus")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("选择音频文件")

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

                Slider(
                    value: seekProgressBinding,
                    in: 0...1,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            player.seek(toProgress: seekDraftProgress ?? player.progress)
                            seekDraftProgress = nil
                        }
                    }
                )
                .tint(.white)
                .accessibilityLabel("播放进度")

                HStack {
                    Text(player.currentTimeLabel)
                    Spacer()
                    Text(player.durationLabel)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 24) {
                Button {
                    if let previous = library.selectPrevious() {
                        player.load(url: previous.url)
                    }
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(!library.hasPreviousRecording)
                .accessibilityLabel("上一首")

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

                Button {
                    if let next = library.selectNext() {
                        player.load(url: next.url)
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(!library.hasNextRecording)
                .accessibilityLabel("下一首")
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
            if library.isLoading {
                ProgressView()
                    .tint(.white)
                Text("正在扫描录音...")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.65))
            } else if let errorMessage = library.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button {
                    presentImporter(.folder)
                } label: {
                    Label("选择文件夹", systemImage: "folder.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }

                Button {
                    presentImporter(.audio)
                } label: {
                    Label("选择音频", systemImage: "waveform.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.14))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
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

    private func presentImporter(_ mode: ImportMode) {
        importMode = mode
        isImporterPresented = true
    }

    private var seekProgressBinding: Binding<Double> {
        Binding(
            get: {
                seekDraftProgress ?? player.progress
            },
            set: { newValue in
                seekDraftProgress = newValue
            }
        )
    }
}

private extension Color {
    static let playerBackground = Color(red: 0.07, green: 0.055, blue: 0.07)
}

private enum ImportMode {
    case folder
    case audio

    var allowedContentTypes: [UTType] {
        switch self {
        case .folder:
            return [.folder]
        case .audio:
            return [.audio]
        }
    }

    var allowsMultipleSelection: Bool {
        switch self {
        case .folder:
            return false
        case .audio:
            return true
        }
    }
}
