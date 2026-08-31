import XCTest

/// The DEBUG-only developer LLM log is reachable from Profile.
final class DebugLogUITests: XCTestCase {

    func testDeveloperLogIsReachableFromProfile() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-mock-ai"]
        app.launch()

        app.tabBars.buttons["Profile"].tap()

        let list = app.collectionViews.firstMatch

        func scrollTo(_ element: XCUIElement, _ label: String) {
            var tries = 0
            while !element.exists && tries < 12 {
                list.swipeUp()
                tries += 1
            }
            XCTAssertTrue(element.exists, label)
        }

        XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Default model"].exists, "no model name in user-facing UI")

        let logLink = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "LLM log")).firstMatch
        scrollTo(logLink, "Developer / LLM log row should be in Profile (DEBUG)")
        XCTAssertTrue(app.switches["Capture LLM logs"].exists)

        let payloadSwitch = app.switches["Capture prompts & responses"]
        scrollTo(payloadSwitch, "payload capture toggle should be in Profile (DEBUG)")
        XCTAssertEqual(payloadSwitch.value as? String, "0", "payload capture defaults off")

        let profileShot = XCTAttachment(screenshot: app.screenshot())
        profileShot.name = "07-profile"
        profileShot.lifetime = .keepAlways
        add(profileShot)

        logLink.tap()
        XCTAssertTrue(app.navigationBars["LLM log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No LLM failures"].exists || app.switches["Failures only"].exists)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "06-debug-llm-log"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
