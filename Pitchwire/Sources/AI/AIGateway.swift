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
    /// Research Lab only: drafts *how to verify* a candidate — what to check on
    /// their author page, what to search for. Guidance, never evidence.
    case verificationBrief

    /// Default tier for this task. Extraction/classification is cheap; anything
    /// the user reads is quality.
    var defaultTier: ModelTier {
        switch self {
        case .storyAnalysis, .matchExplanation, .verificationBrief: return .fast
        case .pitchDraft, .pitchRewrite, .subjectLine, .followUp: return .quality
        }
    }
}

/// Who is waiting on a call. A person tapping "Draft pitch" must not queue behind
/// a background enrichment sweep — `AIClient` grants the pipeline to `.userInitiated`
/// requests before `.background` ones.
enum RequestOrigin {
    case userInitiated
    case background
}

/// A typed request into the gateway. `input` is structured evidence; `prompt` is
/// the instruction. The backend is free to ignore `prompt` and build its own from
/// `task` + `input` — the app does not assume how generation happens.
struct AIRequest {
    var task: AITask
    var tier: ModelTier
    var input: [String: String]
    var prompt: String
    var origin: RequestOrigin

    init(task: AITask, tier: ModelTier? = nil, input: [String: String] = [:],
         prompt: String, origin: RequestOrigin = .userInitiated) {
        self.task = task
        self.tier = tier ?? task.defaultTier
        self.input = input
        self.prompt = prompt
        self.origin = origin
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
