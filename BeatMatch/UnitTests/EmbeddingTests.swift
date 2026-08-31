import XCTest
@testable import Pitchwire

final class EmbeddingTests: XCTestCase {

    func testSimilarityRescaleSpreadsTheUsefulRange() {
        // Raw cosine of two identical unit vectors is 1.0 → rescaled to 1.0.
        let v = Embedding.normalize([0.3, 0.4, 0.5, 0.1])
        XCTAssertEqual(Embedding.similarity(v, v), 1.0, accuracy: 0.001)

        // NLEmbedding compresses unrelated tech text to ~0.55–0.65 raw — that
        // must map to a near-zero signal, not "somewhat relevant".
        XCTAssertLessThan(cosineToSignal(0.58), 0.15)
        XCTAssertGreaterThan(cosineToSignal(0.78), 0.8)
        XCTAssertEqual(cosineToSignal(0.40), 0.0, "below the floor → no signal")
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

    /// The on-device model — may be unavailable in CI; that's a valid state.
    func testNLEmbeddingProviderIsUsableOrCleanlyAbsent() {
        let p = NLEmbeddingProvider()
        if p.isAvailable {
            let v = p.vector(for: "an open-source AI developer tools framework")
            XCTAssertEqual(v?.count ?? 0 > 0, true)
        } else {
            XCTAssertNil(p.vector(for: "anything"))
        }
    }

    private func cosineToSignal(_ raw: Double) -> Double {
        // Build two vectors with a known dot product.
        Embedding.similarity([raw, (1 - raw * raw).squareRoot()], [1, 0])
    }
}
