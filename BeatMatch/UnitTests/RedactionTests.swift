import XCTest
@testable import Pitchwire

final class RedactionTests: XCTestCase {

    func testRedactsBearerTokens() {
        let input = "AIGatewayError.server: GET /v1/generate Authorization: Bearer sk_live_abcDEF123456gh... 401"
        let out = Redaction.redact(input)
        XCTAssertFalse(out.contains("abcDEF123456"))
        XCTAssertTrue(out.contains("Bearer ‹redacted›"))
    }

    func testRedactsProviderKeyShapes() {
        XCTAssertFalse(Redaction.redact("key=nvapi-0123456789abcdef").contains("0123456789abcdef"))
        XCTAssertFalse(Redaction.redact("using sk-proj-ABCDEFGHIJKLMNOP now").contains("ABCDEFGHIJKLMNOP"))
        XCTAssertFalse(Redaction.redact("api_key: ZAI_0123456789ABCDEF").contains("0123456789ABCDEF"))
    }

    func testRedactsRegisteredExactSecret() {
        Redaction.register("tok_this_is_the_client_token_9f2a")
        let out = Redaction.redact("transport error for tok_this_is_the_client_token_9f2a on retry")
        XCTAssertFalse(out.contains("tok_this_is_the_client_token_9f2a"))
        XCTAssertTrue(out.contains("‹redacted›"))
    }

    func testLeavesOrdinaryTextAlone() {
        let input = "storyAnalysis tier=fast 812ms cached=false ok"
        XCTAssertEqual(Redaction.redact(input), input)
    }

    func testLLMLogRedactsEntryDetail() {
        let log = LLMLog(defaults: UserDefaults(suiteName: "t.\(UUID())")!)
        log.isCapturing = true
        log.record(.init(task: "pitchDraft", tier: "quality", provider: "glm",
                         latencyMS: 10, cached: false, outcome: .failed,
                         detail: "401 Authorization: Bearer secret_KEY_value_123456"))
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertFalse(log.entries[0].detail!.contains("secret_KEY_value_123456"))
    }
}
