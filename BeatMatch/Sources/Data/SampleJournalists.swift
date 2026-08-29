import Foundation

/// Placeholder / sample data for local development only.
/// These are NOT real journalists — fictional profiles to prove the
/// analyze -> understand -> match -> explain -> draft loop before the real
/// ingestion pipeline (public editorial-signal ingestion + provenance registry)
/// is built. Every profile carries provenance records, same as real data would,
/// so the UI never special-cases "sample" vs "real" — it reads whatever's there.
enum SampleJournalists {
    private struct Entry {
        let name: String
        let outlet: String
        let topics: [String]
        let bylines: [String]
        /// (sourceType, detail, coverageBasis, daysSinceVerified, pitchPreference?)
        let provenance: [(ProvenanceSourceType, String, String?, Int, String?)]
    }

    static func seedPool() -> [JournalistProfile] {
        let entries: [Entry] = [
            Entry(name: "Riley Chen", outlet: "The Signal Desk",
                  topics: ["ai", "machine learning", "developer tools", "automation"],
                  bylines: ["How small teams ship AI features fast", "Inside the developer tools boom"],
                  provenance: [
                    (.claimedProfile, "Profile claimed and edited by Riley Chen", "Self-declared beat + pitch rules", 20, "Email preferred, no cold DMs, data-backed pitches"),
                    (.publicSignal, "Bylines from The Signal Desk author page", "12 articles, last 90 days", 6, nil)
                  ]),
            Entry(name: "Morgan Ito", outlet: "Northbridge Tech Review",
                  topics: ["ai", "product launch", "vertical ai"],
                  bylines: ["What makes an AI launch land", "The quiet rise of vertical AI"],
                  provenance: [
                    (.publisherPartner, "Supplied by Northbridge Tech Review editorial desk", "Outlet-provided beat + contact routing", 45, "Launch stories welcome; needs one-line product summary up top"),
                    (.publicSignal, "RSS + author archive", "8 articles, last 60 days", 3, nil)
                  ]),
            Entry(name: "Sasha Reyes", outlet: "Founders Weekly",
                  topics: ["funding", "startups", "seed rounds"],
                  bylines: ["Seed rounds are getting weirder", "Why founders are skipping the pitch deck"],
                  provenance: [
                    (.licensedDataset, "Licensed media database record", "Beat classification + outlet", 200, "Funding news only if the round is closed and named"),
                    (.publicSignal, "Public bylines", "Sparse recent coverage", 150, nil)
                  ]),
            Entry(name: "Dana Whitfield", outlet: "The Interface",
                  topics: ["developer tools", "apis", "cli", "sdk"],
                  bylines: ["The best developer tools of the year", "API design as product strategy"],
                  provenance: [
                    (.claimedProfile, "Profile claimed by Dana Whitfield", "Self-declared beat", 8, "Short, technical pitches. Show, don't tell."),
                  ]),
            Entry(name: "Priya Nandan", outlet: "Consumer Tech Daily",
                  topics: ["consumer", "apps", "ios", "productivity"],
                  bylines: ["The App Store's quiet renaissance", "Why consumer apps are getting simpler"],
                  provenance: [
                    (.publisherPartner, "Consumer Tech Daily contributor roster", "Outlet-provided", 30, "Consumer angle required; no B2B"),
                    (.publicSignal, "Author page", "10 articles, last 90 days", 2, nil)
                  ]),
            Entry(name: "Owen Marsh", outlet: "Fintech Ledger",
                  topics: ["fintech", "payments", "banking"],
                  bylines: ["Payments infrastructure nobody talks about", "The new fintech underwriting stack"],
                  provenance: [
                    (.licensedDataset, "Licensed media database record", "Beat + outlet", 90, "Prefers infrastructure over consumer fintech"),
                  ]),
            Entry(name: "Elena Cho", outlet: "The Signal Desk",
                  topics: ["ai", "acquisition", "product launch"],
                  bylines: ["What AI acquisitions really buy", "The build-vs-buy calculus for AI teams"],
                  provenance: [
                    (.publicSignal, "Bylines from The Signal Desk", "6 articles, last 120 days", 40, nil),
                  ]),
            Entry(name: "Marcus Aldridge", outlet: "Deep Dive Tech",
                  topics: ["developer tools", "ai", "open source"],
                  bylines: ["Framework fatigue is real", "The tools developers actually reach for"],
                  provenance: [
                    (.claimedProfile, "Profile claimed by Marcus Aldridge", "Self-declared beat + do-not-pitch list", 15, "No funding pitches. Open-source angle welcome."),
                    (.publicSignal, "Author archive", "14 articles, last 90 days", 4, nil)
                  ]),
            Entry(name: "Talia Brooks", outlet: "Northbridge Tech Review",
                  topics: ["consumer", "product launch", "automation"],
                  bylines: ["Launch week, decoded", "What a good product launch looks like in 2026"],
                  provenance: [
                    (.publisherPartner, "Northbridge Tech Review editorial desk", "Outlet-provided", 60, "Launch playbooks and consumer angles"),
                  ]),
            Entry(name: "Jules Ferreira", outlet: "Founders Weekly",
                  topics: ["startups", "acquisition", "funding"],
                  bylines: ["The acquihire is back", "Inside a founder's first exit"],
                  provenance: [
                    (.publicSignal, "Public bylines", "5 articles, last 180 days", 170, nil),
                  ]),
            Entry(name: "Nora Kessler", outlet: "The Interface",
                  topics: ["ai", "apis", "sdk", "developer tools"],
                  bylines: ["The API-first AI stack", "Why every AI startup needs an SDK strategy"],
                  provenance: [
                    (.claimedProfile, "Profile claimed by Nora Kessler", "Self-declared beat", 25, "API/SDK strategy stories. Email only."),
                    (.publicSignal, "Author page", "9 articles, last 75 days", 5, nil)
                  ]),
            Entry(name: "Ibrahim Solis", outlet: "Consumer Tech Daily",
                  topics: ["ai", "consumer", "apps"],
                  bylines: ["AI features nobody asked for (and some they did)", "The consumer AI app graveyard"],
                  provenance: [
                    (.publisherPartner, "Consumer Tech Daily roster", "Outlet-provided", 35, "Skeptical of AI hype; bring a real use case"),
                  ]),
            Entry(name: "Wren Ashby", outlet: "Deep Dive Tech",
                  topics: ["fintech", "developer tools", "apis"],
                  bylines: ["Building fintech APIs that don't break", "The infrastructure behind embedded finance"],
                  provenance: [
                    (.licensedDataset, "Licensed media database record", "Beat + outlet", 110, nil),
                    (.publicSignal, "Author archive", "7 articles, last 100 days", 12, nil)
                  ]),
            Entry(name: "Camille Duquette", outlet: "Fintech Ledger",
                  topics: ["funding", "fintech", "startups"],
                  bylines: ["Fintech funding is back, quietly", "Who's actually writing fintech checks in 2026"],
                  provenance: [
                    (.publicSignal, "Public bylines", "6 articles, last 60 days", 8, nil),
                  ]),
            Entry(name: "Theo Lindqvist", outlet: "The Signal Desk",
                  topics: ["developer tools", "ai", "product launch"],
                  bylines: ["Developer-first launches, ranked", "What developers notice in the first five minutes"],
                  provenance: [
                    (.claimedProfile, "Profile claimed by Theo Lindqvist", "Self-declared beat", 10, "Developer-first launches. Short pitch, link to docs."),
                    (.publisherPartner, "The Signal Desk desk", "Outlet-provided contact routing", 50, nil)
                  ]),
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
            journalist.provenanceRecords = entry.provenance.map { item in
                let (type, detail, basis, days, pref) = item
                return ProvenanceRecord(
                    sourceType: type,
                    detail: detail,
                    coverageBasis: basis,
                    lastVerifiedAt: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(),
                    pitchPreference: pref
                )
            }
            return journalist
        }
    }
}
