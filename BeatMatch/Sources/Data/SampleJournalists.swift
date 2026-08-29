import Foundation

/// Placeholder / sample data for local development only.
/// These are NOT real journalists — Slice 0 uses fictional profiles to prove the
/// analyze -> match -> explain -> draft loop before the real ingestion pipeline
/// (Fellow 4: public editorial-signal ingestion + provenance registry) is built.
/// Every profile still carries a provenance record, same as real data would,
/// so the UI never special-cases "sample" vs "real" — it just reads whatever's there.
enum SampleJournalists {
    static func seedPool() -> [JournalistProfile] {
        let entries: [(name: String, outlet: String, topics: [String], bylines: [String])] = [
            ("Riley Chen", "The Signal Desk", ["ai", "machine", "learning", "developer"], ["How small teams ship AI features fast", "Inside the developer tools boom"]),
            ("Morgan Ito", "Northbridge Tech Review", ["ai", "product", "launch"], ["What makes an AI launch land", "The quiet rise of vertical AI"]),
            ("Sasha Reyes", "Founders Weekly", ["funding", "startups", "series"], ["Seed rounds are getting weirder", "Why founders are skipping the pitch deck"]),
            ("Dana Whitfield", "The Interface", ["developer", "sdk", "api", "cli"], ["The best developer tools of the year", "API design as product strategy"]),
            ("Priya Nandan", "Consumer Tech Daily", ["consumer", "app", "ios"], ["The App Store's quiet renaissance", "Why consumer apps are getting simpler"]),
            ("Owen Marsh", "Fintech Ledger", ["fintech", "payment", "banking"], ["Payments infrastructure nobody talks about", "The new fintech underwriting stack"]),
            ("Elena Cho", "The Signal Desk", ["ai", "acquisition", "product"], ["What AI acquisitions really buy", "The build-vs-buy calculus for AI teams"]),
            ("Marcus Aldridge", "Deep Dive Tech", ["developer", "framework", "ai"], ["Framework fatigue is real", "The tools developers actually reach for"]),
            ("Talia Brooks", "Northbridge Tech Review", ["consumer", "launch", "general"], ["Launch week, decoded", "What a good product launch looks like in 2026"]),
            ("Jules Ferreira", "Founders Weekly", ["startups", "acquisition", "general"], ["The acquihire is back", "Inside a founder's first exit"]),
            ("Nora Kessler", "The Interface", ["ai", "sdk", "api"], ["The API-first AI stack", "Why every AI startup needs an SDK strategy"]),
            ("Ibrahim Solis", "Consumer Tech Daily", ["ai", "consumer", "app"], ["AI features nobody asked for (and some they did)", "The consumer AI app graveyard"]),
            ("Wren Ashby", "Deep Dive Tech", ["fintech", "developer", "api"], ["Building fintech APIs that don't break", "The infrastructure behind embedded finance"]),
            ("Camille Duquette", "Fintech Ledger", ["funding", "fintech", "startups"], ["Fintech funding is back, quietly", "Who's actually writing fintech checks in 2026"]),
            ("Theo Lindqvist", "The Signal Desk", ["developer", "ai", "launch"], ["Developer-first launches, ranked", "What developers notice in the first five minutes"])
        ]

        var outletCache: [String: Outlet] = [:]

        return entries.map { entry in
            let outlet = outletCache[entry.outlet] ?? Outlet(name: entry.outlet, verticals: [])
            outletCache[entry.outlet] = outlet

            let journalist = JournalistProfile(
                name: entry.name,
                beatTopics: entry.topics,
                recentBylineTitles: entry.bylines,
                outlet: outlet
            )
            journalist.provenance = ProvenanceRecord(
                source: "Sample data (development seed, not verified)",
                lastVerifiedAt: Date(),
                pitchPreference: "Email preferred, no cold DMs",
                issueReported: false
            )
            return journalist
        }
    }
}
