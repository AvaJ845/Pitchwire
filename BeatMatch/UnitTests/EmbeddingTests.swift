import XCTest
@testable import Pitchwire

final class EmbeddingTests: XCTestCase {

    func testSimilarityRescaleSpreadsTheUsefulRange() {
        // Identical unit vectors → rescaled to 1.0.
        let v = Embedding.normalize([0.3, 0.4, 0.5, 0.1])
        XCTAssertEqual(Embedding.similarity(v, v), 1.0, accuracy: 0.001)

        // MiniLM: cross-vertical text lands ~0.15–0.20 raw → near-zero signal;
        // a strong same-vertical match ~0.5 → near-full.
        XCTAssertLessThan(cosineToSignal(0.18), 0.05)
        XCTAssertGreaterThan(cosineToSignal(0.50), 0.8)
        XCTAssertEqual(cosineToSignal(0.10), 0.0, "below the floor → no signal")
    }

    func testEngineFallsBackToWordOverlapWhenSimilarityIsNil() {
        let a = StoryAnalysisResult(theme: "AI", vertical: "ai", region: "US", angle: "product launch",
                                    urgency: "standard", summary: "", audience: "Developers",
                                    subtopics: ["ai", "developer tools"], mediaHooks: [])
        let j = JournalistProfile(name: "J", beatTopics: ["ai", "developer tools"],
                                  outlet: Outlet(name: "O"))
        let offline = RelevanceEngine.score(analysis: a, journalist: j, similarity: nil)
        XCTAssertGreaterThan(offline.total, 0, "no model → still scores on word overlap + other signals")
    }

    func testSimilarityNeverLowersAWordOverlapMatch() {
        let a = StoryAnalysisResult(theme: "AI", vertical: "ai", region: "US", angle: "product launch",
                                    urgency: "standard", summary: "", audience: "Developers",
                                    subtopics: ["ai", "llm"], mediaHooks: [])
        let j = JournalistProfile(name: "J", beatTopics: ["ai", "llm"], outlet: Outlet(name: "O"))
        let word = RelevanceEngine.score(analysis: a, journalist: j, similarity: nil).total
        let weak = RelevanceEngine.score(analysis: a, journalist: j, similarity: 0.1).total
        // topicScore = max(wordScore, similarity) → a weak similarity can't drag
        // an exact beat match down.
        XCTAssertEqual(word, weak, accuracy: 0.001)
    }

    func testSimilarityLiftsAnUnderTaggedProfile() {
        // Beat list misses the word the story uses, but semantically it's a match.
        let a = StoryAnalysisResult(theme: "AI", vertical: "ai", region: "US", angle: "product launch",
                                    urgency: "standard", summary: "", audience: "Developers",
                                    subtopics: ["language models"], mediaHooks: [])
        let j = JournalistProfile(name: "J", beatTopics: ["neural networks"], outlet: Outlet(name: "O"))
        let word = RelevanceEngine.score(analysis: a, journalist: j, similarity: nil).total
        let semantic = RelevanceEngine.score(analysis: a, journalist: j, similarity: 0.7).total
        XCTAssertGreaterThan(semantic, word, "a strong semantic match lifts a profile word overlap missed")
    }

    /// The bundled MiniLM model — must load, produce 384-dim vectors, and
    /// actually separate different topics.
    func testBundledMiniLMLoadsAndDiscriminates() throws {
        let p = try XCTUnwrap(MiniLMEmbeddingProvider(), "MiniLM.mlmodelc must be bundled")
        let ai = try XCTUnwrap(p.vector(for: "open-source LLM evaluation framework for engineering teams"))
        let aiBeat = try XCTUnwrap(p.vector(for: "AI developer tools. AI coding tools. software engineering"))
        let privacyBeat = try XCTUnwrap(p.vector(for: "consumer apps. commerce. streaming"))

        XCTAssertEqual(ai.count, MiniLMEmbeddingProvider.dimension)
        let onBeat = Embedding.rawCosine(ai, aiBeat)
        let offBeat = Embedding.rawCosine(ai, privacyBeat)
        XCTAssertGreaterThan(onBeat, offBeat + 0.1,
                             "an AI story must be clearly closer to an AI beat than a consumer-apps beat")
    }

    private func cosineToSignal(_ raw: Double) -> Double {
        // Build two vectors with a known dot product.
        Embedding.similarity([raw, (1 - raw * raw).squareRoot()], [1, 0])
    }
}
