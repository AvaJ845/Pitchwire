import Foundation
import CoreML
import NaturalLanguage

/// A unit-length semantic vector for a short piece of text, or nil when no model
/// is available. The relevance engine treats a nil provider as "offline" and
/// falls back to word-overlap scoring.
protocol EmbeddingProvider {
    func vector(for text: String) -> [Double]?
}

/// The default provider: the bundled all-MiniLM-L6-v2 sentence-transformer,
/// **on-device** (CoreML) — the user's unpublished story is embedded locally and
/// never leaves the phone. Returns nil only if the bundled model can't load, in
/// which case the relevance engine falls back to word-overlap scoring.
enum DefaultEmbeddingProvider {
    static func make() -> EmbeddingProvider? { MiniLMEmbeddingProvider() }
}

/// all-MiniLM-L6-v2, 384-dim, mean-pooled + L2-normalized in the CoreML graph.
/// 6-bit palettized (~16 MB). Bundled `MiniLM.mlpackage` + `minilm-vocab.txt`.
final class MiniLMEmbeddingProvider: EmbeddingProvider {
    static let dimension = 384
    private static let sequenceLength = 64

    private let model: MLModel
    private let tokenizer: BertTokenizer

    init?(bundle: Bundle = .main) {
        // CPU only: the GPU/ANE path returns an all-zero vector for this graph on
        // the iOS simulator (and is a silent-failure risk on-device). The workload
        // is tiny — ~20 short-text embeddings per match run, then cached — so the
        // CPU path costs a few ms and is the safe choice.
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuOnly
        guard let modelURL = bundle.url(forResource: "MiniLM", withExtension: "mlmodelc"),
              let m = try? MLModel(contentsOf: modelURL, configuration: cfg),
              let vocabURL = bundle.url(forResource: "minilm-vocab", withExtension: "txt"),
              let t = BertTokenizer(vocabURL: vocabURL)
        else { return nil }
        model = m
        tokenizer = t
    }

    func vector(for text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let n = Self.sequenceLength
        let (ids, mask) = tokenizer.encode(trimmed, maxLen: n)
        guard let idsArray = try? MLMultiArray(shape: [1, NSNumber(value: n)], dataType: .int32),
              let maskArray = try? MLMultiArray(shape: [1, NSNumber(value: n)], dataType: .int32)
        else { return nil }
        // Write through the raw int32 buffer — the NSNumber subscript setter is
        // unreliable for .int32 arrays (silently leaves them zeroed).
        let idsPtr = idsArray.dataPointer.bindMemory(to: Int32.self, capacity: n)
        let maskPtr = maskArray.dataPointer.bindMemory(to: Int32.self, capacity: n)
        for i in 0..<n {
            idsPtr[i] = ids[i]
            maskPtr[i] = mask[i]
        }

        let input = try? MLDictionaryFeatureProvider(dictionary: [
            "input_ids": idsArray, "attention_mask": maskArray,
        ])
        guard let input,
              let out = try? model.prediction(from: input),
              let vec = out.featureValue(for: "embedding")?.multiArrayValue
        else { return nil }

        var result = [Double](repeating: 0, count: vec.count)
        for i in 0..<vec.count { result[i] = vec[i].doubleValue }
        return Embedding.normalize(result)
    }
}

/// Apple's on-device sentence embedding — the fallback. Weaker than MiniLM
/// (reads most tech text as ~0.6 similar) but zero bundle cost and no download.
struct NLEmbeddingProvider: EmbeddingProvider {
    private let model = NLEmbedding.sentenceEmbedding(for: .english)
    var isAvailable: Bool { model != nil }

    func vector(for text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let raw = model?.vector(for: trimmed) else { return nil }
        return Embedding.normalize(raw)
    }
}

enum Embedding {
    /// Cosine of two unit vectors, **rescaled** for the bundled MiniLM: related
    /// same-vertical text lands ~0.30–0.50, cross-vertical ~0.10–0.20, so map
    /// [0.22, 0.55] → [0, 1] and clamp. (A different model needs different bounds.)
    static func similarity(_ a: [Double], _ b: [Double]) -> Double {
        max(0, min(1, (rawCosine(a, b) - 0.22) / 0.33))
    }

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
        ([a.theme, a.summary] + a.subtopics + a.mediaHooks + [String(rawText.prefix(600))])
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
