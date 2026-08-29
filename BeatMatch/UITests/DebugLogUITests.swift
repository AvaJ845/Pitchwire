import XCTest

/// The DEBUG-only developer LLM log is reachable from Profile.
final class DebugLogUITests: XCTestCase {

    func testDeveloperLogIsReachableFromProfile() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Profile"].tap()

        let list = app.collectionViews.firstMatch
        let logLink = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "LLM log")).firstMatch
        var tries = 0
        while !logLink.exists && tries < 8 {
            list.swipeUp()
            tries += 1
        }
        XCTAssertTrue(logLink.exists, "Developer / LLM log row should be in Profile (DEBUG)")
        XCTAssertTrue(app.switches["Capture LLM logs"].exists)

        logLink.tap()
        XCTAssertTrue(app.navigationBars["LLM log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No LLM failures"].exists || app.switches["Failures only"].exists)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "06-debug-llm-log"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
