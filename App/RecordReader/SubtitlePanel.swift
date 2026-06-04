import RecordReaderCore
import SwiftUI

struct SubtitlePanel: View {
    let recording: Recording
    let currentTime: TimeInterval
    @Binding var displayMode: SubtitleDisplayMode
    let errorMessage: String?
    let recognitionProgress: SubtitleRecognitionProgress?
    let onRecognize: () -> Void
    @Environment(\.appTheme) private var theme

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
                Picker("字幕显示", selection: $displayMode) {
                    ForEach(SubtitleDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

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

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(segments) { segment in
                        subtitleRow(segment, isActive: segment.id == activeSegmentID)
                            .id(segment.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                scrollToActiveSegment(activeSegmentID, proxy: proxy, animated: false)
            }
            .onChange(of: activeSegmentID) { _, nextID in
                guard displayMode == .follow else {
                    return
                }
                scrollToActiveSegment(nextID, proxy: proxy, animated: true)
            }
            .onChange(of: displayMode) { _, mode in
                guard mode == .follow else {
                    return
                }
                scrollToActiveSegment(activeSegmentID, proxy: proxy, animated: true)
            }
        }
    }

    private func subtitleRow(_ segment: SubtitleSegment, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(timeRange(segment))
                .font(.caption.monospacedDigit())
                .foregroundStyle(isActive ? theme.secondaryText : theme.mutedText)
            Text(segment.text)
                .font(isActive ? .body.weight(.semibold) : .body.weight(.medium))
                .foregroundStyle(isActive ? theme.primaryText : theme.secondaryText)
                .lineSpacing(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive && displayMode == .follow ? theme.subtleFill : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive && displayMode == .follow ? theme.cardStroke : Color.clear, lineWidth: 1)
        )
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
        if let fraction = recognitionProgress?.fractionCompleted {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(theme.accent)
                .frame(maxWidth: 220)
                .controlSize(.small)
        } else {
            ProgressView()
                .tint(theme.accent)
                .scaleEffect(1.08)
        }
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
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
