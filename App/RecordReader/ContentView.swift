import RecordReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var library = AudioLibraryViewModel()
    @StateObject private var player = PlayerController()
    @State private var activeImportMode: ImportMode?
    @State private var isLibraryPresented = false
    @State private var isDebugLogPresented = false
    @State private var isCategoryEditorPresented = false
    @State private var pendingCategory = ""
    @State private var seekDraftProgress: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.playerBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    header

                    if let statusMessage = library.statusMessage {
                        statusCapsule(statusMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

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
                .animation(.easeOut(duration: 0.2), value: library.statusMessage)
                .animation(.easeOut(duration: 0.22), value: library.selectedRecording?.id)
            }
        }
        .foregroundStyle(.white)
        .background(
            DocumentPickerPresenter(mode: $activeImportMode) { urls in
                DebugLog.shared.log("ContentView 收到回调：\(urls.count) 个 URL")
                library.selectImportedItems(.success(urls))
            }
        )
        .sheet(isPresented: $isDebugLogPresented) {
            DebugLogView()
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
                isDebugLogPresented = true
            } label: {
                Image(systemName: "ladybug")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("调试日志")

            Button {
                isLibraryPresented = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("显示录音列表")
        }
        .buttonStyle(IconPressButtonStyle())
    }

    private func statusCapsule(_ message: String) -> some View {
        Label(message, systemImage: statusIcon(for: message))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func statusIcon(for message: String) -> String {
        if message.contains("失败") || message.contains("错误") || message.contains("不可用") {
            return "exclamationmark.triangle"
        }
        if message.contains("识别") || message.contains("扫描") {
            return "waveform.badge.magnifyingglass"
        }
        return "checkmark.circle"
    }

    private func playerContent(_ recording: Recording, subtitlePanelHeight: CGFloat) -> some View {
        VStack(spacing: 24) {
            SubtitlePanel(
                recording: recording,
                errorMessage: library.errorMessage,
                recognitionProgress: library.subtitleRecognitionProgress
            )
                .frame(maxWidth: .infinity)
                .frame(height: subtitlePanelHeight)
                .id(recording.id)

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
                        withAnimation(.easeOut(duration: 0.18)) {
                            library.toggleFavorite()
                        }
                    } label: {
                        Image(systemName: recording.isFavorite ? "heart.fill" : "heart")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(recording.isFavorite ? .white : .white.opacity(0.72))
                    }
                    .buttonStyle(IconPressButtonStyle())
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
                    .buttonStyle(IconPressButtonStyle())
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
                    Button {
                        player.cycleSpeed()
                    } label: {
                        Text(player.speed.label)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.14))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScalePressButtonStyle())
                    .accessibilityLabel("播放速度 \(player.speed.label)")
                    Spacer()
                    Text(player.durationLabel)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 24) {
                Button {
                    let wasPlaying = player.isPlaying
                    var previous: Recording?
                    withAnimation(.easeOut(duration: 0.2)) {
                        previous = library.selectPrevious()
                    }
                    if let previous {
                        player.load(url: previous.url)
                        if wasPlaying {
                            player.play()
                        }
                    }
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(!library.hasPreviousRecording)
                .opacity(library.hasPreviousRecording ? 1 : 0.35)
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
                .buttonStyle(PlayPressButtonStyle())
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

                Button {
                    player.seek(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                }

                Button {
                    let wasPlaying = player.isPlaying
                    var next: Recording?
                    withAnimation(.easeOut(duration: 0.2)) {
                        next = library.selectNext()
                    }
                    if let next {
                        player.load(url: next.url)
                        if wasPlaying {
                            player.play()
                        }
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(!library.hasNextRecording)
                .opacity(library.hasNextRecording ? 1 : 0.35)
                .accessibilityLabel("下一首")
            }
            .font(.title.weight(.semibold))
            .buttonStyle(ControlPressButtonStyle())

            if let playbackError = player.errorMessage {
                Text(playbackError)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
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
                }
                .buttonStyle(FilledCapsuleButtonStyle())

                Button {
                    presentImporter(.audio)
                } label: {
                    Label("选择音频", systemImage: "waveform.badge.plus")
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    library.setFilter(.all)
                }
            } label: {
                Image(systemName: "tray.full")
            }
            .foregroundStyle(library.filter == .all ? .white : .white.opacity(0.58))

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    library.setFilter(.favorites)
                }
            } label: {
                Image(systemName: "heart")
            }
            .foregroundStyle(library.filter == .favorites ? .white : .white.opacity(0.58))

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
        .buttonStyle(IconPressButtonStyle())
    }

    private func subtitlePanelHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.42, 260), 430)
    }

    private func presentImporter(_ mode: ImportMode) {
        DebugLog.shared.log("点击导入按钮：\(mode)")
        activeImportMode = mode
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

private struct IconPressButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 34, minHeight: 34)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.68 : 0.9) : 0.35)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct ControlPressButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 0.92) : 0.35)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct PlayPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 18, y: 10)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct FilledCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
            .foregroundStyle(.black)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.2 : 0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private extension Color {
    static let playerBackground = Color(red: 0.07, green: 0.055, blue: 0.07)
}

enum ImportMode: Identifiable {
    case folder
    case audio

    var id: Self { self }

    var allowedContentTypes: [UTType] {
        switch self {
        case .folder:
            return [.folder]
        case .audio:
            return [.audio, .mp3, .mpeg4Audio, .wav, .aiff, .item]
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

    /// Copy mode (`asCopy: true`) imports a sandbox copy and works without the
    /// open-in-place entitlements a sideloaded build typically lacks; folders
    /// must be opened in place.
    var asCopy: Bool {
        switch self {
        case .folder:
            return false
        case .audio:
            return true
        }
    }
}
