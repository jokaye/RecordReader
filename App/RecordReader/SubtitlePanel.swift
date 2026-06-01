import RecordReaderCore
import SwiftUI

struct SubtitlePanel: View {
    let recording: Recording
    let currentTime: TimeInterval
    @Binding var displayMode: SubtitleDisplayMode
    let errorMessage: String?
    let recognitionProgress: SubtitleRecognitionProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(statusTitle, systemImage: statusIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusColor)
                Spacer()
                Text(recording.fileExtension.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.58))
            }

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
                VStack(spacing: 12) {
                    if status == .recognizing {
                        recognitionProgressView
                    }
                    Text(primaryStatusMessage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let secondaryStatusMessage {
                        Text(secondaryStatusMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.56))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
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
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusColor.opacity(status == .failed ? 0.34 : 0.12), lineWidth: 1)
        )
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
                .foregroundStyle(isActive ? .white.opacity(0.76) : .white.opacity(0.5))
            Text(segment.text)
                .font(isActive ? .body.weight(.semibold) : .body.weight(.medium))
                .foregroundStyle(isActive ? .white : .white.opacity(0.78))
                .lineSpacing(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive && displayMode == .follow ? Color.white.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive && displayMode == .follow ? Color.white.opacity(0.22) : Color.clear, lineWidth: 1)
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
            return .white.opacity(0.82)
        case .recognizing:
            return .white.opacity(0.9)
        case .ready:
            return .green.opacity(0.82)
        case .failed:
            return .red.opacity(0.88)
        }
    }

    private var statusMessage: String {
        switch status {
        case .notStarted:
            return "点击更多操作，为这段录音识别中文字幕。"
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

    @ViewBuilder
    private var recognitionProgressView: some View {
        if let fraction = recognitionProgress?.fractionCompleted {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(.white.opacity(0.86))
                .frame(maxWidth: 220)
                .controlSize(.small)
        } else {
            ProgressView()
                .tint(.white)
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
