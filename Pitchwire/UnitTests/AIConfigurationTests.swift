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

    func testFromDictBlankOrMissingIsOffline() {
        XCTAssertFalse(AIConfiguration.from(dict: [:]).isConfigured)
        XCTAssertFalse(AIConfiguration.from(dict: ["BaseURL": "", "ClientToken": ""]).isConfigured)
        XCTAssertFalse(AIConfiguration.from(dict: ["BaseURL": "https://x"]).isConfigured)   // no token
        XCTAssertFalse(AIConfiguration.from(dict: ["ClientToken": "abc"]).isConfigured)     // no url
    }

    func testFromDictConfiguredWhenBothPresent() {
        let c = AIConfiguration.from(dict: [
            "BaseURL": "https://pitchwire-ai.example.workers.dev",
            "ClientToken": "tok_abc123",
        ])
        XCTAssertTrue(c.isConfigured)
        XCTAssertEqual(c.baseURL?.host, "pitchwire-ai.example.workers.dev")
    }
}
