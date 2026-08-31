import XCTest

/// The human verification path: Profile → Research Lab → open a profile →
/// un-verify → attach an article → re-verify. DEBUG-only screen. The shipped
/// seed is already verified, so this exercises the round trip.
final class ResearchLabUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testResearcherCanUnverifyAttachEvidenceAndReverify() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        app.buttons["Profile"].tap()
        let lab = app.buttons["Research Lab"]
        var tries = 0
        while !lab.exists && tries < 6 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(lab.waitForExistence(timeout: 5))
        lab.tap()
        XCTAssertTrue(app.navigationBars["Research Lab"].waitForExistence(timeout: 5))

        // Open the first verified profile.
        let firstRow = app.descendants(matching: .any)
            .matching(identifier: "lab-row-verified").firstMatch
        var d = 0
        while !firstRow.isHittable && d < 6 { app.swipeUp(); d += 1 }
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()

        // Un-verify → back to candidate.
        let unverify = app.buttons["Un-verify (back to candidate)"]
        var u = 0
        while !unverify.isHittable && u < 8 { app.swipeUp(); u += 1 }
        XCTAssertTrue(unverify.waitForExistence(timeout: 5))
        unverify.tap()

        // Attach an article.
        let addArticle = app.buttons["Add article"]
        var s = 0
        while !addArticle.isHittable && s < 8 { app.swipeUp(); s += 1 }
        XCTAssertTrue(addArticle.waitForExistence(timeout: 5))
        addArticle.tap()

        let headline = app.textFields["Headline (as published)"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        headline.tap(); headline.typeText("A recent on-topic piece")
        let urlField = app.textFields["URL (https://…)"]
        urlField.tap(); urlField.typeText("https://example.com/article")
        app.buttons["Add"].tap()

        // Reviewer + re-verify.
        let reviewer = app.textFields["Reviewer (your initials)"]
        var r = 0
        while !reviewer.isHittable && r < 8 { app.swipeUp(); r += 1 }
        XCTAssertTrue(reviewer.waitForExistence(timeout: 5))
        if (reviewer.value as? String ?? "").isEmpty { reviewer.tap(); reviewer.typeText("QA") }
        let verify = app.buttons["Verify this profile"]
        XCTAssertTrue(verify.waitForExistence(timeout: 5))
        verify.tap()

        XCTAssertTrue(app.staticTexts["Verified"].waitForExistence(timeout: 5),
                      "profile should read as verified again")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "research-lab-verified"; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
