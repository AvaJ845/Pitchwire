import Foundation

/// The default until a backend exists. Always throws; callers fall back to
/// deterministic templates, so the whole product works with zero configuration.
struct OfflineGateway: AIGateway {
    func run(_ request: AIRequest) async throws -> AIResponse {
        throw AIGatewayError.notConfigured
    }
}
