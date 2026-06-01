import RecordReaderCore
import SwiftUI

struct SubtitlePanel: View {
    let recording: Recording
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(subtitle.segments) { segment in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(timeRange(segment))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(segment.text)
                                    .font(.body.weight(.medium))
                                    .lineSpacing(4)
                            }
                            .padding(.vertical, 2)
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
