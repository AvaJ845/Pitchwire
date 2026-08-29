import Foundation

/// Which class of model a task needs. Cheap/fast for extraction and tagging,
/// stronger for user-visible prose. The app picks the tier per task; the backend
/// router picks the actual provider (GLM-5.3-Flash default, quality-tier fallback).
enum ModelTier: String, Codable {
    case fast
    case quality
}

/// Every LLM call is one of a fixed set of tasks — never a free-form prompt from
/// a random call site. The backend can route, cache, price, and observe per task.
enum AITask: String, Codable, CaseIterable {
    case storyAnalysis
    case matchExplanation
    case pitchDraft
    case pitchRewrite
    case subjectLine
    case followUp

    /// Default tier for this task. Extraction/classification is cheap; anything
    /// the user reads is quality.
    var defaultTier: ModelTier {
        switch self {
        case .storyAnalysis, .matchExplanation: return .fast
        case .pitchDraft, .pitchRewrite, .subjectLine, .followUp: return .quality
        }
    }
}

/// A typed request into the gateway. `input` is structured evidence; `prompt` is
/// the instruction. The backend is free to ignore `prompt` and build its own from
/// `task` + `input` — the app does not assume how generation happens.
struct AIRequest {
    var task: AITask
    var tier: ModelTier
    var input: [String: String]
    var prompt: String

    init(task: AITask, tier: ModelTier? = nil, input: [String: String] = [:], prompt: String) {
        self.task = task
        self.tier = tier ?? task.defaultTier
        self.input = input
        self.prompt = prompt
    }
}

struct AIUsage: Codable, Hashable {
    var inputTokens: Int
    var outputTokens: Int
}

struct AIResponse {
    var text: String
    var model: String
    var cached: Bool
    var usage: AIUsage?
}

enum AIGatewayError: Error {
    /// No backend configured — the app is running fully offline.
    case notConfigured
    case transport(Error)
    case server(status: Int)
    case decoding
}

/// The boundary between the app and every AI provider. Only implementations in
/// this folder ever exist; a caller receives an `AIClient`, never a gateway.
protocol AIGateway {
    func run(_ request: AIRequest) async throws -> AIResponse
}
