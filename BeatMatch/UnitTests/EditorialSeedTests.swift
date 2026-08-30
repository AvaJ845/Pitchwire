import XCTest
@testable import Pitchwire

/// Guards the shipped `editorial_seed.json` against drift from the spec:
/// candidates only, no contact data, every claim traceable to a source.
final class EditorialSeedTests: XCTestCase {

    private func loadFile() throws -> SeedFile {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "editorial_seed", withExtension: "json"),
                                "editorial_seed.json must be bundled")
        return try JSONDecoder().decode(SeedFile.self, from: Data(contentsOf: url))
    }

    func testSeedIsAGoldStandardEvalSet_notADatabase() throws {
        let file = try loadFile()
        XCTAssertGreaterThanOrEqual(file.profiles.count, 20, "the eval set is ~25 records")
        XCTAssertLessThanOrEqual(file.profiles.count, 30, "not the start of a mass database")
    }

    func testNothingIsVerifiedAndEverythingIsTraceable() throws {
        for p in try loadFile().profiles {
            XCTAssertNil(p.verificationDate, "\(p.name): AI cannot verify — must be null")
            XCTAssertNil(p.verifiedBy, "\(p.name): no human reviewer yet")
            XCTAssertEqual(p.provenance, "PUBLIC_EDITORIAL_SIGNAL", "\(p.name)")
            XCTAssertEqual(p.confidence, "exploratory", "\(p.name): unverified never presents higher")
            let src = try XCTUnwrap(p.sourceURL, "\(p.name): every record needs a traceable source")
            XCTAssertTrue(src.hasPrefix("https://"), "\(p.name): source must be a real URL")
            XCTAssertFalse(p.evidenceSummary.trimmingCharacters(in: .whitespaces).isEmpty, "\(p.name)")
            XCTAssertFalse(p.beatTopics.isEmpty, "\(p.name)")
        }
    }

    /// The JSON must carry no field that looks like personal contact data — the
    /// product does not hold this, and the schema must not tempt a future editor.
    func testRawJSONContainsNoContactData() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "editorial_seed", withExtension: "json"))
        let raw = try String(contentsOf: url, encoding: .utf8).lowercased()
        // Contact-data field names (as JSON keys) and address schemes.
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

    func testLoaderBuildsUnverifiedCandidates() throws {
        let profiles = try EditorialSeedLoader.load()
        XCTAssertGreaterThanOrEqual(profiles.count, 20)
        for j in profiles {
            XCTAssertTrue(j.isUnverifiedCandidate, "\(j.name) must read as a candidate")
            XCTAssertFalse(j.isVerified)
            XCTAssertFalse(j.isFictional)
            XCTAssertEqual(j.evidenceState, .candidate)
            XCTAssertEqual(j.evidenceConfidence, .exploratory)
            XCTAssertNotNil(j.outlet)
            XCTAssertNotNil(j.primaryEvidence?.sourceURL)
        }
    }
}
