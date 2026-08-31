import Foundation
import NaturalLanguage

/// A unit-length semantic vector for a short piece of text, or nil when no model
/// is available. The relevance engine treats a nil provider as "offline" and
/// falls back to word-overlap scoring.
protocol EmbeddingProvider {
    func vector(for text: String) -> [Double]?
}

/// Apple's on-device sentence embedding (`NLEmbedding`). **No network, no asset
/// download** — the user's unpublished story text is embedded locally and never
/// leaves the device for matching. iOS 16+.
struct NLEmbeddingProvider: EmbeddingProvider {
    private let model = NLEmbedding.sentenceEmbedding(for: .english)

    /// `true` when the on-device model actually loaded.
    var isAvailable: Bool { model != nil }

    func vector(for text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let raw = model?.vector(for: trimmed) else { return nil }
        return Embedding.normalize(raw)
    }
}

enum Embedding {
    /// Cosine similarity of two unit vectors, **rescaled** to spread the useful
    /// range. `NLEmbedding` compresses unrelated tech text to ~0.5–0.65 and only
    /// truly-close pairs exceed ~0.75, so raw cosine is nearly useless as a
    /// signal. Map [0.55, 0.82] → [0, 1] and clamp.
    static func similarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
        return max(0, min(1, (dot - 0.55) / 0.27))
    }

    /// The raw cosine, for diagnostics / tests.
    static func rawCosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        return zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
    }

    static func normalize(_ v: [Double]) -> [Double] {
        let mag = (v.reduce(0.0) { $0 + $1 * $1 }).squareRoot()
        return mag > 0 ? v.map { $0 / mag } : v
    }

    /// The text embedded for a story — concise, so the vector reflects the topic
    /// rather than the boilerplate.
    static func storyText(_ a: StoryAnalysisResult, rawText: String) -> String {
        ([a.theme, a.summary] + a.subtopics + a.mediaHooks
            + [String(rawText.prefix(600))])
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}

extension JournalistProfile {
    /// The text embedded for a journalist — their beat plus what they've actually
    /// written, so similarity is against real coverage, not a keyword list.
    var embeddingText: String {
        ([role].compactMap { $0 } + beatTopics + allCoverage.prefix(6).map(\.title))
            .joined(separator: ". ")
    }
}
