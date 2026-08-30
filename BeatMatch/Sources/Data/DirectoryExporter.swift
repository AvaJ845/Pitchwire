import Foundation

/// Serialises the live `JournalistDirectory` back into `editorial_seed.json`
/// shape, so a researcher's verify/edit work can be committed as the shipped
/// seed instead of living only in one device's store.
///
/// DEBUG-only surface (the Lab). The output has the same fields as the input —
/// **no contact data**, ever.
enum DirectoryExporter {

    static func json(for profiles: [JournalistProfile], reviewer: String) -> String {
        let file = SeedFile(
            generatedAt: SeedDate.string.string(from: Date()),
            method: "Exported from the Research Lab after human verification. "
                + "Records marked verified were checked against their author page by \(reviewer.isEmpty ? "a researcher" : reviewer). "
                + "No contact data. Article dates are as published, never guessed.",
            verticals: ["ai-dev-tools", "privacy-security", "fintech-personal-finance", "indie-ios-consumer"],
            profiles: profiles
                .filter { !$0.isRejected }
                .sorted { $0.name < $1.name }
                .map(seedProfile(from:))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .useDefaultKeys
        return (try? encoder.encode(file)).flatMap { String(data: $0, encoding: .utf8) }
            ?? "{\"error\":\"encode failed\"}"
    }

    private static func seedProfile(from p: JournalistProfile) -> SeedProfile {
        let record = p.primaryEvidence
        return SeedProfile(
            name: p.name,
            outlet: p.outlet?.name ?? "",
            outletURL: p.outlet?.url,
            outletVerticals: p.outlet?.verticals.isEmpty == false ? p.outlet?.verticals : nil,
            role: p.role,
            beatTopics: p.beatTopics,
            audiences: p.audiences.isEmpty ? nil : p.audiences,
            regions: p.regions.isEmpty ? nil : p.regions,
            coveredAngles: p.coveredAngles.isEmpty ? nil : p.coveredAngles,
            vertical: p.vertical,
            provenance: (record?.provenance ?? .publicEditorialSignal).rawValue,
            sourceURL: record?.sourceURL,
            evidenceSummary: record?.evidenceSummary ?? "",
            confidence: (record?.confidence ?? .exploratory).rawValue,
            verificationDate: SeedDate.format(record?.verificationDate),
            verifiedBy: record?.verifiedBy,
            publishedPitchPreference: record?.pitchPreference,
            articles: p.allCoverage.map {
                SeedArticle(title: $0.title, url: $0.url,
                            publishedAt: SeedDate.format($0.publishedAt),
                            topics: $0.topics.isEmpty ? nil : $0.topics)
            }
        )
    }
}
