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

    var isConfigured: Bool { baseURL != nil && clientToken != nil }
}
