import XCTest
@testable import Pitchwire

final class AIConfigurationTests: XCTestCase {

    func testOfflineIsNotConfigured() {
        XCTAssertFalse(AIConfiguration.offline.isConfigured)
    }

    func testBlankValuesAreTreatedAsOffline() {
        let blank = AIConfiguration(baseURL: URL(string: ""), clientToken: "")
        XCTAssertFalse(blank.isConfigured)
        let tokenOnly = AIConfiguration(baseURL: nil, clientToken: "abc")
        XCTAssertFalse(tokenOnly.isConfigured)
    }

    func testConfiguredWhenBothPresent() {
        let c = AIConfiguration(baseURL: URL(string: "https://pitchwire-ai.example.workers.dev"),
                                clientToken: "tok_abc123")
        XCTAssertTrue(c.isConfigured)
    }

    func testFromBundleFallsBackToOfflineWhenNoRealPlist() {
        // The test bundle has no AIConfig.plist (only AIConfig.example.plist ships,
        // and it has blank values) → must be offline, never a half-configured state.
        let c = AIConfiguration.fromBundle(.main)
        XCTAssertFalse(c.isConfigured)
    }
}
