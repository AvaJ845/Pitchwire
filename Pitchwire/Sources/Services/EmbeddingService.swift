import Foundation
import CoreML
import Accelerate

/// A unit-length semantic vector for a short piece of text, or nil when no model
/// is available. The relevance engine treats a nil provider as "offline" and
/// falls back to word-overlap scoring. `Float` — the model's native precision,
/// and half the storage when cached on `JournalistProfile.embedding`.
///
/// `Sendable` so the (CPU-bound) embedding pass can run off the main actor — see
/// `MatchRunner.warmDirectory`.
protocol EmbeddingProvider: Sendable {
    func vector(for text: String) -> [Float]?
}

/// The default provider: the bundled all-MiniLM-L6-v2 sentence-transformer,
/// **on-device** (CoreML) — the user's unpublished story is embedded locally and
/// never leaves the phone. `nil` only if the bundled model can't load, in which
/// case the relevance engine falls back to word-overlap scoring.
///
/// One instance for the whole app: loading the 16 MB model and parsing the
/// 30 k-line vocab is not something to redo per match run.
enum DefaultEmbeddingProvider {
    static let shared: EmbeddingProvider? = {
        #if DEBUG
        // UI tests don't assert on semantic-specific ranking, and a thrashing CI
        // runner can take 20 s to load the model + warm the pool — skip it and
        // let the engine fall back to word overlap.
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") { return nil }
        #endif
        return MiniLMEmbeddingProvider()
    }()
}

/// all-MiniLM-L6-v2, 384-dim, mean-pooled + L2-normalized in the CoreML graph.
/// 6-bit palettized (~16 MB). Bundled `MiniLM.mlpackage` + `minilm-vocab.txt`.
///
/// `@unchecked Sendable`: both stored properties are immutable, `BertTokenizer`
/// is a value type, and `MLModel.prediction(from:)` is documented thread-safe.
final class MiniLMEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
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

    func vector(for text: String) -> [Float]? {
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

        var result = [Float](repeating: 0, count: vec.count)
        for i in 0..<vec.count { result[i] = vec[i].floatValue }
        return Embedding.normalize(result)
    }
}

enum Embedding {
    /// Cosine of two unit vectors, **rescaled** for the bundled MiniLM: related
    /// same-vertical text lands ~0.30–0.50, cross-vertical ~0.10–0.20, so map
    /// [0.22, 0.55] → [0, 1] and clamp. (A different model needs different bounds.)
    static func similarity(_ a: [Float], _ b: [Float]) -> Double {
        max(0, min(1, (Double(rawCosine(a, b)) - 0.22) / 0.33))
    }

    static func rawCosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        return vDSP.dot(a, b)
    }

    static func normalize(_ v: [Float]) -> [Float] {
        guard !v.isEmpty else { return v }
        let mag = vDSP.dot(v, v).squareRoot()
        return mag > 0 ? vDSP.multiply(1 / mag, v) : v
    }

    /// The text embedded for a story — the *distilled* fields only. The raw
    /// press release is mostly boilerplate the analysis step already stripped;
    /// including it just dilutes the vector against the tight journalist side
    /// (beat + real article titles).
    static func storyText(_ a: StoryAnalysisResult) -> String {
        ([a.theme, a.summary] + a.subtopics + a.mediaHooks)
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
