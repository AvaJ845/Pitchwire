import Foundation

/// A one-slot handoff from the Share Extension to the app. The extension stashes
/// the shared text; the app takes it on next activation and pre-fills Home.
/// Backed by the App Group so both processes see it; falls back to standard
/// defaults if the group isn't provisioned (dev / no entitlement).
enum SharedInbox {
    static let appGroup = "group.com.avaresearch.pitchwire"
    private static let key = "pitchwire.sharedStory"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Called from the Share Extension. Trims and caps the text.
    static func stash(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaults.set(String(trimmed.prefix(8_000)), forKey: key)
    }

    /// Called from the app. Returns the pending story once, then clears it.
    static func take() -> String? {
        guard let text = defaults.string(forKey: key), !text.isEmpty else { return nil }
        defaults.removeObject(forKey: key)
        return text
    }

    static var hasPending: Bool { (defaults.string(forKey: key)?.isEmpty == false) }
}
