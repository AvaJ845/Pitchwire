import Foundation

/// A direct client for any OpenAI-compatible `/chat/completions` endpoint —
/// z.ai (`https://api.z.ai/api/paas/v4`) and NVIDIA NIM
/// (`https://integrate.api.nvidia.com/v1`) both speak this.
///
/// IMPORTANT: this holds a real provider key. It is for the **backend** (which
/// composes GLM + NVIDIA behind `FallbackGateway`) or a keyed dev / self-hosted
/// build ONLY. Never ship a build that constructs this with a real key — the app
/// store path is always `HTTPGateway` → our backend.
struct OpenAICompatibleGateway: AIGateway {
    var baseURL: URL
    var apiKey: String
    var model: String
    var session: URLSession = .shared

    /// z.ai — MVP default. Free: `glm-4.7-flash`, `glm-4.5-flash`. Paid: `glm-5.3-flash`.
    static func zai(apiKey: String, model: String = "glm-4.7-flash") -> OpenAICompatibleGateway {
        OpenAICompatibleGateway(
            baseURL: URL(string: "https://api.z.ai/api/paas/v4")!,
            apiKey: apiKey,
            model: model
        )
    }

    /// NVIDIA API Catalog / NIM — free tier (~40 rpm, ~1000 starter credits).
    /// Used as the last failover step. Verify the free tier permits commercial
    /// use before shipping this in the backend.
    static func nvidiaNIM(apiKey: String, model: String = "meta/llama-3.3-70b-instruct") -> OpenAICompatibleGateway {
        OpenAICompatibleGateway(
            baseURL: URL(string: "https://integrate.api.nvidia.com/v1")!,
            apiKey: apiKey,
            model: model
        )
    }

    func run(_ request: AIRequest) async throws -> AIResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(Wire.Request(
            model: model,
            messages: [
                .init(role: "system", content: Self.systemPrompt(for: request.task)),
                .init(role: "user", content: Self.userContent(for: request))
            ],
            temperature: request.tier == .fast ? 0.2 : 0.6
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AIGatewayError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIGatewayError.server(status: http.statusCode)   // 429 → FallbackGateway moves on
        }
        guard let decoded = try? JSONDecoder().decode(Wire.Response.self, from: data),
              let text = decoded.choices.first?.message.content else {
            throw AIGatewayError.decoding
        }
        return AIResponse(
            text: text,
            model: decoded.model ?? model,
            cached: false,
            usage: decoded.usage.map { AIUsage(inputTokens: $0.prompt_tokens, outputTokens: $0.completion_tokens) }
        )
    }

    private static func systemPrompt(for task: AITask) -> String {
        switch task {
        case .storyAnalysis:
            return "You extract structured fields from a press story. Reply with JSON only, matching the requested schema."
        case .matchExplanation:
            return "You write one plain sentence explaining why a journalist fits a story, using only the facts given."
        case .pitchDraft, .pitchRewrite:
            return "You write concise, respectful media pitches grounded only in the facts given. No hype, no invented details."
        case .subjectLine:
            return "You write short, specific email subject lines. One per line."
        case .followUp:
            return "You write a brief, polite follow-up email."
        case .verificationBrief:
            return "You suggest how a researcher should verify a candidate — checks and searches. You have no web access and conclude nothing."
        }
    }

    private static func userContent(for request: AIRequest) -> String {
        let facts = request.input.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        return facts.isEmpty ? request.prompt : "\(request.prompt)\n\n\(facts)"
    }

    private enum Wire {
        struct Request: Encodable {
            let model: String
            let messages: [Message]
            let temperature: Double
            struct Message: Encodable { let role: String; let content: String }
        }
        struct Response: Decodable {
            let model: String?
            let choices: [Choice]
            let usage: Usage?
            struct Choice: Decodable { let message: Message }
            struct Message: Decodable { let content: String }
            struct Usage: Decodable { let prompt_tokens: Int; let completion_tokens: Int }
        }
    }
}
