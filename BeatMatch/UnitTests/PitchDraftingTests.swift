import XCTest
@testable import Pitchwire

final class PitchDraftingTests: XCTestCase {

    func testParsesCleanLabels() {
        let d = DefaultPitchDraftingService.parse(
            "SUBJECT: New tool launches\nSHORT: A short pitch here.\nLONG: A longer pitch.\nMore detail.")
        XCTAssertEqual(d?.subject, "New tool launches")
        XCTAssertEqual(d?.shortBody, "A short pitch here.")
        XCTAssertEqual(d?.longBody, "A longer pitch.\nMore detail.")
    }

    func testStripsMarkdownWrappedLabels() {
        let text = """
        **SUBJECT:** New AI SDK launches today

        **SHORT:** Today we're releasing an AI SDK for small teams.

        **LONG:**
        Hi Dana, I'm reaching out because you cover dev tools.
        The SDK ships today.
        """
        let d = DefaultPitchDraftingService.parse(text)
        XCTAssertEqual(d?.subject, "New AI SDK launches today")
        XCTAssertFalse(d?.subject.contains("*") ?? true)
        XCTAssertTrue(d?.shortBody.contains("small teams") ?? false)
        XCTAssertFalse(d?.shortBody.contains("LONG") ?? true)
        XCTAssertTrue(d?.longBody.contains("cover dev tools") ?? false)
    }

    func testReturnsNilWhenLabelsAreMissing() {
        XCTAssertNil(DefaultPitchDraftingService.parse("Just a blob of pitch text with no structure."))
        XCTAssertNil(DefaultPitchDraftingService.parse("SUBJECT: only a subject, nothing else"))
    }

    func testHandlesLowercaseAndHeadingMarkers() {
        let d = DefaultPitchDraftingService.parse("### Subject: Hi\nshort: quick note\n## long: the details")
        XCTAssertEqual(d?.subject, "Hi")
        XCTAssertEqual(d?.shortBody, "quick note")
        XCTAssertEqual(d?.longBody, "the details")
    }
}
