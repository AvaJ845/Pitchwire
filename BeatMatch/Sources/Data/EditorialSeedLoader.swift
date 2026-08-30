import Foundation

/// Loads the editorial research seed set — a **gold-standard evaluation dataset**,
/// not the start of a scraped database. Records are compiled from public editorial
/// signals (author pages, bylines) in a research session and ship as *candidates*:
/// `verificationDate` is null until a human approves them in the Research Lab.
///
/// If no `editorial_seed.json` is bundled, falls back to `SampleJournalists`
/// (fictional demo data) so the app still runs.
enum EditorialSeedLoader {

    /// The pool the matcher scores against. Real candidates when present, else
    /// fictional demo profiles.
    static func seedPool() -> [JournalistProfile] {
        (try? load()) ?? SampleJournalists.seedPool()
    }

    /// `true` when a real seed file is bundled (used to pick honest UI copy).
    static var hasRealSeed: Bool {
        Bundle.main.url(forResource: "editorial_seed", withExtension: "json") != nil
    }

    static func load(from bundle: Bundle = .main) throws -> [JournalistProfile] {
        guard let url = bundle.url(forResource: "editorial_seed", withExtension: "json") else {
            throw SeedError.notBundled
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder.seed.decode(SeedFile.self, from: data)
        return file.profiles.map { $0.build() }
    }

    enum SeedError: Error { case notBundled }
}

// MARK: - JSON shape

/// Mirrors `editorial_seed.json`. Deliberately has **no** field for email, phone,
/// social handles or any other contact data — that is not what this product holds.
struct SeedFile: Decodable {
    var generatedAt: String
    var method: String
    var profiles: [SeedProfile]
}

struct SeedProfile: Decodable {
    var name: String
    var outlet: String
    var outletURL: String?
    var outletVerticals: [String]?
    var role: String?
    var beatTopics: [String]
    var audiences: [String]?
    var regions: [String]?
    var coveredAngles: [String]?
    var vertical: String?
    var provenance: String
    var sourceURL: String?
    var evidenceSummary: String
    var confidence: String?
    /// ISO-8601 date; null for a candidate the researcher hasn't verified.
    var verificationDate: String?
    var verifiedBy: String?
    var publishedPitchPreference: String?
    var articles: [SeedArticle]

    func build() -> JournalistProfile {
        let outlet = Outlet(name: outlet, url: outletURL, verticals: outletVerticals ?? [])
        let profile = JournalistProfile(
            name: name,
            role: role,
            beatTopics: beatTopics,
            outlet: outlet,
            audiences: audiences ?? [],
            regions: regions ?? [],
            coveredAngles: coveredAngles ?? [],
            doNotPitch: []
        )
        let record = EditorialEvidenceRecord(
            provenance: ProvenanceType(rawValue: provenance) ?? .publicEditorialSignal,
            evidenceSummary: evidenceSummary,
            sourceURL: sourceURL,
            verificationDate: verificationDate.flatMap { JSONDecoder.seedDate.date(from: $0) },
            verifiedBy: verifiedBy,
            confidence: confidence.flatMap(EvidenceConfidence.init(rawValue:)) ?? .exploratory,
            pitchPreference: publishedPitchPreference
        )
        record.articles = articles.map { $0.build(outletName: outlet.name) }
        profile.evidenceRecords = [record]
        return profile
    }
}

struct SeedArticle: Decodable {
    var title: String
    var url: String
    var publishedAt: String?
    var topics: [String]?

    func build(outletName: String) -> CoverageEvidence {
        CoverageEvidence(
            title: title,
            url: url,
            publishedAt: publishedAt.flatMap { JSONDecoder.seedDate.date(from: $0) },
            topics: topics ?? [],
            outletName: outletName
        )
    }
}

private extension JSONDecoder {
    static let seed = JSONDecoder()
    /// The seed file uses plain `yyyy-MM-dd` dates.
    static let seedDate: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
