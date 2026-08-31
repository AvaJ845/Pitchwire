import XCTest
@testable import Pitchwire

/// A gateway that blocks each call until the test releases it, recording the
/// order calls *complete* in.
private actor BarrierGateway: AIGateway {
    private(set) var completed: [String] = []
    private var gates: [String: CheckedContinuation<Void, Never>] = [:]

    func run(_ request: AIRequest) async throws -> AIResponse {
        let key = request.input["id"] ?? request.task.rawValue
        await withCheckedContinuation { c in gates[key] = c }
        completed.append(key)
        return AIResponse(text: key, model: "test", cached: false, usage: nil)
    }

    /// Wait until `key`'s call has entered `run` and is parked on its gate.
    func waitUntilParked(_ key: String) async {
        while gates[key] == nil { await Task.yield() }
    }

    func release(_ key: String) {
        gates.removeValue(forKey: key)?.resume()
    }

    func order() -> [String] { completed }
}

final class AIClientPipelineTests: XCTestCase {

    func testUserRequestJumpsAheadOfQueuedBackgroundWork() async {
        let gw = BarrierGateway()
        let client = AIClient(gatewayOverride: gw)

        @Sendable func req(_ id: String, _ origin: RequestOrigin) -> AIRequest {
            AIRequest(task: .matchExplanation, input: ["id": id], prompt: "x", origin: origin)
        }

        // bg1 acquires the pipeline immediately and parks in the gateway.
        async let r1: String? = client.text(for: req("bg1", .background))
        await gw.waitUntilParked("bg1")

        // While bg1 is in flight, queue bg2 then user1. Give them a beat to enqueue.
        async let r2: String? = client.text(for: req("bg2", .background))
        async let r3: String? = client.text(for: req("user1", .userInitiated))
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Finish bg1 → the pipeline should hand off to user1, not bg2.
        await gw.release("bg1")
        await gw.waitUntilParked("user1")
        await gw.release("user1")
        await gw.waitUntilParked("bg2")
        await gw.release("bg2")

        _ = await (r1, r2, r3)
        let order = await gw.order()
        XCTAssertEqual(order, ["bg1", "user1", "bg2"],
                       "a user-initiated call must preempt queued background work")
    }
}
