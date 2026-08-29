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
    /// Advisory only — the backend router has the final say.
    var defaultModel: String

    static let offline = AIConfiguration(baseURL: nil, clientToken: nil, defaultModel: "glm-5.3-flash")

    var isConfigured: Bool { baseURL != nil && clientToken != nil }
}
