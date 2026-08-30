import Foundation

/// Talks to the Pitchwire backend gateway — NOT to any provider directly.
/// Unused until `AIConfiguration.baseURL` is set; kept here so wiring a real
/// backend is a config change, not new code.
///
/// Wire contract (backend owns everything past this point):
///   POST {baseURL}/v1/generate
///   Authorization: Bearer {clientToken}     ← scoped per-user token, never a provider key
///   body:  { "task", "tier", "input": {..}, "prompt" }
///   200:   { "text", "model", "cached", "usage": { "inputTokens", "outputTokens" } }
struct HTTPGateway: AIGateway {
    let config: AIConfiguration
    var session: URLSession = HTTPGateway.defaultSession

    /// 25s, not URLSession's default 60s. The backend runs a failover chain with
    /// its own per-model timeout; if nothing has answered in 25s the app should
    /// stop waiting and use its deterministic fallback.
    static let defaultSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 25
        c.timeoutIntervalForResource = 30
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    func run(_ request: AIRequest) async throws -> AIResponse {
        guard let baseURL = config.baseURL, let token = config.clientToken else {
            throw AIGatewayError.notConfigured
        }

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/generate"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(Wire.Request(
            task: request.task.rawValue,
            tier: request.tier.rawValue,
            input: request.input,
            prompt: request.prompt
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AIGatewayError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIGatewayError.server(status: http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(Wire.Response.self, from: data) else {
            throw AIGatewayError.decoding
        }

        return AIResponse(
            text: decoded.text,
            model: decoded.model,
            cached: decoded.cached,
            usage: decoded.usage.map { AIUsage(inputTokens: $0.inputTokens, outputTokens: $0.outputTokens) }
        )
    }

    private enum Wire {
        struct Request: Encodable {
            let task: String
            let tier: String
            let input: [String: String]
            let prompt: String
        }
        struct Response: Decodable {
            let text: String
            let model: String
            let cached: Bool
            let usage: Usage?
            struct Usage: Decodable { let inputTokens: Int; let outputTokens: Int }
        }
    }
}
