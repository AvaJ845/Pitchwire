import XCTest
@testable import Pitchwire

/// Guards the shipped `editorial_seed.json`: human-verified, no contact data,
/// every claim traceable to a source, a curated set — not a database.
///
/// The real seed is git-ignored (real people, real notes — not for a public
/// repo), so these skip on CI / a fresh clone and run on the operator's machine
/// where the file is present.
final class EditorialSeedTests: XCTestCase {

    private func seedURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "editorial_seed", withExtension: "json") else {
            throw XCTSkip("editorial_seed.json not bundled — falls back to the fictional pool")
        }
        return url
    }

    private func loadFile() throws -> SeedFile {
        try JSONDecoder().decode(SeedFile.self, from: Data(contentsOf: seedURL()))
    }

    func testSeedIsACuratedSet_notADatabase() throws {
        let file = try loadFile()
        XCTAssertGreaterThanOrEqual(file.profiles.count, 15, "the eval set")
        XCTAssertLessThanOrEqual(file.profiles.count, 40, "not the start of a mass database")
    }

    func testEveryRecordIsHumanVerifiedAndTraceable() throws {
        for p in try loadFile().profiles {
            // Verified by a person, with a date and a name.
            let date = try XCTUnwrap(p.verificationDate, "\(p.name): shipped seed is human-verified")
            XCTAssertNotNil(SeedDate.string.date(from: date), "\(p.name): verificationDate must be yyyy-MM-dd")
            XCTAssertFalse((p.verifiedBy ?? "").trimmingCharacters(in: .whitespaces).isEmpty,
                           "\(p.name): a verification needs a reviewer")

            XCTAssertTrue(["PUBLIC_EDITORIAL_SIGNAL", "CLAIMED_PROFILE"].contains(p.provenance), "\(p.name)")
            let src = try XCTUnwrap(p.sourceURL, "\(p.name): every record needs a traceable source")
            XCTAssertTrue(src.hasPrefix("https://"), "\(p.name): source must be a real URL")
            XCTAssertFalse(p.evidenceSummary.trimmingCharacters(in: .whitespaces).isEmpty, "\(p.name)")
            XCTAssertFalse(p.beatTopics.isEmpty, "\(p.name)")

            // At least one dated article, each with a real URL.
            XCTAssertFalse(p.articles.isEmpty, "\(p.name): a verified record has article evidence")
            for a in p.articles {
                XCTAssertTrue(a.url.hasPrefix("https://"), "\(p.name): article URL must be real — \(a.title)")
                XCTAssertFalse(a.title.trimmingCharacters(in: .whitespaces).isEmpty, "\(p.name): empty title")
                if let d = a.publishedAt {
                    XCTAssertNotNil(SeedDate.string.date(from: d), "\(p.name): article date must be yyyy-MM-dd")
                }
            }
        }
    }

    /// The JSON must carry no field that looks like personal contact data.
    func testRawJSONContainsNoContactData() throws {
        let raw = try String(contentsOf: seedURL(), encoding: .utf8).lowercased()
        for banned in ["\"email\":", "\"phone\":", "\"phonenumber\":", "\"mobile\":", "\"cell\":",
                       "\"signal\":", "\"telegram\":", "\"whatsapp\":", "\"twitter\":", "\"x\":",
                       "\"linkedin\":", "\"instagram\":", "\"mastodon\":", "\"bluesky\":",
                       "\"dm\":", "\"handle\":", "\"contact\":", "\"address\":", "mailto:", "tel:"] {
            XCTAssertFalse(raw.contains(banned), "editorial_seed.json must not contain \(banned)")
        }
    }

    func testEveryVerticalIsRepresented() throws {
        let verticals = Set(try loadFile().profiles.compactMap(\.vertical))
        XCTAssertEqual(verticals, ["ai-dev-tools", "privacy-security",
                                   "fintech-personal-finance", "indie-ios-consumer"])
    }

    func testLoaderBuildsVerifiedProfiles() throws {
        _ = try seedURL()   // skip when the real seed isn't bundled
        let profiles = try EditorialSeedLoader.load()
        XCTAssertGreaterThanOrEqual(profiles.count, 15)
        for j in profiles {
            XCTAssertTrue(j.isVerified, "\(j.name) is human-verified")
            XCTAssertFalse(j.isUnverifiedCandidate)
            XCTAssertFalse(j.isFictional)
            XCTAssertFalse(j.isRejected, "rejected records are dropped on export")
            XCTAssertEqual(j.evidenceState, .verified)
            XCTAssertNotNil(j.outlet)
            XCTAssertNotNil(j.primaryEvidence?.sourceURL)
            XCTAssertFalse(j.allCoverage.isEmpty, "\(j.name) has article evidence")
        }
    }
}
