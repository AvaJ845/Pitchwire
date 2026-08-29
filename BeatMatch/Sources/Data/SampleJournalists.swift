import Foundation

/// Fictional sample data — **not real journalists.** These stand in for the real
/// ingestion pipeline (public editorial signals + publisher partnerships +
/// licensed data + claimed profiles) so the analyze → match → explain → draft
/// loop can be built and shown. Every profile carries only `.sampleData`
/// provenance, so `JournalistProfile.isSampleData` is true and the UI shows a
/// clear "sample data" state everywhere a match appears.
///
/// The beat / audience / angle / byline fields are shaped like what real public
/// editorial signals would produce, so the relevance engine has something real
/// to score against. When real ingestion lands it writes real `ProvenanceRecord`s
/// with real source types; `isSampleData` flips to false and the banners vanish.
enum SampleJournalists {
    private struct Entry {
        let name: String
        let outlet: String
        let topics: [String]
        let bylines: [String]
        let audiences: [String]
        let regions: [String]
        let angles: [String]
        var doNotPitch: [String] = []
    }

    static func seedPool() -> [JournalistProfile] {
        let entries: [Entry] = [
            Entry(name: "Riley Chen", outlet: "The Signal Desk",
                  topics: ["ai", "machine learning", "developer tools", "automation"],
                  bylines: ["How small teams ship AI features fast", "Inside the developer tools boom", "The year agents got useful"],
                  audiences: ["Developers", "Founders & investors"], regions: ["US", "Global"],
                  angles: ["product launch", "partnership"]),
            Entry(name: "Morgan Ito", outlet: "Northbridge Tech Review",
                  topics: ["ai", "product launch", "vertical ai"],
                  bylines: ["What makes an AI launch land", "The quiet rise of vertical AI", "Launch week, decoded"],
                  audiences: ["Founders & investors", "Businesses & teams"], regions: ["US"],
                  angles: ["product launch", "acquisition"]),
            Entry(name: "Sasha Reyes", outlet: "Founders Weekly",
                  topics: ["funding", "startups", "seed rounds", "venture"],
                  bylines: ["Seed rounds are getting weirder", "Why founders are skipping the pitch deck", "Who's writing first checks now"],
                  audiences: ["Founders & investors"], regions: ["US", "Global"],
                  angles: ["funding"], doNotPitch: ["product launch"]),
            Entry(name: "Dana Whitfield", outlet: "The Interface",
                  topics: ["developer tools", "apis", "cli", "sdk"],
                  bylines: ["The best developer tools of the year", "API design as product strategy", "CLI renaissance"],
                  audiences: ["Developers"], regions: ["US", "EU"],
                  angles: ["product launch", "partnership"]),
            Entry(name: "Priya Nandan", outlet: "Consumer Tech Daily",
                  topics: ["consumer", "apps", "ios", "productivity"],
                  bylines: ["The App Store's quiet renaissance", "Why consumer apps are getting simpler", "The productivity app reckoning"],
                  audiences: ["Consumers"], regions: ["US"],
                  angles: ["product launch"], doNotPitch: ["funding"]),
            Entry(name: "Owen Marsh", outlet: "Fintech Ledger",
                  topics: ["fintech", "payments", "banking", "infrastructure"],
                  bylines: ["Payments infrastructure nobody talks about", "The new fintech underwriting stack"],
                  audiences: ["Businesses & teams"], regions: ["US", "EU"],
                  angles: ["product launch", "partnership", "funding"]),
            Entry(name: "Elena Cho", outlet: "The Signal Desk",
                  topics: ["ai", "acquisition", "product strategy"],
                  bylines: ["What AI acquisitions really buy", "The build-vs-buy calculus for AI teams"],
                  audiences: ["Founders & investors", "Businesses & teams"], regions: ["US"],
                  angles: ["acquisition", "funding"]),
            Entry(name: "Marcus Aldridge", outlet: "Deep Dive Tech",
                  topics: ["developer tools", "ai", "open source", "frameworks"],
                  bylines: ["Framework fatigue is real", "The tools developers actually reach for", "Open source's funding problem"],
                  audiences: ["Developers"], regions: ["Global"],
                  angles: ["product launch", "partnership"], doNotPitch: ["funding"]),
            Entry(name: "Talia Brooks", outlet: "Northbridge Tech Review",
                  topics: ["consumer", "product launch", "design"],
                  bylines: ["Launch week, decoded", "What a good product launch looks like in 2026", "The onboarding arms race"],
                  audiences: ["Consumers", "Founders & investors"], regions: ["US"],
                  angles: ["product launch"]),
            Entry(name: "Jules Ferreira", outlet: "Founders Weekly",
                  topics: ["startups", "acquisition", "exits"],
                  bylines: ["The acquihire is back", "Inside a founder's first exit"],
                  audiences: ["Founders & investors"], regions: ["US", "EU"],
                  angles: ["acquisition", "funding"]),
            Entry(name: "Nora Kessler", outlet: "The Interface",
                  topics: ["ai", "apis", "sdk", "developer tools"],
                  bylines: ["The API-first AI stack", "Why every AI startup needs an SDK strategy", "Inference is the new bottleneck"],
                  audiences: ["Developers", "Founders & investors"], regions: ["US", "Global"],
                  angles: ["product launch", "partnership"]),
            Entry(name: "Ibrahim Solis", outlet: "Consumer Tech Daily",
                  topics: ["ai", "consumer", "apps"],
                  bylines: ["AI features nobody asked for (and some they did)", "The consumer AI app graveyard"],
                  audiences: ["Consumers"], regions: ["US"],
                  angles: ["product launch"]),
            Entry(name: "Wren Ashby", outlet: "Deep Dive Tech",
                  topics: ["fintech", "developer tools", "apis", "infrastructure"],
                  bylines: ["Building fintech APIs that don't break", "The infrastructure behind embedded finance"],
                  audiences: ["Developers", "Businesses & teams"], regions: ["EU", "US"],
                  angles: ["product launch", "partnership"]),
            Entry(name: "Camille Duquette", outlet: "Fintech Ledger",
                  topics: ["funding", "fintech", "startups", "venture"],
                  bylines: ["Fintech funding is back, quietly", "Who's actually writing fintech checks in 2026"],
                  audiences: ["Founders & investors"], regions: ["EU", "Global"],
                  angles: ["funding", "acquisition"], doNotPitch: ["product launch"]),
            Entry(name: "Theo Lindqvist", outlet: "The Signal Desk",
                  topics: ["developer tools", "ai", "product launch"],
                  bylines: ["Developer-first launches, ranked", "What developers notice in the first five minutes", "The changelog is the pitch"],
                  audiences: ["Developers"], regions: ["EU", "Global"],
                  angles: ["product launch"]),
        ]

        var outletCache: [String: Outlet] = [:]

        return entries.map { entry in
            let outlet = outletCache[entry.outlet] ?? Outlet(name: entry.outlet, verticals: [])
            outletCache[entry.outlet] = outlet

            let journalist = JournalistProfile(
                name: entry.name,
                beatTopics: entry.topics,
                recentBylineTitles: entry.bylines,
                outlet: outlet,
                audiences: entry.audiences,
                regions: entry.regions,
                coveredAngles: entry.angles,
                doNotPitch: entry.doNotPitch
            )
            journalist.provenanceRecords = [
                ProvenanceRecord(
                    sourceType: .sampleData,
                    detail: "Fictional profile — a stand-in until real journalist ingestion is built. This is not a real person.",
                    coverageBasis: "Demo beat topics and article titles, not real coverage",
                    lastVerifiedAt: Date()
                )
            ]
            return journalist
        }
    }
}
