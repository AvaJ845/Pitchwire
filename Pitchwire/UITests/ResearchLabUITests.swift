import XCTest

/// The human verification path is wired: Profile → Research Lab → open a
/// verified profile → un-verify → re-verify. DEBUG-only screen. The article-
/// attach + validation rules are covered by ResearchLabTests (unit); this test
/// proves the screen is reachable and the state round-trips in the UI.
final class ResearchLabUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testResearcherCanUnverifyAndReverify() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-mock-ai"]
        app.launch()

        app.buttons["Profile"].tap()
        let lab = app.buttons["Research Lab"]
        var tries = 0
        while !lab.exists && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(lab.waitForExistence(timeout: 5))
        lab.tap()
        XCTAssertTrue(app.navigationBars["Research Lab"].waitForExistence(timeout: 5))

        // Open the first verified profile.
        let firstRow = app.descendants(matching: .any)
            .matching(identifier: "lab-row-verified").firstMatch
        var d = 0
        while !firstRow.isHittable && d < 8 { app.swipeUp(); d += 1 }
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()

        // Un-verify → back to candidate. (The seed profile keeps its articles,
        // so re-verifying later only needs a reviewer name.)
        let unverify = app.buttons["Un-verify (back to candidate)"]
        scrollToHittable(unverify, in: app)
        XCTAssertTrue(unverify.waitForExistence(timeout: 5))
        unverify.tap()

        // "Verify this profile" only renders when the profile is not verified —
        // its appearance is the signal that un-verify worked.
        let verify = app.buttons["Verify this profile"]
        scrollToHittable(verify, in: app)
        XCTAssertTrue(verify.waitForExistence(timeout: 5),
                      "the Verify button should appear after un-verifying")

        // Reviewer + re-verify. `-uitest-reset` clears lab.reviewer.
        let reviewer = app.textFields["Reviewer (your initials)"]
        scrollToHittable(reviewer, in: app)
        XCTAssertTrue(reviewer.waitForExistence(timeout: 5))
        reviewer.tap()
        reviewer.typeText("QA")

        XCTAssertTrue(waitUntilEnabled(verify, timeout: 15),
                      "Verify should enable once there's a reviewer (articles are still attached)")
        verify.tap()

        XCTAssertTrue(app.staticTexts["Verified"].waitForExistence(timeout: 10),
                      "profile should read as verified again")

        // The action left an audit trail — go back to the Lab and check.
        app.navigationBars.buttons.firstMatch.tap()
        let history = app.staticTexts["History"]
        var h = 0
        while !history.exists && h < 10 { app.swipeUp(); h += 1 }
        XCTAssertTrue(history.exists, "the Lab should show a History section after a verify")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "research-lab-history"; attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var n = 0
        while !element.isHittable && n < 8 { app.swipeUp(); n += 1 }
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isEnabled { return true }
            usleep(200_000)
        }
        return element.exists && element.isEnabled
    }
}
