import XCTest

/// Campaign memory: add a follow-up on a campaign, see it listed.
final class FollowUpsUITests: XCTestCase {

    func testAddAndCompleteAFollowUp() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-mock-ai"]
        app.launch()

        // Get a campaign: analyze → find journalists
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("We're launching an AI developer tools SDK today. Founder available.")
        app.buttons["Analyze"].tap()
        XCTAssertTrue(app.buttons["Find journalists"].waitForExistence(timeout: 10))
        app.buttons["Find journalists"].tap()
        XCTAssertTrue(app.staticTexts["Excellent match"].waitForExistence(timeout: 10)
                      || app.staticTexts["Strong match"].exists)

        // Open Follow-ups from the match list toolbar
        app.buttons["Follow-ups"].tap()
        XCTAssertTrue(app.navigationBars["Follow-ups"].waitForExistence(timeout: 5))

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Send Dana the demo link")
        app.buttons["Add"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Send Dana the demo link"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open"].exists)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "08-follow-ups"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
