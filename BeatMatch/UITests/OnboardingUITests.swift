import XCTest

/// First-launch intro: shown once, honest about what Pitchwire is and isn't,
/// and dismissible. Every other UI test passes `-uitest-reset` (which skips it);
/// this one opts back in with `-uitest-onboarding`.
final class OnboardingUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testOnboardingRunsThroughToTheApp() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-onboarding", "-uitest-mock-ai"]
        app.launch()

        XCTAssertTrue(app.staticTexts["An AI press agent in your pocket"].waitForExistence(timeout: 5))

        // Advance through the informational pages.
        for _ in 0..<3 {
            app.buttons["Continue"].tap()
        }

        // The honesty page must actually be shown.
        XCTAssertTrue(app.staticTexts["Research, not a mailing list"].exists
                      || app.staticTexts["Yours, on your device"].exists)

        app.buttons["Get started"].tap()

        // Lands on the story intake, and onboarding does not return.
        XCTAssertTrue(app.staticTexts["What's your story?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Get started"].exists)
    }

    func testOnboardingCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-onboarding", "-uitest-mock-ai"]
        app.launch()

        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.staticTexts["What's your story?"].waitForExistence(timeout: 5))
    }
}
