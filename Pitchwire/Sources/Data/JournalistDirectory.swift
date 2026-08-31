import Foundation
import SwiftData

/// The persistent journalist directory — the pool matching scores against and the
/// Research Lab curates. Seeded once from `editorial_seed.json` (candidates); a
/// researcher's verify / reject / edit decisions live here and apply to every
/// campaign.
@MainActor
enum JournalistDirectory {

    /// Import the seed set as candidates if the directory is empty. Idempotent.
    @discardableResult
    static func ensureSeeded(_ context: ModelContext) -> Int {
        let count = (try? context.fetchCount(FetchDescriptor<JournalistProfile>())) ?? 0
        guard count == 0 else { return count }

        for profile in EditorialSeedLoader.seedPool() {
            context.insert(profile)
            if let outlet = profile.outlet { context.insert(outlet) }
            for record in profile.evidenceRecords {
                context.insert(record)
                for article in record.articles { context.insert(article) }
            }
        }
        try? context.save()
        return (try? context.fetchCount(FetchDescriptor<JournalistProfile>())) ?? 0
    }

    /// Everything a researcher can act on.
    static func all(_ context: ModelContext) -> [JournalistProfile] {
        (try? context.fetch(FetchDescriptor<JournalistProfile>(
            sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    /// The pool matching is allowed to use — rejected profiles are excluded.
    static func matchable(_ context: ModelContext) -> [JournalistProfile] {
        all(context).filter { !$0.isRejected }
    }
}

/// Every state change a researcher makes in the Lab, as pure model mutations so
/// they can be unit-tested. **AI never calls these** — they are the human step.
/// Each one appends an `AuditEntry` so there's a record of who verified what.
@MainActor
enum LabActions {

    private static func audit(_ action: String, _ subject: String, by reviewer: String,
                              _ detail: String = "", into context: ModelContext) {
        context.insert(AuditEntry(action: action, subject: subject, reviewer: reviewer, detail: detail))
    }

    /// Attach one real article. Requires a title and an https URL — the researcher
    /// found it by opening the profile's `sourceURL`.
    @discardableResult
    static func addArticle(
        to profile: JournalistProfile,
        title: String, url: String, publishedAt: Date?, topics: [String],
        context: ModelContext, reviewer: String = ""
    ) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, u.hasPrefix("https://"), let record = profile.primaryEvidence else { return false }
        let article = CoverageEvidence(title: t, url: u, publishedAt: publishedAt,
                                       topics: topics, outletName: profile.outlet?.name)
        context.insert(article)
        article.record = record
        record.articles.append(article)
        audit("article +", profile.name, by: reviewer, t, into: context)
        try? context.save()
        return true
    }

    static func removeArticle(_ article: CoverageEvidence, context: ModelContext, reviewer: String = "") {
        let subject = article.record?.profile?.name ?? "—"
        let title = article.title
        context.delete(article)
        audit("article −", subject, by: reviewer, title, into: context)
        try? context.save()
    }

    /// Mark a candidate verified. Fails without ≥1 article and a reviewer name —
    /// a verification must be attributable, and AI-only claims are not evidence.
    @discardableResult
    static func verify(
        _ profile: JournalistProfile,
        reviewer: String, confidence: EvidenceConfidence,
        context: ModelContext
    ) -> Bool {
        let who = reviewer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !who.isEmpty,
              let record = profile.primaryEvidence,
              !record.articles.isEmpty
        else { return false }
        record.verificationDate = Date()
        record.verifiedBy = who
        record.confidence = confidence
        profile.isRejected = false
        audit("verify", profile.name, by: who,
              "\(record.articles.count) articles · \(confidence.label)", into: context)
        try? context.save()
        return true
    }

    static func unverify(_ profile: JournalistProfile, context: ModelContext, reviewer: String = "") {
        guard let record = profile.primaryEvidence else { return }
        record.verificationDate = nil
        record.verifiedBy = nil
        audit("un-verify", profile.name, by: reviewer, into: context)
        try? context.save()
    }

    static func reject(_ profile: JournalistProfile, context: ModelContext, reviewer: String = "") {
        profile.isRejected = true
        if let record = profile.primaryEvidence {
            record.verificationDate = nil
            record.verifiedBy = nil
        }
        audit("reject", profile.name, by: reviewer, "excluded from matching", into: context)
        try? context.save()
    }

    static func restore(_ profile: JournalistProfile, context: ModelContext, reviewer: String = "") {
        profile.isRejected = false
        audit("restore", profile.name, by: reviewer, into: context)
        try? context.save()
    }

    /// Only when the journalist has confirmed (e.g. by email) that they claimed
    /// this profile — a self-serve claim flow needs accounts, which don't exist yet.
    static func markClaimed(_ profile: JournalistProfile, reviewer: String, context: ModelContext) {
        guard let record = profile.primaryEvidence else { return }
        record.provenance = .claimedProfile
        record.verifiedBy = reviewer.trimmingCharacters(in: .whitespacesAndNewlines)
        record.verificationDate = Date()
        audit("claim", profile.name, by: reviewer, "provenance → CLAIMED_PROFILE", into: context)
        try? context.save()
    }

    static func resolveRemoval(_ request: RemovalRequest, resolution: String,
                               context: ModelContext, reviewer: String = "") {
        request.resolvedAt = Date()
        request.resolution = resolution
        audit("removal resolved", request.journalistName, by: reviewer, resolution, into: context)
        try? context.save()
    }
}
