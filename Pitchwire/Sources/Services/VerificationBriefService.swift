import Foundation

#if DEBUG
/// Research Lab helper (DEBUG-only — the Lab is `#if DEBUG`). The model drafts
/// **how to verify** a candidate — what to confirm on their author page, what to
/// search for — so a researcher works faster. It has no web access and concludes
/// nothing; this is guidance, never evidence, and it is not stored.
struct VerificationBrief: Equatable {
    var checks: [String]
    var searches: [String]

    var isEmpty: Bool { checks.isEmpty && searches.isEmpty }
}

@MainActor
enum VerificationBriefService {

    static func draft(for profile: JournalistProfile, using ai: AIClient) async -> VerificationBrief? {
        guard ai.isConfigured else { return nil }
        // @Model fields read here, on the main actor.
        let request = AIRequest(
            task: .verificationBrief,
            tier: .fast,
            input: [
                "journalist": profile.name,
                "outlet": profile.outlet?.name ?? "",
                "beat": profile.beatTopics.joined(separator: ", "),
                "sourcePage": profile.primaryEvidence?.sourceURL ?? "",
                "aiSummary": profile.primaryEvidence?.evidenceSummary ?? ""
            ],
            prompt: "Draft a verification brief for this candidate.",
            origin: .userInitiated
        )
        guard let text = await ai.text(for: request) else { return nil }
        let brief = parse(text)
        return brief.isEmpty ? nil : brief
    }

    /// Split the two labelled blocks. Tolerant of markdown bullets and casing.
    nonisolated static func parse(_ raw: String) -> VerificationBrief {
        var checks: [String] = []
        var searches: [String] = []
        var bucket = 0   // 0 = none, 1 = checks, 2 = searches

        for line in raw.split(separator: "\n") {
            let t = line
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            let lower = t.lowercased()
            if lower.hasPrefix("checks") { bucket = 1; continue }
            if lower.hasPrefix("searches") || lower.hasPrefix("search:") { bucket = 2; continue }

            let item = t.drop(while: { "-•\u{2022}0123456789.) ".contains($0) })
                .trimmingCharacters(in: .whitespaces)
            guard item.count > 3 else { continue }
            switch bucket {
            case 1: checks.append(item)
            case 2: searches.append(item)
            default: break
            }
        }
        return VerificationBrief(checks: Array(checks.prefix(4)), searches: Array(searches.prefix(4)))
    }
}
#endif
