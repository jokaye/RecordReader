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
            guard let mode else {
                return
            }
            guard !isPresenting, hostController.presentedViewController == nil else {
                return
            }
            guard hostController.viewIfLoaded?.window != nil else {
                return
            }

            isPresenting = true
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: mode.allowedContentTypes,
                asCopy: false
            )
            picker.allowsMultipleSelection = mode.allowsMultipleSelection
            picker.shouldShowFileExtensions = true
            picker.delegate = self
            picker.presentationController?.delegate = self
            hostController.present(picker, animated: true)
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
