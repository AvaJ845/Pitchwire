import Foundation

/// Which class of model a task needs. Cheap/fast for extraction and tagging,
/// stronger for user-visible prose. The app picks the tier; the backend router
/// picks the actual provider (GLM-5.3-Flash default, quality-tier fallback).
enum ModelTier: String, Codable {
    case fast
    case quality
}

/// The single seam every LLM call goes through.
///
/// Per the AI Infrastructure Direction, this is non-negotiable from day one:
/// - The app never holds a provider API key. A real `AIProvider` talks to the
///   Pitchwire backend with a scoped client token; the backend vault holds the
///   real credentials and routes to GLM-5.3-Flash (or a fallback).
/// - The model interprets and drafts language only. Journalist identity, coverage,
///   dates, and provenance are authoritative structured data, never model output.
///
/// Only `OfflineAIProvider` ships today, so every caller must degrade gracefully
/// to a deterministic result when `generate` throws.
protocol AIProvider {
    func generate(prompt: String, tier: ModelTier) async throws -> String
}

enum AIProviderError: Error {
    /// No backend configured — the app is running fully offline.
    case notConfigured
}

/// The default until a backend exists. Always throws; callers fall back to templates.
struct OfflineAIProvider: AIProvider {
    func generate(prompt: String, tier: ModelTier) async throws -> String {
        throw AIProviderError.notConfigured
    }
}
