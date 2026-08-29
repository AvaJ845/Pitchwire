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

    // Advisory only — the backend task→model map is the real router. MVP starts on
    // the free tier (GLM-4.7-Flash / 4.5-Flash); a paid model (GLM-5.3-Flash) is
    // routed per-task server-side later, no app change. See docs/DIRECTION.md.
    static let offline = AIConfiguration(baseURL: nil, clientToken: nil, defaultModel: "glm-4.7-flash")

    var isConfigured: Bool { baseURL != nil && clientToken != nil }
}
