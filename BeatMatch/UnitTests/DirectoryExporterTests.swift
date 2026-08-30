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
            FollowUpTask.self, RemovalRequest.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    func testExportRoundTripsVerificationAndDropsRejected() throws {
        let ctx = try context()
        JournalistDirectory.ensureSeeded(ctx)
        let all = JournalistDirectory.all(ctx)
        XCTAssertGreaterThanOrEqual(all.count, 3)

        // Verify one, reject another.
        let verified = all[0]
        _ = LabActions.addArticle(to: verified, title: "A verified piece",
                                  url: "https://example.com/x",
                                  publishedAt: SeedDate.string.date(from: "2026-07-15"),
                                  topics: ["ai"], context: ctx)
        XCTAssertTrue(LabActions.verify(verified, reviewer: "DJ", confidence: .high, context: ctx))
        LabActions.reject(all[1], context: ctx)

        let json = DirectoryExporter.json(for: JournalistDirectory.all(ctx), reviewer: "DJ")
        XCTAssertFalse(json.contains(all[1].name), "rejected profile must be dropped from the export")

        // Round-trip: decode and rebuild.
        let file = try JSONDecoder().decode(SeedFile.self, from: Data(json.utf8))
        XCTAssertEqual(file.profiles.count, all.count - 1)

        let exported = file.profiles.first { $0.name == verified.name }
        XCTAssertNotNil(exported)
        XCTAssertEqual(exported?.verificationDate, SeedDate.string.string(from: Date()))
        XCTAssertEqual(exported?.verifiedBy, "DJ")
        XCTAssertEqual(exported?.confidence, "high")
        XCTAssertEqual(exported?.articles.first?.url, "https://example.com/x")
        XCTAssertEqual(exported?.articles.first?.publishedAt, "2026-07-15")

        let rebuilt = exported!.build()
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
