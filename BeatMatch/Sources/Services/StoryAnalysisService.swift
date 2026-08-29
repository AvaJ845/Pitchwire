import Foundation

struct StoryAnalysisResult: Codable, Hashable {
    var theme: String
    var vertical: String
    var region: String
    var angle: String
    var urgency: String
    var summary: String
    var audience: String
    var subtopics: [String]
    var mediaHooks: [String]
}

protocol StoryAnalysisService {
    func analyze(rawText: String) async throws -> StoryAnalysisResult
}

/// Deterministic, offline implementation so the app runs with zero configuration.
/// The LLM-backed implementation (fast tier — see `ModelTier`) takes an `AIProvider`
/// and produces the same struct; no UI code changes when it's swapped in. The model
/// only ever *interprets* the pasted text — the journalist/outlet data stays
/// authoritative elsewhere.
struct StubStoryAnalysisService: StoryAnalysisService {
    func analyze(rawText: String) async throws -> StoryAnalysisResult {
        let lowered = rawText.lowercased()
        let vertical = Self.detectVertical(in: lowered)
        let angle = Self.detectAngle(in: lowered)
        let urgency = (lowered.contains("today") || lowered.contains("embargo") || lowered.contains("tomorrow"))
            ? "time-sensitive" : "standard"
        let summary = String(rawText.prefix(220)).trimmingCharacters(in: .whitespacesAndNewlines)

        return StoryAnalysisResult(
            theme: Self.displayName(for: vertical),
            vertical: vertical,
            region: lowered.contains("europe") || lowered.contains("eu ") ? "EU" : "US",
            angle: angle,
            urgency: urgency,
            summary: summary.isEmpty ? "No summary available." : summary,
            audience: Self.detectAudience(in: lowered, vertical: vertical),
            subtopics: Self.detectSubtopics(in: lowered),
            mediaHooks: Self.detectMediaHooks(in: lowered, angle: angle, urgency: urgency)
        )
    }

    private static func displayName(for vertical: String) -> String {
        switch vertical {
        case "ai": return "AI"
        case "developer tools": return "Developer tools"
        case "fintech": return "Fintech"
        default: return vertical.capitalized
        }
    }

    private static func detectVertical(in text: String) -> String {
        let map: [(String, [String])] = [
            ("ai", ["ai", "machine learning", "llm", "model", "agent"]),
            ("developer tools", ["developer", "sdk", "api", "cli", "framework"]),
            ("consumer", ["app", "consumer", "iphone", "ios", "android"]),
            ("fintech", ["payment", "banking", "fintech", "finance", "ledger"])
        ]
        for (label, keywords) in map where keywords.contains(where: text.contains) {
            return label
        }
        return "general tech"
    }

    private static func detectAngle(in text: String) -> String {
        if text.contains("raise") || text.contains("funding") || text.contains("series ") || text.contains("seed round") {
            return "funding"
        } else if text.contains("launch") || text.contains("announc") || text.contains("introduc") || text.contains("unveil") {
            return "product launch"
        } else if text.contains("acqui") || text.contains("merger") {
            return "acquisition"
        } else if text.contains("hire") || text.contains("joins as") || text.contains("appoint") {
            return "hire"
        } else if text.contains("partner") || text.contains("integration with") {
            return "partnership"
        }
        return "general news"
    }

    private static func detectAudience(in text: String, vertical: String) -> String {
        if text.contains("developer") || text.contains("engineer") { return "Developers" }
        if text.contains("founder") || text.contains("startup") || text.contains("investor") { return "Founders & investors" }
        if text.contains("enterprise") || text.contains("business") || text.contains("team") { return "Businesses & teams" }
        if text.contains("consumer") || text.contains("everyday") { return "Consumers" }
        switch vertical {
        case "developer tools": return "Developers"
        case "fintech": return "Businesses & teams"
        case "consumer": return "Consumers"
        default: return "Founders & investors"
        }
    }

    private static func detectSubtopics(in text: String) -> [String] {
        let candidates: [String: [String]] = [
            "machine learning": ["machine learning", "ml ", "neural"],
            "automation": ["automat", "workflow"],
            "APIs": ["api", "sdk", "endpoint"],
            "developer tools": ["developer tool", "devtool", "cli"],
            "payments": ["payment", "checkout", "billing"],
            "productivity": ["productivity", "faster", "save time"],
            "privacy": ["privacy", "on-device", "private", "encrypt"],
            "open source": ["open source", "open-source", "mit license"],
            "funding": ["seed", "series a", "series b", "raised"]
        ]
        var hits: [String] = []
        for (label, needles) in candidates where needles.contains(where: text.contains) {
            hits.append(label)
        }
        return Array(hits.prefix(5))
    }

    private static func detectMediaHooks(in text: String, angle: String, urgency: String) -> [String] {
        var hooks: [String] = []
        if text.contains("first") || text.contains("only") { hooks.append("Novelty — framed as a first") }
        if text.contains("fastest") || text.contains("faster") || text.contains("cheaper") { hooks.append("Concrete before/after numbers") }
        if angle == "funding" { hooks.append("New capital + what it funds") }
        if angle == "product launch" { hooks.append("What the product does, in one line") }
        if angle == "acquisition" { hooks.append("Build-vs-buy story for the space") }
        if urgency == "time-sensitive" { hooks.append("Time-bound — embargo or launch date") }
        if text.contains("founder") { hooks.append("Founder available for interview") }
        if hooks.isEmpty { hooks.append("Clear practical use case") }
        return Array(hooks.prefix(4))
    }
}
