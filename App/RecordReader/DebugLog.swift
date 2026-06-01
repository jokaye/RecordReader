import Foundation
import os
import RecordReaderCore
import SwiftUI
import UIKit

/// Lightweight in-app log so import/playback issues can be diagnosed directly
/// on a sideloaded device (no Xcode console required). Also mirrors to
/// os.Logger for Console.app when a Mac is attached.
final class DebugLog: ObservableObject {
    static let shared = DebugLog()

    @Published private(set) var entries: [String] = []

    private let logger = Logger(subsystem: "com.recordreader.app", category: "RecordReader")

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func log(_ message: String) {
        logger.log("\(message, privacy: .public)")
        let line = "[\(Self.timeFormatter.string(from: Date()))] \(message)"
        if Thread.isMainThread {
            append(line)
        } else {
            DispatchQueue.main.async { self.append(line) }
        }
    }

    func clear() {
        if Thread.isMainThread {
            entries.removeAll()
        } else {
            DispatchQueue.main.async { self.entries.removeAll() }
        }
    }

    var text: String {
        entries.joined(separator: "\n")
    }

    private func append(_ line: String) {
        entries.append(line)
        if entries.count > 1000 {
            entries.removeFirst(entries.count - 1000)
        }
    }
}

struct DebugLogView: View {
    @ObservedObject var log = DebugLog.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DebugRecognitionSettingsView()
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .background(Color(uiColor: .systemBackground))

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(log.entries.isEmpty ? "暂无日志。点击导入按钮后再回来查看。" : log.text)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                            .id("logBottom")
                    }
                    .onChange(of: log.entries.count) { _, _ in
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
            .navigationTitle("调试日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("复制") {
                        UIPasteboard.general.string = log.text
                    }
                    Button("清除") {
                        log.clear()
                    }
                }
            }
        }
    }
}

private struct DebugRecognitionSettingsView: View {
    @AppStorage(DebugSettings.recognitionProviderKey) private var recognitionProviderRawValue = RecognitionProvider.defaultValue.rawValue
    @AppStorage(DebugSettings.sherpaThreadCountKey) private var sherpaThreadCountRawValue = SherpaThreadCount.defaultValue.rawValue
    @AppStorage(DebugSettings.transcriptionWindowDurationKey) private var transcriptionWindowDurationRawValue = TranscriptionWindowDuration.defaultValue.rawValue
    @AppStorage(DebugSettings.transcriptionWorkerCountKey) private var transcriptionWorkerCountRawValue = TranscriptionWorkerCount.defaultValue.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            providerControl
            threadCountControl
            workerCountControl
            windowDurationControl
        }
        .onChange(of: recognitionProviderRawValue) { _, newValue in
            let provider = RecognitionProvider(rawValueOrDefault: newValue)
            if provider.rawValue != newValue {
                recognitionProviderRawValue = provider.rawValue
            }
            DebugSettings.recognitionProvider = provider
            DebugLog.shared.log("本地识别后端设置为 \(provider.logLabel)，下次识别生效")
        }
        .onChange(of: sherpaThreadCountRawValue) { _, newValue in
            let threadCount = SherpaThreadCount(rawValueOrDefault: newValue)
            if threadCount.rawValue != newValue {
                sherpaThreadCountRawValue = threadCount.rawValue
            }
            DebugSettings.sherpaThreadCount = threadCount
            DebugLog.shared.log("本地识别线程数设置为 \(threadCount.label)，下次识别生效")
        }
        .onChange(of: transcriptionWindowDurationRawValue) { _, newValue in
            let duration = TranscriptionWindowDuration(rawValueOrDefault: newValue)
            if duration.rawValue != newValue {
                transcriptionWindowDurationRawValue = duration.rawValue
            }
            DebugSettings.transcriptionWindowDuration = duration
            DebugLog.shared.log("长音频识别窗口设置为 \(duration.rawValue) 秒，下次识别生效")
        }
        .onChange(of: transcriptionWorkerCountRawValue) { _, newValue in
            let workerCount = TranscriptionWorkerCount(rawValueOrDefault: newValue)
            if workerCount.rawValue != newValue {
                transcriptionWorkerCountRawValue = workerCount.rawValue
            }
            DebugSettings.transcriptionWorkerCount = workerCount
            DebugLog.shared.log("长音频并行识别设置为 \(workerCount.label)，下次识别生效")
        }
    }

    private var providerControl: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("本地识别后端", systemImage: "switch.2")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("本地识别后端", selection: $recognitionProviderRawValue) {
                    ForEach(RecognitionProvider.selectableCases) { provider in
                        Text(provider.logLabel).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("CoreML 对当前内置 int8 中文模型不可用，已保留为后续兼容模型实验。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var threadCountControl: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("本地识别线程数", systemImage: "cpu")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("本地识别线程数", selection: $sherpaThreadCountRawValue) {
                    ForEach(SherpaThreadCount.allCases) { threadCount in
                        Text(threadCount.label).tag(threadCount.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("用于真机性能测试，改动后下次识别生效。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var windowDurationControl: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("长音频窗口长度", systemImage: "waveform.path")
                .font(.subheadline.weight(.semibold))

            Picker("长音频窗口长度", selection: $transcriptionWindowDurationRawValue) {
                ForEach(TranscriptionWindowDuration.allCases) { duration in
                    Text(duration.label).tag(duration.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Text("窗口越长开销越少，但字幕时间范围会更粗。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var workerCountControl: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("长音频并行数", systemImage: "square.stack.3d.up")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("长音频并行数", selection: $transcriptionWorkerCountRawValue) {
                    ForEach(TranscriptionWorkerCount.allCases) { workerCount in
                        Text(workerCount.label).tag(workerCount.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("并行窗口会增加内存占用；Auto 当前按 2 路并行测试。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
