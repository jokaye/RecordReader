import Foundation
import os
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
