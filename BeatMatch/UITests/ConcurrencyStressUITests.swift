import XCTest

/// Regression guard for the crash where `ExplanationEnricher` fanned out
/// concurrent AI calls that raced `LLMLog.entries` (SIGSEGV in
/// `_swift_release_dealloc`), plus the sibling bug where the enricher and the
/// pitch drafter read `@Model` properties off the main actor.
///
/// This drives the exact overlap: land on the match list (enrichment starts
/// against the live backend), then thrash navigation and kick off pitch drafts
/// while it is still running. If any of that is thread-unsafe the app dies here.
final class ConcurrencyStressUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func matchRows(_ app: XCUIApplication) -> XCUIElementQuery {
        // Match rows carry an evidence-state tag ("Demo" / "Candidate" / "Verified")
        // in their combined a11y label; the story card and honesty banner do not.
        app.collectionViews.firstMatch.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Demo", "Candidate"))
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testEnrichmentOverlapsNavigationAndDraftingWithoutCrashing() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["What's your story?"].waitForExistence(timeout: 5))
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(
            "Today we're launching an AI developer tools SDK for small teams shipping "
            + "machine learning features. Founder available for interviews."
        )
        app.buttons["Analyze"].tap()
        XCTAssertTrue(app.staticTexts["What we understood"].waitForExistence(timeout: 10))
        app.buttons["Find journalists"].tap()

        // Enrichment kicks off here.
        XCTAssertTrue(app.staticTexts["Excellent match"].waitForExistence(timeout: 10))
        let list = app.collectionViews.firstMatch

        // Thrash: open and back out of several rows fast while enrichment runs.
        for pass in 0..<3 {
            let rows = matchRows(app)
            for i in 0..<min(3, rows.count) {
                let row = rows.element(boundBy: i)
                guard row.exists else { continue }
                row.tap()
                _ = app.staticTexts["Why this match"].waitForExistence(timeout: 5)
                back(app)
            }
            if pass < 2 { list.swipeUp(); list.swipeDown() }
        }

        // Draft a pitch (concurrent backend call) while enrichment may still run.
        let firstRow = matchRows(app).firstMatch
        var tries = 0
        while !firstRow.exists && tries < 6 { list.swipeDown(); tries += 1 }
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()
        XCTAssertTrue(app.staticTexts["Why this match"].waitForExistence(timeout: 5))
        app.buttons["Draft pitch"].tap()
        XCTAssertTrue(app.buttons["View draft"].waitForExistence(timeout: 20))

        // Back to the list, open another, draft again.
        back(app)
        let anotherRow = matchRows(app).element(boundBy: 1)
        if anotherRow.waitForExistence(timeout: 5) {
            anotherRow.tap()
            _ = app.staticTexts["Why this match"].waitForExistence(timeout: 5)
            if app.buttons["Draft pitch"].exists {
                app.buttons["Draft pitch"].tap()
                _ = app.buttons["View draft"].waitForExistence(timeout: 20)
            }
        }

        // Still alive and responsive.
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }
}
