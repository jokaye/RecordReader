import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Drives a native `UIDocumentPickerViewController`.
///
/// SwiftUI's `.fileImporter` repeatedly failed to deliver a result on this
/// project ("点击打开没有反应"), so import is handled through UIKit directly,
/// which reliably calls its delegate after the user taps "打开".
struct DocumentPickerPresenter: UIViewControllerRepresentable {
    @Binding var mode: ImportMode?
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator.hostController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.presentIfNeeded(for: mode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
        var parent: DocumentPickerPresenter
        let hostController = UIViewController()
        private var isPresenting = false

        init(_ parent: DocumentPickerPresenter) {
            self.parent = parent
        }

        func presentIfNeeded(for mode: ImportMode?) {
            guard let mode, !isPresenting else {
                return
            }

            isPresenting = true
            DebugLog.shared.log("准备弹出文件选择器：\(mode)")
            present(mode: mode, attempt: 0)
        }

        private func present(mode: ImportMode, attempt: Int) {
            guard let presenter = Self.topViewController(),
                  presenter.presentedViewController == nil else {
                // The hosting view controller may not be in the window yet on the
                // first layout pass; retry briefly instead of silently no-oping.
                guard attempt < 10 else {
                    DebugLog.shared.log("找不到可用的顶层控制器，放弃弹出选择器")
                    isPresenting = false
                    parent.mode = nil
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.present(mode: mode, attempt: attempt + 1)
                }
                return
            }

            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: mode.allowedContentTypes,
                asCopy: false
            )
            picker.allowsMultipleSelection = mode.allowsMultipleSelection
            picker.shouldShowFileExtensions = true
            picker.delegate = self
            picker.presentationController?.delegate = self
            DebugLog.shared.log("从 \(type(of: presenter)) 弹出选择器（尝试 \(attempt)）")
            presenter.present(picker, animated: true) {
                DebugLog.shared.log("选择器已显示")
            }
        }

        private static func topViewController() -> UIViewController? {
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let keyWindow = windowScene?.windows.first { $0.isKeyWindow }
                ?? windowScene?.windows.first
            var top = keyWindow?.rootViewController
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            DebugLog.shared.log("代理回调 didPickDocumentsAt：\(urls.count) 个 URL")
            for url in urls {
                DebugLog.shared.log("  选中：\(url.lastPathComponent)")
            }
            finish(delivering: urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DebugLog.shared.log("代理回调 documentPickerWasCancelled（用户取消）")
            finish(delivering: nil)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            DebugLog.shared.log("选择器被下滑关闭")
            finish(delivering: nil)
        }

        private func finish(delivering urls: [URL]?) {
            guard isPresenting else {
                DebugLog.shared.log("finish 被重复调用，已忽略")
                return
            }
            isPresenting = false
            if let urls, !urls.isEmpty {
                DebugLog.shared.log("向 App 交付 \(urls.count) 个 URL")
                parent.onPick(urls)
            } else {
                DebugLog.shared.log("没有可交付的 URL")
            }
            parent.mode = nil
        }
    }
}
