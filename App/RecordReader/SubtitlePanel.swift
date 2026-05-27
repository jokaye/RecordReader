import RecordReaderCore
import SwiftUI

struct SubtitlePanel: View {
    let recording: Recording
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(statusTitle, systemImage: statusIcon)
                    .font(.headline.weight(.semibold))
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
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Spacer()
                Text(statusMessage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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

    private var statusMessage: String {
        switch status {
        case .notStarted:
            return "点击更多操作，为这段录音识别中文字幕。"
        case .recognizing:
            return "正在读取录音并生成中文字幕。"
        case .ready:
            return "没有识别出字幕文本。"
        case .failed:
            return recording.subtitle?.errorMessage ?? "中文语音识别未能完成。"
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
