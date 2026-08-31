import XCTest
@testable import Pitchwire

private struct FakeGateway: AIGateway {
    var result: Result<String, Error>
    func run(_ request: AIRequest) async throws -> AIResponse {
        switch result {
        case .success(let text): return AIResponse(text: text, model: "", cached: false, usage: nil)
        case .failure(let error): throw error
        }
    }
}

// @MainActor: `LLMLog.record` funnels mutations to the main thread, so the
// assertions on `log.entries` must observe from there too.
@MainActor
final class FallbackGatewayTests: XCTestCase {

    private func request() -> AIRequest { AIRequest(task: .pitchDraft, prompt: "x") }

    /// A log that always captures, independent of the DEBUG default.
    private func capturingLog() -> LLMLog {
        let log = LLMLog(defaults: UserDefaults(suiteName: "t.\(UUID())")!)
        log.isCapturing = true
        return log
    }

    func testReturnsFirstSuccessAndAttributesTheProvider() async throws {
        let gw = FallbackGateway(steps: [
            .init(name: "glm-4.7-flash", gateway: FakeGateway(result: .success("primary"))),
            .init(name: "nvidia", gateway: FakeGateway(result: .success("secondary")))
        ])
        let response = try await gw.run(request())
        XCTAssertEqual(response.text, "primary")
        XCTAssertEqual(response.model, "glm-4.7-flash")
    }

    func testFailsOverAndLogsEachHop() async throws {
        let log = capturingLog()
        let gw = FallbackGateway(steps: [
            .init(name: "glm-4.7-flash", gateway: FakeGateway(result: .failure(AIGatewayError.server(status: 429)))),
            .init(name: "glm-4.5-flash", gateway: FakeGateway(result: .failure(AIGatewayError.server(status: 429)))),
            .init(name: "nvidia-nim", gateway: FakeGateway(result: .success("rescued")))
        ], log: log)

        let response = try await gw.run(request())
        XCTAssertEqual(response.text, "rescued")
        XCTAssertEqual(response.model, "nvidia-nim")

        XCTAssertEqual(log.entries.count, 2, "one log line per failed hop, none for the winner")
        XCTAssertEqual(log.entries.map(\.outcome), [.failover, .failover])
        XCTAssertEqual(log.entries.map(\.provider), ["glm-4.7-flash", "glm-4.5-flash"])
    }

    func testAllProvidersDownThrowsAndLogsFinalAsFailed() async {
        let log = capturingLog()
        let gw = FallbackGateway(steps: [
            .init(name: "glm", gateway: FakeGateway(result: .failure(AIGatewayError.server(status: 500)))),
            .init(name: "nvidia", gateway: FakeGateway(result: .failure(AIGatewayError.notConfigured)))
        ], log: log)

        do {
            _ = try await gw.run(request())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(log.entries.last?.outcome, .failed)
        }
    }
}

@MainActor
final class LLMLogTests: XCTestCase {

    func testRespectsCaptureToggle() {
        let log = LLMLog(defaults: UserDefaults(suiteName: "t.\(UUID())")!)
        log.isCapturing = false
        log.record(.init(task: "x", tier: "fast", provider: "p", latencyMS: 1, cached: false, outcome: .failed))
        XCTAssertTrue(log.entries.isEmpty)

        log.isCapturing = true
        log.record(.init(task: "x", tier: "fast", provider: "p", latencyMS: 1, cached: false, outcome: .failed))
        XCTAssertEqual(log.entries.count, 1)
    }

    func testRingBufferCaps() {
        let log = LLMLog(capacity: 5, defaults: UserDefaults(suiteName: "t.\(UUID())")!)
        log.isCapturing = true
        for i in 0..<12 {
            log.record(.init(task: "t\(i)", tier: "fast", provider: "p", latencyMS: 0, cached: false, outcome: .ok))
        }
        XCTAssertEqual(log.entries.count, 5)
        XCTAssertEqual(log.entries.first?.task, "t7")
    }

    func testFailuresFilter() {
        let log = LLMLog(defaults: UserDefaults(suiteName: "t.\(UUID())")!)
        log.isCapturing = true
        log.record(.init(task: "a", tier: "fast", provider: "p", latencyMS: 0, cached: false, outcome: .ok))
        log.record(.init(task: "b", tier: "fast", provider: "p", latencyMS: 0, cached: false, outcome: .failover))
        log.record(.init(task: "c", tier: "fast", provider: "p", latencyMS: 0, cached: false, outcome: .failed))
        XCTAssertEqual(log.failures.map(\.task), ["b", "c"])
    }
}
