import XCTest
@testable import Pitchwire

/// The living benchmark for "Pitchwire can consistently explain why its top
/// recommendations are relevant." See `docs/EVAL.md`.
///
/// Runs each benchmark story through the real matching path and asserts the
/// explain-yourself invariants. Vertical-accuracy checks switch on automatically
/// once a real `editorial_seed.json` is bundled.
final class EditorialRelevanceEvalTests: XCTestCase {

    private struct EvalStory {
        let n: Int
        let line: String
        let expectedVerticals: Set<String>
        let analysis: StoryAnalysisResult
    }

    private let pool = EditorialSeedLoader.seedPool()
    private var usingRealSeed: Bool { EditorialSeedLoader.hasRealSeed }

    private func story(
        _ n: Int, _ line: String, verticals: Set<String>,
        vertical: String, angle: String, audience: String,
        region: String = "US", subtopics: [String], theme: String
    ) -> EvalStory {
        EvalStory(n: n, line: line, expectedVerticals: verticals, analysis: StoryAnalysisResult(
            theme: theme, vertical: vertical, region: region, angle: angle,
            urgency: "standard", summary: line, audience: audience,
            subtopics: subtopics, mediaHooks: []
        ))
    }

    private lazy var stories: [EvalStory] = [
        story(1, "Solo dev launches a native macOS Markdown editor with local-first sync.",
              verticals: ["indie-ios-consumer"], vertical: "consumer", angle: "product launch",
              audience: "Consumers", subtopics: ["apps", "ios", "productivity", "design"], theme: "Consumer apps"),
        story(2, "$12M Series A for an open-source LLM evaluation framework for engineering teams.",
              verticals: ["ai-dev-tools"], vertical: "ai", angle: "funding",
              audience: "Developers", subtopics: ["ai", "developer tools", "open source", "llm"], theme: "AI"),
        story(3, "Privacy company ships E2EE group calling with a third-party audit.",
              verticals: ["privacy-security"], vertical: "consumer", angle: "product launch",
              audience: "Consumers", subtopics: ["privacy", "encryption", "security"], theme: "Privacy"),
        story(4, "Neobank launches automated tax-loss harvesting for retail brokerage customers.",
              verticals: ["fintech-personal-finance"], vertical: "fintech", angle: "product launch",
              audience: "Consumers", subtopics: ["fintech", "payments", "investing", "personal finance"], theme: "Fintech"),
        story(5, "AI lab releases a smaller MIT-licensed open-weight model that runs on a laptop.",
              verticals: ["ai-dev-tools"], vertical: "ai", angle: "product launch",
              audience: "Developers", subtopics: ["ai", "open source", "llm", "models"], theme: "AI"),
        story(6, "Well-funded startup acquired by an incumbent for its developer-tools team.",
              verticals: ["ai-dev-tools"], vertical: "developer tools", angle: "acquisition",
              audience: "Founders & investors", subtopics: ["developer tools", "acquisition", "ai"], theme: "Developer tools"),
    ]

    func testEveryStoryProducesFullyExplainedMatches() {
        let service = WeightedRelevanceService()
        let embeddings = DefaultEmbeddingProvider.make()
        for j in pool where j.embedding.count != MiniLMEmbeddingProvider.dimension {
            if let v = embeddings?.vector(for: j.embeddingText), v.count == MiniLMEmbeddingProvider.dimension {
                j.embedding = v
            }
        }
        var report = "\n=== Editorial relevance eval (seed: \(usingRealSeed ? "real" : "fictional fallback"), "
            + "embeddings: \(embeddings == nil ? "off" : "MiniLM") ===\n"

        for s in stories {
            let results = service.match(analysis: s.analysis, storyText: s.line,
                                        against: pool, embeddings: embeddings)
            report += "\n#\(s.n) \(s.line)\n"
            for r in results.prefix(5) {
                report += String(format: "   [%@ %.2f] %@ — %@\n",
                                 r.confidenceTier.rawValue, r.confidenceScore,
                                 r.journalist.name, r.explanation.reasonText)
            }

            XCTAssertFalse(results.isEmpty, "#\(s.n) returned no matches")

            for r in results {
                // Invariant 1 — every match is explained: a real beat and a real reason,
                // never a bare score.
                XCTAssertFalse(r.journalist.beatTopics.isEmpty,
                               "#\(s.n): \(r.journalist.name) has no beat")
                XCTAssertGreaterThan(r.explanation.reasonText.trimmingCharacters(in: .whitespaces).count, 10,
                                     "#\(s.n): \(r.journalist.name) has no real reason")

                // Invariant 2 — "excellent" means repeated on-topic coverage.
                if r.confidenceTier == .excellent {
                    let repeated = r.relevance?.signals.first { $0.name == "Repeated coverage" }?.score ?? 0
                    XCTAssertGreaterThanOrEqual(repeated, 0.5,
                        "#\(s.n): \(r.journalist.name) is 'excellent' without repeated coverage")
                }

                // The shipped seed is human-verified with real dated articles —
                // every returned match should read as verified and carry evidence.
                if usingRealSeed {
                    XCTAssertTrue(r.journalist.isVerified,
                        "#\(s.n): \(r.journalist.name) should read as verified (shipped seed)")
                    XCTAssertFalse(r.journalist.allCoverage.isEmpty,
                        "#\(s.n): \(r.journalist.name) has no article evidence")
                }
            }

            // Invariant 3 — top picks in the right neighbourhood (real seed only).
            if usingRealSeed, let top = results.first {
                let topVerticals = Set(results.prefix(3).compactMap { verticalTag(for: $0.journalist) })
                XCTAssertFalse(topVerticals.isDisjoint(with: s.expectedVerticals),
                    "#\(s.n): top 3 (\(topVerticals)) miss expected \(s.expectedVerticals); top = \(top.journalist.name)")
            }
        }
        print(report)
    }

    func testPitchPreferenceDisqualifiesRatherThanDownranks() {
        // A funding story: any profile that publicly declined funding pitches must
        // be absent or clearly disqualified, never merely lower.
        let funding = stories.first { $0.analysis.angle == "funding" }!.analysis
        for j in pool where j.doNotPitch.contains(where: { funding.angle.localizedCaseInsensitiveContains($0) }) {
            let r = RelevanceEngine.score(analysis: funding, journalist: j)
            XCTAssertTrue(r.isDisqualified, "\(j.name) declined funding pitches but wasn't disqualified")
        }
    }

    /// Pulls a `vertical` tag off a real seed profile. Fictional profiles have none.
    private func verticalTag(for j: JournalistProfile) -> String? {
        // The loader doesn't persist `vertical` on the model; re-read the file.
        guard let url = Bundle.main.url(forResource: "editorial_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SeedFile.self, from: data)
        else { return nil }
        return file.profiles.first { $0.name == j.name }?.vertical
    }
}
