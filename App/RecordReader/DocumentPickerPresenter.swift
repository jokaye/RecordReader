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
            present(mode: mode, attempt: 0)
        }

        private func present(mode: ImportMode, attempt: Int) {
            guard let presenter = Self.topViewController(),
                  presenter.presentedViewController == nil else {
                // The hosting view controller may not be in the window yet on the
                // first layout pass; retry briefly instead of silently no-oping.
                guard attempt < 10 else {
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
            presenter.present(picker, animated: true)
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
            finish(delivering: urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish(delivering: nil)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            finish(delivering: nil)
        }

        private func finish(delivering urls: [URL]?) {
            guard isPresenting else {
                return
            }
            isPresenting = false
            if let urls, !urls.isEmpty {
                parent.onPick(urls)
            }
            parent.mode = nil
        }
    }
}
