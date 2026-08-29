import Foundation

/// One weighted factor in a match score. Deterministic and inspectable — every
/// number here can be shown to the user and traced to structured data.
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

    var tier: ConfidenceTier {
        total >= 0.68 ? .excellent : (total >= 0.42 ? .strong : .possible)
    }

    /// The signals that actually drove the score, strongest first.
    var drivers: [RelevanceSignal] {
        signals.filter { $0.score >= 0.35 && $0.note != nil }
            .sorted { $0.contribution > $1.contribution }
    }

    var isDisqualified: Bool {
        signals.contains { $0.name == "Pitch preference" && $0.score == 0 }
    }
}

/// Scores a journalist against an analyzed story on weighted, explainable
/// signals — the "relevance engine" from the brief. The model never runs here;
/// this reads structured beat / coverage / preference data only.
enum RelevanceEngine {

    static func score(analysis: StoryAnalysisResult, journalist j: JournalistProfile) -> RelevanceResult {
        let storyTerms = terms(analysis.subtopics + [analysis.vertical, analysis.theme])
        let beatTerms = terms(j.beatTopics)
        let bylineTerms = terms(j.recentBylineTitles)

        // 1. Beat match — do their declared topics overlap the story?
        let beatOverlap = beatTerms.intersection(storyTerms)
        let beatScore = beatTerms.isEmpty ? 0 : min(1, Double(beatOverlap.count) / 2.0)
        let beatNote = beatOverlap.isEmpty ? nil
            : "covers \(display(j.beatTopics, matching: beatOverlap))"

        // 2. Recent coverage — have they written on this lately? (byline titles,
        //    recency approximated by position: earlier = more recent.)
        var coverageScore = 0.0
        var coverageHit: String?
        for (i, title) in j.recentBylineTitles.prefix(4).enumerated() {
            let hit = terms([title]).intersection(storyTerms)
            if !hit.isEmpty {
                let recencyWeight = 1.0 - (Double(i) * 0.2)
                coverageScore = max(coverageScore, recencyWeight)
                if coverageHit == nil { coverageHit = "\u{201C}\(title)\u{201D}" }
            }
        }
        let coverageNote = coverageHit.map { "wrote \($0) recently" }

        // 3. Angle fit — do they cover this kind of story (launch vs funding vs …)?
        let angleScore: Double = j.coveredAngles.isEmpty ? 0.5
            : (j.coveredAngles.contains(analysis.angle) ? 1.0 : 0.15)
        let angleNote = j.coveredAngles.contains(analysis.angle)
            ? "works the \(analysis.angle) beat" : nil

        // 4. Audience fit
        let audienceScore: Double = j.audiences.isEmpty ? 0.5
            : (j.audiences.contains(analysis.audience) ? 1.0 : 0.3)
        let audienceNote = j.audiences.contains(analysis.audience)
            ? "writes for \(analysis.audience.lowercased())" : nil

        // 5. Geography
        let geoScore: Double = j.regions.isEmpty ? 0.6
            : (j.regions.contains(analysis.region) || j.regions.contains("Global") ? 1.0 : 0.35)

        // 6. Declared pitch preference — a hard filter, not a nudge.
        //    "no funding pitches" etc. zeroes it out.
        let blocked = j.doNotPitch.contains { dnp in
            analysis.angle.localizedCaseInsensitiveContains(dnp)
                || dnp.localizedCaseInsensitiveContains(analysis.angle)
                || storyTerms.contains(dnp.lowercased())
        }
        let prefScore: Double = blocked ? 0.0 : 1.0

        // 7. Evidence freshness — a small tilt toward better-sourced profiles.
        let evidenceScore: Double = {
            switch j.evidenceConfidence {
            case .high: return 1.0
            case .moderate: return 0.6
            case .exploratory: return 0.35
            }
        }()

        let signals = [
            RelevanceSignal(name: "Beat match",       score: beatScore,     weight: 0.28, note: beatNote),
            RelevanceSignal(name: "Recent coverage",  score: coverageScore, weight: 0.24, note: coverageNote),
            RelevanceSignal(name: "Angle fit",        score: angleScore,    weight: 0.16, note: angleNote),
            RelevanceSignal(name: "Audience fit",     score: audienceScore, weight: 0.12, note: audienceNote),
            RelevanceSignal(name: "Geography",        score: geoScore,      weight: 0.06, note: nil),
            RelevanceSignal(name: "Pitch preference", score: prefScore,     weight: 0.06, note: blocked ? "they've asked not to be pitched this angle" : nil),
            RelevanceSignal(name: "Evidence",         score: evidenceScore, weight: 0.08, note: nil),
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
            // Uppercase a standalone "ai" inside a phrase ("vertical ai" -> "vertical AI").
            return raw
                .split(separator: " ")
                .map { $0 == "ai" ? "AI" : String($0) }
                .joined(separator: " ")
        }
    }
}
