import XCTest
import SwiftData
@testable import Pitchwire

@MainActor
final class DirectoryExporterTests: XCTestCase {

    private func context() throws -> ModelContext {
        let schema = Schema([
            Story.self, Campaign.self, MediaTarget.self, Outlet.self,
            JournalistProfile.self, MatchExplanation.self, PitchDraft.self,
            EditorialEvidenceRecord.self, CoverageEvidence.self,
            FollowUpTask.self, RemovalRequest.self, AuditEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func freshCandidate(_ ctx: ModelContext, name: String) -> JournalistProfile {
        let p = JournalistProfile(name: name, beatTopics: ["ai"],
                                  outlet: Outlet(name: "Outlet Z"), vertical: "ai-dev-tools")
        let r = EditorialEvidenceRecord(provenance: .publicEditorialSignal,
                                        evidenceSummary: "candidate", sourceURL: "https://z/author")
        p.evidenceRecords = [r]
        ctx.insert(p); ctx.insert(r); ctx.insert(p.outlet!)
        try? ctx.save()
        return p
    }

    func testExportRoundTripsVerificationAndDropsRejected() throws {
        let ctx = try context()
        let keep = freshCandidate(ctx, name: "Aaa Keeper")
        let drop = freshCandidate(ctx, name: "Zzz Dropped")

        XCTAssertTrue(LabActions.addArticle(to: keep, title: "A verified piece",
                                            url: "https://example.com/x",
                                            publishedAt: SeedDate.string.date(from: "2026-07-15"),
                                            topics: ["ai"], context: ctx))
        XCTAssertTrue(LabActions.verify(keep, reviewer: "DJ", confidence: .high, context: ctx))
        LabActions.reject(drop, context: ctx)

        let all = JournalistDirectory.all(ctx)
        let json = DirectoryExporter.json(for: all, reviewer: "DJ")
        XCTAssertFalse(json.contains("Zzz Dropped"), "rejected profile must be dropped from the export")

        let file = try JSONDecoder().decode(SeedFile.self, from: Data(json.utf8))
        XCTAssertEqual(file.profiles.count, all.filter { !$0.isRejected }.count)

        let exported = try XCTUnwrap(file.profiles.first { $0.name == "Aaa Keeper" })
        XCTAssertEqual(exported.verificationDate, SeedDate.string.string(from: Date()))
        XCTAssertEqual(exported.verifiedBy, "DJ")
        XCTAssertEqual(exported.confidence, "high")
        XCTAssertEqual(exported.articles.first?.url, "https://example.com/x")
        XCTAssertEqual(exported.articles.first?.publishedAt, "2026-07-15")

        let rebuilt = exported.build()
        XCTAssertTrue(rebuilt.isVerified)
        XCTAssertEqual(rebuilt.evidenceConfidence, .high)
    }

    func testExportHasNoContactFieldNames() throws {
        let ctx = try context()
        JournalistDirectory.ensureSeeded(ctx)
        let json = DirectoryExporter.json(for: JournalistDirectory.all(ctx), reviewer: "DJ").lowercased()
        for banned in ["\"email\"", "\"phone\"", "\"signal\"", "\"twitter\"", "mailto:"] {
            XCTAssertFalse(json.contains(banned), "export must not introduce \(banned)")
        }
    }
}
