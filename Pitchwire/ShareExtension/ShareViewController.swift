import UIKit
import UniformTypeIdentifiers
import Social

/// Minimal share target: pull the shared text or URL, stash it for the app,
/// tell the user to open Pitchwire. No UI to fill in — the story goes straight
/// to Home. (Opening the host app from an extension is restricted by iOS, so
/// the app picks it up on next activation instead.)
final class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool { true }

    override func presentationAnimationDidFinish() {
        extractSharedText { [weak self] text in
            guard let self else { return }
            if let text, !text.isEmpty {
                SharedInbox.stash(text)
            }
            DispatchQueue.main.async {
                self.textView.text = text ?? ""
                self.placeholder = "Shared to Pitchwire — open the app to analyse it"
                self.validateContent()
            }
        }
    }

    override func didSelectPost() {
        // The value was already stashed in presentationAnimationDidFinish;
        // also stash whatever the user left in the text box.
        SharedInbox.stash(contentText ?? "")
        extensionContext?.completeRequest(returningItems: nil)
    }

    override func configurationItems() -> [Any]! { [] }

    // MARK: - Extraction

    private func extractSharedText(_ completion: @escaping (String?) -> Void) {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let attachments = items.flatMap { $0.attachments ?? [] }

        // Prefer plain text; fall back to a URL.
        if let textItem = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            textItem.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { value, _ in
                completion((value as? String) ?? (value as? NSAttributedString)?.string)
            }
            return
        }
        if let urlItem = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            urlItem.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
                completion((value as? URL)?.absoluteString)
            }
            return
        }
        // Some hosts pass the URL as text under a generic type.
        if let anyText = items.compactMap({ $0.attributedContentText?.string }).first {
            completion(anyText); return
        }
        completion(nil)
    }
}
