import Foundation

/// One weighted factor in an editorial-relevance score. Deterministic and
/// inspectable — every number here can be shown to the user and traced to
/// structured editorial data.
struct RelevanceSignal: Identifiable {
    let id = UUID()
    let name: String
    let score: Double        // 0...1
    let weight: Double        // relative importance
    let note: String?         // human fragment for the "why", nil if it didn't contribute

    var contribution: Double { score * weight }
}

struct RelevanceResult {
    let signals: [RelevanceSignal]

    /// 0...1 — weighted average of the signals that had any weight.
    var total: Double {
        let w = signals.map(\.weight).reduce(0, +)
        guard w > 0 else { return 0 }
        return signals.map(\.contribution).reduce(0, +) / w
    }

    /// Editorial-relevance tier. An "excellent" match must show a *pattern* of
    /// coverage, not a single lucky headline.
    var tier: ConfidenceTier {
        let repeated = signals.first { $0.name == Signal.repeatedCoverage }?.score ?? 0
        if total >= 0.68 && repeated >= 0.5 { return .excellent }
        if total >= 0.42 { return .strong }
        return .possible
    }

    /// The signals that actually drove the score, strongest first.
    var drivers: [RelevanceSignal] {
        signals.filter { $0.score >= 0.35 && $0.note != nil }
            .sorted { $0.contribution > $1.contribution }
    }

    var isDisqualified: Bool {
        signals.contains { $0.name == Signal.pitchPreference && $0.score == 0 }
    }

    /// Shown wherever the score appears. The score is about editorial fit — it is
    /// explicitly **not** a prediction of a reply or of coverage.
    var relevanceDisclaimer: String {
        "Editorial relevance — how closely their published work matches your story. "
            + "Not a prediction that they will respond or cover it."
    }

    enum Signal {
        static let topicMatch = "Editorial similarity"
        static let recentCoverage = "Recent coverage"
        static let repeatedCoverage = "Repeated coverage"
        static let angleFit = "Angle fit"
        static let audienceFit = "Audience fit"
        static let publication = "Publication relevance"
        static let geography = "Geography"
        static let pitchPreference = "Pitch preference"
        static let evidence = "Evidence & verification"
    }
}

/// Scores an editorial professional against an analyzed story on weighted,
/// explainable signals. The model never runs here — this reads structured beat /
/// coverage / preference data only, so every recommendation is traceable.
enum RelevanceEngine {
    typealias Signal = RelevanceResult.Signal

    /// `similarity` is the on-device semantic match of the story to this person's
    /// beat + real article text (0...1). `nil` = no embedding model — the engine
    /// falls back to word-overlap so it still works offline.
    static func score(analysis: StoryAnalysisResult, journalist j: JournalistProfile,
                      similarity: Double? = nil) -> RelevanceResult {
        let storyTerms = terms(analysis.subtopics + [analysis.vertical, analysis.theme])
        let beatTerms = terms(j.beatTopics)
        let coverage = j.allCoverage
        let beatOverlap = beatTerms.intersection(storyTerms)

        // 1. Editorial similarity — does the story match what they actually write?
        //    Word overlap on the declared beat is the precise anchor; on-device
        //    semantic similarity adds recall for synonymy ("LLM" ≈ "language
        //    model"). The stronger of the two wins; nil similarity = offline.
        let wordScore = beatTerms.isEmpty ? 0 : min(1, Double(beatOverlap.count) / 2.0)
        let topicScore = max(wordScore, similarity ?? 0)
        let topicNote: String? = {
            if !beatOverlap.isEmpty { return "covers \(display(j.beatTopics, matching: beatOverlap))" }
            if (similarity ?? 0) >= 0.45 { return "their published work lines up with this story" }
            return nil
        }()

        // On-topic articles count as coverage of *this* story only when the
        // person's **declared beat** overlaps the story's specific subtopics.
        // (Similarity is not discriminative enough to gate on — it reads every
        // tech story as ~0.6 similar to every other.) Without this gate an
        // off-beat one-off headline reads as a beat.
        let storyCoreTerms = terms(analysis.subtopics)
        let beatFitsStory = !beatTerms.isDisjoint(with: storyCoreTerms)
        let onTopic = beatFitsStory ? coverage.filter { article in
            !terms([article.title]).union(terms(article.topics)).isDisjoint(with: storyTerms)
        } : []

        // 2. Recent coverage — recency of their most recent on-topic article,
        //    from real publish dates (not byline position).
        let recencyScore = onTopic.map { recency(of: $0.publishedAt) }.max() ?? 0
        let recentNote: String? = {
            guard recencyScore >= 0.35 else { return nil }
            // Only quote a headline when the headline itself is on-topic — a
            // tag-only match shouldn't put a mismatched title in the reason.
            if let byTitle = onTopic.first(where: { !terms([$0.title]).isDisjoint(with: storyTerms) }) {
                let when = byTitle.publishedLabel.map { " (\($0))" } ?? ""
                return "wrote \u{201C}\(byTitle.title)\u{201D}\(when)"
            }
            return "has recent coverage in this area"
        }()

        // 3. Repeated coverage — a real beat writes about this more than once.
        let repeatedScore: Double = {
            switch onTopic.count {
            case 0: return 0
            case 1: return 0.4
            case 2: return 0.75
            default: return 1.0
            }
        }()
        let repeatedNote = onTopic.count >= 2
            ? "has covered this repeatedly (\(onTopic.count) recent pieces)" : nil

        // 4. Angle fit — do they cover this kind of story (launch vs funding vs …)?
        let coversAngle = j.coveredAngles.contains(analysis.angle)
        let angleScore: Double = j.coveredAngles.isEmpty ? 0.5 : (coversAngle ? 1.0 : 0.15)
        let angleNote = coversAngle ? "works the \(analysis.angle) beat" : nil

        // 5. Audience fit
        let servesAudience = j.audiences.contains(analysis.audience)
        let audienceScore: Double = j.audiences.isEmpty ? 0.5 : (servesAudience ? 1.0 : 0.3)
        let audienceNote = servesAudience ? "writes for \(analysis.audience.lowercased())" : nil

        // 6. Publication relevance — is the outlet itself in this space?
        let outletTerms = terms(j.outlet?.verticals ?? [])
        let outletOverlap = outletTerms.intersection(storyTerms)
        let publicationScore: Double = outletTerms.isEmpty ? 0.5
            : (outletOverlap.isEmpty ? 0.35 : min(1, 0.6 + 0.4 * Double(outletOverlap.count)))
        let publicationNote = (!outletOverlap.isEmpty && j.outlet != nil)
            ? "at \(j.outlet!.name), which covers this space" : nil

        // 7. Geography
        let geoScore: Double = j.regions.isEmpty ? 0.6
            : (j.regions.contains(analysis.region) || j.regions.contains("Global") ? 1.0 : 0.35)

        // 8. Declared pitch preference — a hard filter, not a nudge.
        let blocked = j.doNotPitch.contains { dnp in
            analysis.angle.localizedCaseInsensitiveContains(dnp)
                || dnp.localizedCaseInsensitiveContains(analysis.angle)
                || storyTerms.contains(dnp.lowercased())
        }
        let prefScore: Double = blocked ? 0.0 : 1.0

        // 9. Evidence & verification — a small tilt toward better-sourced,
        //    human-verified profiles. Unverified candidates never get elevated.
        let evidenceScore: Double = {
            switch j.evidenceConfidence {
            case .high: return 1.0
            case .moderate: return 0.6
            case .exploratory: return 0.35
            }
        }()

        let signals = [
            RelevanceSignal(name: Signal.topicMatch,       score: topicScore,       weight: 0.24, note: topicNote),
            RelevanceSignal(name: Signal.recentCoverage,   score: recencyScore,     weight: 0.18, note: recentNote),
            RelevanceSignal(name: Signal.repeatedCoverage, score: repeatedScore,    weight: 0.14, note: repeatedNote),
            RelevanceSignal(name: Signal.angleFit,         score: angleScore,       weight: 0.10, note: angleNote),
            RelevanceSignal(name: Signal.audienceFit,      score: audienceScore,    weight: 0.10, note: audienceNote),
            RelevanceSignal(name: Signal.publication,      score: publicationScore, weight: 0.08, note: publicationNote),
            RelevanceSignal(name: Signal.geography,        score: geoScore,         weight: 0.04, note: nil),
            RelevanceSignal(name: Signal.pitchPreference,  score: prefScore,        weight: 0.06, note: blocked ? "they've asked not to be pitched this angle" : nil),
            RelevanceSignal(name: Signal.evidence,         score: evidenceScore,    weight: 0.06, note: nil),
        ]
        return RelevanceResult(signals: signals)
    }

    /// A readable "why" built from the signals that actually drove the score.
    static func prose(_ result: RelevanceResult, journalist j: JournalistProfile) -> String {
        if result.isDisqualified {
            return "On topic, but \(j.name) has asked not to be pitched this kind of story."
        }
        let fragments = Array(result.drivers.prefix(3).compactMap(\.note))
        guard !fragments.isEmpty else {
            return "A light topical overlap with this story."
        }
        let joined: String
        switch fragments.count {
        case 1: joined = fragments[0]
        case 2: joined = "\(fragments[0]) and \(fragments[1])"
        default: joined = "\(fragments[0]), \(fragments[1]), and \(fragments[2])"
        }
        let closer: String
        switch result.tier {
        case .excellent: closer = " — a direct fit for this story."
        case .strong:    closer = " — a solid fit."
        case .possible:  closer = "."
        }
        return joined.prefix(1).uppercased() + joined.dropFirst() + closer
    }

    // MARK: - helpers

    /// Recency weight from a real publish date. Unknown date → treated as stale.
    private static func recency(of date: Date?) -> Double {
        guard let date else { return 0.2 }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 9_999
        switch days {
        case ..<0:    return 0.9      // future-dated (bad data) — don't reward fully
        case 0..<60:  return 1.0
        case 60..<180: return 0.7
        case 180..<365: return 0.4
        default:      return 0.2
        }
    }

    private static let stop: Set<String> = ["the", "and", "for", "with", "your", "a", "an", "of", "to", "in", "on", "is", "are"]

    private static func terms(_ strings: [String]) -> Set<String> {
        Set(strings
            .flatMap { $0.lowercased().split { !$0.isLetter }.map(String.init) }
            .filter { $0.count > 1 && !stop.contains($0) }
        )
    }

    private static func display(_ topics: [String], matching: Set<String>) -> String {
        let hits = topics.filter { topic in
            !terms([topic]).isDisjoint(with: matching)
        }
        let shown = (hits.isEmpty ? topics : hits).prefix(2).map(prettyBeat)
        return shown.joined(separator: " and ")
    }

    private static func prettyBeat(_ raw: String) -> String {
        switch raw {
        case "ai": return "AI"
        case "apis", "api": return "APIs"
        case "sdk", "sdks": return "SDKs"
        case "cli": return "the CLI"
        case "ios": return "iOS"
        default:
            return raw
                .split(separator: " ")
                .map { $0 == "ai" ? "AI" : String($0) }
                .joined(separator: " ")
        }
    }
}
