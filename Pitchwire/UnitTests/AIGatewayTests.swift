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

/// Stands in for a URLSession task whose surrounding `Task` was cancelled.
private struct CancellingGateway: AIGateway {
    func run(_ request: AIRequest) async throws -> AIResponse {
        throw AIGatewayError.transport(URLError(.cancelled))
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

    /// A cancelled call (view dismissed mid-request) must stop the chain and not
    /// spend the remaining providers or write a failover line.
    func testCancellationStopsTheChainWithoutLogging() async {
        let log = capturingLog()
        let gw = FallbackGateway(steps: [
            .init(name: "glm", gateway: CancellingGateway()),
            .init(name: "nvidia", gateway: FakeGateway(result: .success("must not be reached")))
        ], log: log)

        do {
            _ = try await gw.run(request())
            XCTFail("expected the cancellation to propagate")
        } catch {
            XCTAssertTrue(error.isCancellation)
        }
        XCTAssertTrue(log.entries.isEmpty, "cancellation is not a failover or a failure")
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

@MainActor
final class AIClientCancellationTests: XCTestCase {

    func testCancelledCallLeavesNoFailureInTheLog() async {
        let log = LLMLog(defaults: UserDefaults(suiteName: "t.\(UUID())")!)
        log.isCapturing = true
        let client = AIClient(log: log, gatewayOverride: CancellingGateway())

        let text = await client.text(for: AIRequest(task: .matchExplanation, prompt: "x", origin: .background))

        XCTAssertNil(text, "the caller still gets nil and keeps its deterministic fallback")
        XCTAssertTrue(log.entries.isEmpty, "a cancelled request is not a failure")
        XCTAssertTrue(log.failures.isEmpty)
    }

    func testIsCancellationClassification() {
        XCTAssertTrue((CancellationError() as Error).isCancellation)
        XCTAssertTrue((URLError(.cancelled) as Error).isCancellation)
        XCTAssertTrue(AIGatewayError.transport(URLError(.cancelled)).isCancellation)
        XCTAssertFalse(AIGatewayError.transport(URLError(.timedOut)).isCancellation)
        XCTAssertFalse(AIGatewayError.server(status: 500).isCancellation)
        XCTAssertFalse(AIGatewayError.notConfigured.isCancellation)
    }
}
