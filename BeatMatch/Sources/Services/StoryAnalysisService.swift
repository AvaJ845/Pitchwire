import Foundation

struct StoryAnalysisResult: Codable, Hashable {
    var theme: String
    var vertical: String
    var region: String
    var angle: String
    var urgency: String
    var summary: String
}

protocol StoryAnalysisService {
    func analyze(rawText: String) async throws -> StoryAnalysisResult
}

/// Deterministic, offline implementation so Slice 0 runs with zero configuration.
/// Swap for an LLM-backed implementation (cheap/fast tier per the brief) without
/// touching UI code — this is the seam the AI Fellow wires a real provider into.
struct StubStoryAnalysisService: StoryAnalysisService {
    func analyze(rawText: String) async throws -> StoryAnalysisResult {
        let lowered = rawText.lowercased()
        let vertical = Self.detectVertical(in: lowered)
        let angle = Self.detectAngle(in: lowered)
        let urgency = (lowered.contains("today") || lowered.contains("embargo")) ? "time-sensitive" : "standard"
        let summary = String(rawText.prefix(220)).trimmingCharacters(in: .whitespacesAndNewlines)

        return StoryAnalysisResult(
            theme: Self.displayName(for: vertical),
            vertical: vertical,
            region: lowered.contains("europe") ? "EU" : "US",
            angle: angle,
            urgency: urgency,
            summary: summary.isEmpty ? "No summary available." : summary
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
            ("ai", ["ai", "machine learning", "llm", "model"]),
            ("developer tools", ["developer", "sdk", "api", "cli", "framework"]),
            ("consumer", ["app", "consumer", "iphone", "ios"]),
            ("fintech", ["payment", "banking", "fintech", "finance"])
        ]
        for (label, keywords) in map where keywords.contains(where: text.contains) {
            return label
        }
        return "general tech"
    }

    private static func detectAngle(in text: String) -> String {
        if text.contains("raise") || text.contains("funding") || text.contains("series ") {
            return "funding"
        } else if text.contains("launch") || text.contains("announc") {
            return "product launch"
        } else if text.contains("acqui") {
            return "acquisition"
        }
        return "general news"
    }
}
