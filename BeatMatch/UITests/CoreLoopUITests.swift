import XCTest

/// Smoke test for the North Star loop: paste story -> "what we understood"
/// confirmation -> Find journalists -> confidence-tiered matches -> journalist
/// detail (why this match + about-this-profile provenance) -> Draft pitch ->
/// editable draft.
final class CoreLoopUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testAnalyzeToDraftLoop() {
        let app = XCUIApplication()
        app.launch()

        // Home intake
        XCTAssertTrue(app.staticTexts["What's your story?"].waitForExistence(timeout: 5))

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(
            "Today we're launching an AI developer tools SDK that helps small teams "
            + "ship machine learning features fast. Founder available for interviews."
        )

        snap(app, "01-home-intake")
        app.buttons["Analyze"].tap()

        // Screen 2 — confirm understanding, then proceed
        XCTAssertTrue(app.staticTexts["What we understood"].waitForExistence(timeout: 10))
        snap(app, "02-story-summary")
        app.buttons["Find journalists"].tap()

        // Match list — deterministic seed data puts Morgan Ito in the top tier
        XCTAssertTrue(app.staticTexts["Excellent match"].waitForExistence(timeout: 10))
        snap(app, "03-match-list")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Morgan Ito")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        // Detail: "why this match" + provenance are non-negotiable per the brief
        XCTAssertTrue(app.staticTexts["Why this match"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["About this profile"].exists)
        snap(app, "04-journalist-detail")

        // Draft pitch
        app.buttons["Draft pitch"].tap()
        let viewDraft = app.buttons["View draft"]
        XCTAssertTrue(viewDraft.waitForExistence(timeout: 10))
        viewDraft.tap()

        // Editable draft screen
        XCTAssertTrue(app.navigationBars["Pitch draft"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Subject"].exists)
        XCTAssertTrue(app.switches["Marked as sent"].exists)
        snap(app, "05-pitch-draft")
    }
}
