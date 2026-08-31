import Foundation

/// Everything the app needs to reach AI — and nothing it must not hold.
///
/// The app NEVER carries a provider API key. `clientToken` is a short-lived,
/// per-user, scoped token issued by the Pitchwire backend; the backend vault
/// holds the real GLM / OpenAI / Anthropic credentials and does the routing.
///
/// `baseURL == nil` means "no backend yet" → the app runs on `OfflineGateway`
/// and every feature falls back to a deterministic result.
struct AIConfiguration {
    var baseURL: URL?
    var clientToken: String?

    // No model field on purpose. The app declares AITask + ModelTier; the backend
    // owns the task→model map and the failover chain (MVP: free GLM-4.7/4.5-Flash;
    // GLM-5.3-Flash paid, routed per-task server-side later). Which model answered
    // a call is only knowable from AIResponse.model. See docs/DIRECTION.md.
    static let offline = AIConfiguration(baseURL: nil, clientToken: nil)

    var isConfigured: Bool {
        guard let baseURL, let clientToken else { return false }
        return !clientToken.isEmpty && !baseURL.absoluteString.isEmpty
    }

    /// Reads `Config/AIConfig.plist` from the bundle (gitignored — see
    /// `AIConfig.example.plist`). Absent or blank → `.offline`.
    static func fromBundle(_ bundle: Bundle = .main) -> AIConfiguration {
        guard
            let url = bundle.url(forResource: "AIConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return .offline
        }
        return from(dict: dict)
    }

    /// Pure mapping from a plist dict — testable without a bundle.
    static func from(dict: [String: Any]) -> AIConfiguration {
        guard
            let base = (dict["BaseURL"] as? String).flatMap(URL.init(string:)),
            !base.absoluteString.isEmpty,
            let token = dict["ClientToken"] as? String, !token.isEmpty
        else {
            return .offline
        }
        return AIConfiguration(baseURL: base, clientToken: token)
    }
}
