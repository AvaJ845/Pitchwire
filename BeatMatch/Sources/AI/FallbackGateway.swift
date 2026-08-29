import Foundation

/// Tries a chain of gateways in order and returns the first success. Each failed
/// step is written to the LLM log as a `.failover` so a developer can see exactly
/// where and why the chain moved on.
///
/// In production this shape lives **in the backend**: the app talks only to our
/// gateway (`HTTPGateway`), and the backend composes the real chain —
///   `GLM-4.7-Flash → GLM-4.5-Flash → NVIDIA NIM (free)` —
/// so a z.ai rate-limit is invisible to the user. `FallbackGateway` is kept here
/// as the tested mechanism and for any keyed dev / self-hosted build.
struct FallbackGateway: AIGateway {
    struct Step {
        var name: String
        var gateway: AIGateway
    }

    var steps: [Step]
    var log: LLMLog?

    init(steps: [Step], log: LLMLog? = nil) {
        self.steps = steps
        self.log = log
    }

    func run(_ request: AIRequest) async throws -> AIResponse {
        var lastError: Error = AIGatewayError.notConfigured

        for (index, step) in steps.enumerated() {
            let start = Date()
            do {
                var response = try await step.gateway.run(request)
                // Attribute the win to the provider that actually answered.
                if response.model.isEmpty { response.model = step.name }
                return response
            } catch {
                lastError = error
                let isLast = index == steps.count - 1
                log?.record(LLMLogEntry(
                    task: request.task.rawValue,
                    tier: request.tier.rawValue,
                    provider: step.name,
                    latencyMS: Int(Date().timeIntervalSince(start) * 1000),
                    cached: false,
                    outcome: isLast ? .failed : .failover,
                    detail: "\(error)"
                ))
            }
        }

        throw lastError
    }
}
