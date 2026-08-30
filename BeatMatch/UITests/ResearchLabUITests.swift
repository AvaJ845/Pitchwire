import XCTest

/// The human verification path: Profile → Research Lab → open a candidate →
/// attach a real article → verify. DEBUG-only screen.
final class ResearchLabUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testResearcherCanAttachEvidenceAndVerifyACandidate() {
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

        // Open the first candidate.
        let firstCandidate = app.descendants(matching: .any)
            .matching(identifier: "lab-row-candidates").firstMatch
        XCTAssertTrue(firstCandidate.waitForExistence(timeout: 5))
        firstCandidate.tap()

        // Attach an article (the button is below the beat/fit section — scroll to it).
        let addArticle = app.buttons["Add article"]
        var s = 0
        while !addArticle.isHittable && s < 6 { app.swipeUp(); s += 1 }
        XCTAssertTrue(addArticle.waitForExistence(timeout: 5))
        addArticle.tap()

        let headline = app.textFields["Headline (as published)"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        headline.tap(); headline.typeText("A recent on-topic piece")
        let urlField = app.textFields["URL (https://…)"]
        urlField.tap(); urlField.typeText("https://example.com/article")
        app.buttons["Add"].tap()

        // Set reviewer + verify (scroll down to the Verify section).
        let reviewer = app.textFields["Reviewer (your initials)"]
        var r = 0
        while !reviewer.isHittable && r < 6 { app.swipeUp(); r += 1 }
        XCTAssertTrue(reviewer.waitForExistence(timeout: 5))
        reviewer.tap(); reviewer.typeText("DJ")
        let verify = app.buttons["Verify this profile"]
        XCTAssertTrue(verify.waitForExistence(timeout: 5))
        verify.tap()

        XCTAssertTrue(app.staticTexts["Verified"].waitForExistence(timeout: 5),
                      "profile should now read as verified")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "research-lab-verified"; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
