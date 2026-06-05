import RecordReaderCore
import SwiftUI

struct SubtitlePanel: View {
    let recording: Recording
    let currentTime: TimeInterval
    @Binding var displayMode: SubtitleDisplayMode
    let errorMessage: String?
    let recognitionProgress: SubtitleRecognitionProgress?
    let onSeekToSubtitle: (TimeInterval) -> Void
    let onRecognize: () -> Void
    @State private var searchText = ""
    @State private var showsReRecognitionConfirmation = false
    @Environment(\.appTheme) private var theme

    init(
        recording: Recording,
        currentTime: TimeInterval,
        displayMode: Binding<SubtitleDisplayMode>,
        errorMessage: String?,
        recognitionProgress: SubtitleRecognitionProgress?,
        onSeekToSubtitle: @escaping (TimeInterval) -> Void = { _ in },
        onRecognize: @escaping () -> Void
    ) {
        self.recording = recording
        self.currentTime = currentTime
        self._displayMode = displayMode
        self.errorMessage = errorMessage
        self.recognitionProgress = recognitionProgress
        self.onSeekToSubtitle = onSeekToSubtitle
        self.onRecognize = onRecognize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(statusTitle, systemImage: statusIcon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(statusColor)
                Spacer()
                Text(recording.fileExtension.uppercased())
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(theme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
            }

            Rectangle()
                .fill(theme.cardStroke.opacity(0.62))
                .frame(height: 1)
                .padding(.top, 18)
                .padding(.bottom, 14)

            if let subtitle = recording.subtitle, !subtitle.segments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Picker("字幕显示", selection: $displayMode) {
                            ForEach(SubtitleDisplayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button {
                            showsReRecognitionConfirmation = true
                        } label: {
                            Label("重新识别", systemImage: "arrow.clockwise")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.secondaryText)
                        .padding(8)
                        .background(theme.subtleFill.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("重新识别字幕")
                    }

                    subtitleSearchField
                }
                .confirmationDialog(
                    "重新识别会替换当前字幕。",
                    isPresented: $showsReRecognitionConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("重新识别", role: .destructive) {
                        onRecognize()
                    }
                    Button("取消", role: .cancel) {}
                }

                subtitleList(subtitle.segments)
            } else {
                Spacer()
                VStack(spacing: 18) {
                    if status == .recognizing {
                        recognitionProgressView
                    }
                    Text(primaryStatusMessage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let secondaryStatusMessage {
                        Text(secondaryStatusMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.mutedText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    if shouldShowRecognitionAction {
                        Button {
                            onRecognize()
                        } label: {
                            Label(recognitionActionTitle, systemImage: "sparkles")
                        }
                        .buttonStyle(SubtitleActionButtonStyle())
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 22)
        .animation(.easeOut(duration: 0.22), value: status)
        .animation(.easeOut(duration: 0.22), value: recording.subtitle?.segments.count ?? 0)
    }

    private func subtitleList(_ segments: [SubtitleSegment]) -> some View {
        let activeSegmentID = SubtitleTimeline.activeSegment(in: segments, at: currentTime)?.id
        let visibleSegments = filteredSegments(from: segments)
        let searchIsActive = !normalizedSearchText.isEmpty

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if visibleSegments.isEmpty {
                        Text("未找到匹配字幕")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(theme.mutedText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 28)
                    } else {
                        ForEach(visibleSegments) { segment in
                            subtitleRow(segment, isActive: segment.id == activeSegmentID)
                                .id(segment.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                guard !searchIsActive else {
                    return
                }
                scrollToActiveSegment(activeSegmentID, proxy: proxy, animated: false)
            }
            .onChange(of: activeSegmentID) { _, nextID in
                guard displayMode == .follow, !searchIsActive else {
                    return
                }
                scrollToActiveSegment(nextID, proxy: proxy, animated: true)
            }
            .onChange(of: displayMode) { _, mode in
                guard mode == .follow, !searchIsActive else {
                    return
                }
                scrollToActiveSegment(activeSegmentID, proxy: proxy, animated: true)
            }
            .onChange(of: normalizedSearchText) { _, nextSearchText in
                guard nextSearchText.isEmpty else {
                    scrollToFirstVisibleSegment(visibleSegments, proxy: proxy)
                    return
                }
                scrollToActiveSegment(activeSegmentID, proxy: proxy, animated: true)
            }
        }
    }

    private func subtitleRow(_ segment: SubtitleSegment, isActive: Bool) -> some View {
        Button {
            onSeekToSubtitle(segment.startTime)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(isActive ? theme.accent : Color.clear)
                    .frame(width: 3)
                    .padding(.vertical, 3)

                VStack(alignment: .leading, spacing: 5) {
                    Text(timeRange(segment))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isActive ? theme.accent : theme.mutedText)
                    Text(segment.text)
                        .font(isActive ? .body.weight(.semibold) : .body.weight(.medium))
                        .foregroundStyle(isActive ? theme.primaryText : theme.secondaryText)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(activeRowFill(isActive: isActive))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? theme.cardStroke.opacity(0.88) : Color.clear, lineWidth: 1)
        )
        .buttonStyle(.plain)
        .accessibilityLabel("\(timeRange(segment)) \(segment.text)")
        .accessibilityHint("跳转到这句字幕")
        .transition(.opacity)
    }

    private func scrollToActiveSegment(
        _ id: SubtitleSegment.ID?,
        proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard displayMode == .follow, let id else {
            return
        }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(id, anchor: .center)
            }
        } else {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private var subtitleSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.mutedText)

            TextField("搜索字幕", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.primaryText)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.mutedText)
                .accessibilityLabel("清除字幕搜索")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(theme.subtleFill.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.cardStroke.opacity(0.55), lineWidth: 1)
        )
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func filteredSegments(from segments: [SubtitleSegment]) -> [SubtitleSegment] {
        let query = normalizedSearchText
        guard !query.isEmpty else {
            return segments
        }
        return segments.filter { segment in
            segment.text.localizedCaseInsensitiveContains(query)
                || timeRange(segment).localizedCaseInsensitiveContains(query)
        }
    }

    private func scrollToFirstVisibleSegment(
        _ segments: [SubtitleSegment],
        proxy: ScrollViewProxy
    ) {
        guard let firstID = segments.first?.id else {
            return
        }
        withAnimation(.easeOut(duration: 0.18)) {
            proxy.scrollTo(firstID, anchor: .top)
        }
    }

    private func activeRowFill(isActive: Bool) -> Color {
        guard isActive else {
            return Color.clear
        }
        switch displayMode {
        case .follow:
            return theme.softAccent.opacity(0.72)
        case .all:
            return theme.subtleFill.opacity(0.42)
        }
    }

    private var status: SubtitleStatus {
        recording.subtitle?.status ?? .notStarted
    }

    private var statusTitle: String {
        switch status {
        case .notStarted:
            return "字幕"
        case .recognizing:
            return "正在识别"
        case .ready:
            return "字幕已生成"
        case .failed:
            return "识别失败"
        }
    }

    private var statusIcon: String {
        switch status {
        case .notStarted:
            return "captions.bubble"
        case .recognizing:
            return "waveform.badge.magnifyingglass"
        case .ready:
            return "checkmark.bubble"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .notStarted:
            return theme.primaryText
        case .recognizing:
            return theme.accent
        case .ready:
            return .green.opacity(0.82)
        case .failed:
            return .red.opacity(0.88)
        }
    }

    private var statusMessage: String {
        switch status {
        case .notStarted:
            return "为这段录音生成中文字幕。"
        case .recognizing:
            return recognitionProgress?.detail ?? "正在读取录音并生成中文字幕。"
        case .ready:
            return "没有识别出字幕文本。"
        case .failed:
            return recording.subtitle?.errorMessage ?? "中文语音识别未能完成。"
        }
    }

    private var primaryStatusMessage: String {
        guard status == .recognizing, let recognitionProgress else {
            return statusMessage
        }
        return recognitionProgress.title
    }

    private var secondaryStatusMessage: String? {
        guard status == .recognizing else {
            return nil
        }
        return statusMessage
    }

    private var shouldShowRecognitionAction: Bool {
        status == .notStarted || status == .failed || status == .ready
    }

    private var recognitionActionTitle: String {
        switch status {
        case .notStarted:
            return "生成字幕"
        case .ready:
            return "重新识别"
        case .failed:
            return "重试识别"
        case .recognizing:
            return "正在识别"
        }
    }

    @ViewBuilder
    private var recognitionProgressView: some View {
        NeonLoadingIndicator(progress: recognitionProgress?.fractionCompleted)
    }

    private func timeRange(_ segment: SubtitleSegment) -> String {
        "\(format(segment.startTime)) - \(format(segment.endTime))"
    }

    private func format(_ value: TimeInterval) -> String {
        let totalSeconds = max(0, Int(value.rounded()))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct SubtitleActionButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(Color.white.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
            .foregroundStyle(theme.primaryText)
            .shadow(color: theme.accent.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 18, y: 9)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .overlay(
                GlowPressOverlay(shape: .capsule, isPressed: configuration.isPressed)
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
