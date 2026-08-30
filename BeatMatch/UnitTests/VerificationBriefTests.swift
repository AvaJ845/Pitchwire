import XCTest
@testable import Pitchwire

final class VerificationBriefTests: XCTestCase {

    func testParsesLabelledBlocks() {
        let raw = """
        CHECKS:
        - Author page still lists them on the AI beat
        - A byline in the last 60 days
        - Bio still says WIRED

        SEARCHES:
        - "Jane Doe" WIRED AI model launch
        - site:wired.com "Jane Doe" 2026
        """
        let b = VerificationBriefService.parse(raw)
        XCTAssertEqual(b.checks.count, 3)
        XCTAssertEqual(b.searches.count, 2)
        XCTAssertTrue(b.checks[0].contains("AI beat"))
        XCTAssertTrue(b.searches[1].contains("site:wired.com"))
        XCTAssertFalse(b.isEmpty)
    }

    func testToleratesMarkdownAndNumbering() {
        let raw = """
        **Checks**
        1. Still at the outlet
        2) Recent on-topic work
        ## Searches
        * "Jane Doe" fintech launch
        """
        let b = VerificationBriefService.parse(raw)
        XCTAssertEqual(b.checks, ["Still at the outlet", "Recent on-topic work"])
        XCTAssertEqual(b.searches, ["\"Jane Doe\" fintech launch"])
    }

    func testEmptyWhenUnstructured() {
        XCTAssertTrue(VerificationBriefService.parse("just a paragraph of prose, no labels").isEmpty)
    }
}
