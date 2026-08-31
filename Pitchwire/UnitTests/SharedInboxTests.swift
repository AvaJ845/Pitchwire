import XCTest
@testable import Pitchwire

final class SharedInboxTests: XCTestCase {

    override func tearDown() {
        _ = SharedInbox.take()   // leave nothing behind
        super.tearDown()
    }

    func testStashThenTakeReturnsOnceThenClears() {
        SharedInbox.stash("We're launching an on-device AI eval framework today.")
        XCTAssertTrue(SharedInbox.hasPending)

        let first = SharedInbox.take()
        XCTAssertEqual(first, "We're launching an on-device AI eval framework today.")

        XCTAssertNil(SharedInbox.take(), "a second take is empty — the story is consumed")
        XCTAssertFalse(SharedInbox.hasPending)
    }

    func testBlankIsIgnoredAndLongTextIsCapped() {
        SharedInbox.stash("   \n  ")
        XCTAssertNil(SharedInbox.take())

        SharedInbox.stash(String(repeating: "x", count: 20_000))
        let stored = SharedInbox.take()
        XCTAssertEqual(stored?.count, 8_000)
    }
}
