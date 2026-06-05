import RecordReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("recordReader.themeMode") private var themeModeRawValue = AppThemeMode.light.rawValue
    @StateObject private var library = AudioLibraryViewModel()
    @StateObject private var player = PlayerController()
    @State private var activeImportMode: ImportMode?
    @State private var isLibraryPresented = false
    @State private var isDebugLogPresented = false
    @State private var isSettingsPresented = false
    @State private var isCategoryEditorPresented = false
    @State private var pendingCategory = ""
    @State private var seekDraftProgress: Double?
    @State private var subtitleDisplayMode: SubtitleDisplayMode = .follow

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                theme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if let transientStatusMessage {
                        statusRow(transientStatusMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let recording = library.selectedRecording {
                        playerContent(
                            recording,
                            subtitlePanelHeight: subtitlePanelHeight(
                                for: recording,
                                availableHeight: geometry.size.height
                            )
                        )
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: 430, maxHeight: .infinity)
                .background(theme.screenSurface)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: 0.2), value: transientStatusMessage)
                .animation(.easeOut(duration: 0.22), value: library.selectedRecording?.id)
            }
        }
        .foregroundStyle(theme.primaryText)
        .environment(\.appTheme, theme)
        .preferredColorScheme(selectedThemeMode.colorScheme)
        .background(
            DocumentPickerPresenter(mode: $activeImportMode) { urls in
                DebugLog.shared.log("ContentView 收到回调：\(urls.count) 个 URL")
                library.selectImportedItems(.success(urls))
            }
        )
        .sheet(isPresented: $isDebugLogPresented) {
            DebugLogView()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(themeMode: themeModeBinding) {
                isDebugLogPresented = true
            }
            .preferredColorScheme(selectedThemeMode.colorScheme)
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
            } else {
                player.unload()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image("AppMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .accessibilityHidden(true)

            Spacer(minLength: 12)

            if !library.recordings.isEmpty {
                importMenu
            }

            Button {
                isLibraryPresented = true
            } label: {
                Image(systemName: "list.bullet")
            }
            .accessibilityLabel("显示录音列表")

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("设置")
        }
        .font(.title2.weight(.semibold))
        .foregroundStyle(theme.secondaryText)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .background(theme.headerBackground)
        .buttonStyle(IconPressButtonStyle())
    }

    private var importMenu: some View {
        Menu {
            Button {
                presentImporter(.audio)
            } label: {
                Label("选择音频", systemImage: "waveform.badge.plus")
            }

            Button {
                presentImporter(.folder)
            } label: {
                Label("选择文件夹", systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("导入录音")
    }

    private func statusRow(_ message: String) -> some View {
        Label(message, systemImage: statusIcon(for: message))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 44)
            .padding(.vertical, 14)
            .background(theme.screenSurface)
    }

    private var transientStatusMessage: String? {
        if let errorMessage = library.errorMessage {
            return errorMessage
        }
        if library.isLoading {
            return library.statusMessage ?? "正在扫描录音..."
        }
        guard let statusMessage = library.statusMessage else {
            return nil
        }
        if isTransientStatusMessage(statusMessage) {
            return statusMessage
        }
        return nil
    }

    private func isTransientStatusMessage(_ message: String) -> Bool {
        let transientMarkers = ["正在", "失败", "错误", "不可用", "未识别"]
        return transientMarkers.contains { message.contains($0) }
    }

    private func statusIcon(for message: String) -> String {
        if message.contains("失败")
            || message.contains("错误")
            || message.contains("不可用")
            || message.contains("未识别")
            || message.contains("无法")
            || message.contains("没有")
            || message.contains("请先") {
            return "exclamationmark.triangle"
        }
        if message.contains("识别") || message.contains("扫描") {
            return "waveform.badge.magnifyingglass"
        }
        return "checkmark.circle"
    }

    private func playerContent(_ recording: Recording, subtitlePanelHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            SubtitlePanel(
                recording: recording,
                currentTime: player.currentTime,
                displayMode: $subtitleDisplayMode,
                errorMessage: library.errorMessage,
                recognitionProgress: library.subtitleRecognitionProgress,
                onSeekToSubtitle: { time in
                    player.seek(to: time)
                },
                onRecognize: {
                    library.recognizeSubtitleForSelectedRecording()
                }
            )
                .frame(maxWidth: .infinity)
                .frame(height: subtitlePanelHeight)
                .id(recording.id)

            Spacer(minLength: 8)

            playerCard(recording)

            if let playbackError = player.errorMessage {
                Text(playbackError)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }

    private func playerCard(_ recording: Recording) -> some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(recording.category ?? "未分类")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        library.toggleFavorite()
                    }
                } label: {
                    Image(systemName: recording.isFavorite ? "heart.fill" : "heart")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(recording.isFavorite ? theme.accent : theme.secondaryText)
                }
                .buttonStyle(IconPressButtonStyle())
                .accessibilityLabel(recording.isFavorite ? "取消收藏" : "收藏录音")

                Menu {
                    Button("编辑分类") {
                        pendingCategory = recording.category ?? ""
                        isCategoryEditorPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(IconPressButtonStyle())
                .accessibilityLabel("更多操作")
            }

            VStack(spacing: 8) {
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
                .tint(theme.accent)
                .accessibilityLabel("播放进度")

                HStack {
                    Text(player.currentTimeLabel)
                    Spacer()
                    Button {
                        player.cycleSpeed()
                    } label: {
                        Text(player.speed.label)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(ScalePressButtonStyle())
                    .accessibilityLabel("播放速度 \(player.speed.label)")
                    Spacer()
                    Text(player.durationLabel)
                }
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(theme.secondaryText)
            }

            playbackControls
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.elevatedCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
    }

    private var playbackControls: some View {
        HStack(spacing: 25) {
            previousButton

            Button {
                player.seek(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
            }
            .accessibilityLabel("后退 15 秒")

            Button {
                player.playPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.controlForeground)
                    .frame(width: 64, height: 64)
                    .background(theme.controlFill)
                    .clipShape(Circle())
                    .shadow(color: theme.cardShadow, radius: 18, y: 8)
            }
            .buttonStyle(PlayPressButtonStyle())
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

            Button {
                player.seek(by: 15)
            } label: {
                Image(systemName: "goforward.15")
            }
            .accessibilityLabel("前进 15 秒")

            nextButton
        }
        .font(.title2.weight(.semibold))
        .foregroundStyle(theme.secondaryText)
        .buttonStyle(ControlPressButtonStyle())
    }

    private var previousButton: some View {
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
        .opacity(library.hasPreviousRecording ? 1 : 0.18)
        .accessibilityLabel("上一首")
    }

    private var nextButton: some View {
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
        .opacity(library.hasNextRecording ? 1 : 0.18)
        .accessibilityLabel("下一首")
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
            Text("选择录音文件夹或音频文件")
                .font(.title2.weight(.bold))
            Text("扫描手机可访问的录音文件，支持播放、收藏、分类和中文语音转字幕。")
                .font(.body)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            emptyImportMenu
            if library.isLoading {
                NeonLoadingIndicator(progress: nil)
                Text("正在扫描录音...")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            } else if let errorMessage = library.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 34)
    }

    private var emptyImportMenu: some View {
        Menu {
            Button {
                presentImporter(.audio)
            } label: {
                Label("选择音频", systemImage: "waveform.badge.plus")
            }

            Button {
                presentImporter(.folder)
            } label: {
                Label("选择文件夹", systemImage: "folder.badge.plus")
            }
        } label: {
            Label("添加录音", systemImage: "plus")
        }
        .buttonStyle(FilledCapsuleButtonStyle())
        .accessibilityLabel("添加录音")
    }

    private func subtitlePanelHeight(for recording: Recording, availableHeight: CGFloat) -> CGFloat {
        if shouldExpandSubtitlePanel(for: recording) {
            return min(max(availableHeight * 0.48, 300), 520)
        }
        return min(max(availableHeight * 0.28, 210), 300)
    }

    private func shouldExpandSubtitlePanel(for recording: Recording) -> Bool {
        guard let subtitle = recording.subtitle else {
            return false
        }
        if !subtitle.segments.isEmpty {
            return true
        }
        return subtitle.status == .recognizing
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

    private var selectedThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRawValue) ?? .light
    }

    private var themeModeBinding: Binding<AppThemeMode> {
        Binding(
            get: { selectedThemeMode },
            set: { themeModeRawValue = $0.rawValue }
        )
    }

    private var theme: AppTheme {
        AppTheme(mode: selectedThemeMode)
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
            .overlay(
                GlowPressOverlay(shape: .rounded(10), isPressed: configuration.isPressed)
            )
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
            .overlay(
                GlowPressOverlay(shape: .rounded(12), isPressed: configuration.isPressed)
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct PlayPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .overlay(
                GlowPressOverlay(shape: .circle, isPressed: configuration.isPressed)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 18, y: 10)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .overlay(
                GlowPressOverlay(shape: .rounded(12), isPressed: configuration.isPressed)
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct FilledCapsuleButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(theme.accent.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .overlay(
                GlowPressOverlay(shape: .capsule, isPressed: configuration.isPressed)
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct SecondaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(theme.subtleFill.opacity(configuration.isPressed ? 0.76 : 1), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
            .foregroundStyle(theme.primaryText)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .overlay(
                GlowPressOverlay(shape: .capsule, isPressed: configuration.isPressed)
            )
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
