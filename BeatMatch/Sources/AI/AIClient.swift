import Foundation
import Observation

/// One vendor-neutral record per AI call. `print` today; a real sink (or none)
/// swaps in behind the protocol.
struct AIEvent {
    var task: AITask
    var tier: ModelTier
    var model: String
    var latencyMS: Int
    var cached: Bool
    var ok: Bool
    var errorKind: String?
}

protocol AITelemetry {
    func record(_ event: AIEvent)
}

struct LoggingTelemetry: AITelemetry {
    func record(_ event: AIEvent) {
        let status = event.ok ? "ok" : "ERR(\(event.errorKind ?? "?"))"
        print("[AI] \(event.task.rawValue) tier=\(event.tier.rawValue) model=\(event.model) \(event.latencyMS)ms cached=\(event.cached) \(status)")
    }
}

/// The single seam every feature uses for AI. Features never touch a gateway or a
/// provider — they call `client.run(...)` and fall back if it throws.
///
/// - Centralized observability: every call is timed and emitted as an `AIEvent`.
/// - Replaceable: `configure(_:)` swaps the underlying gateway with no feature changes.
/// - Provider-independent: the app has no concept of GLM / OpenAI / Anthropic.
@Observable
final class AIClient {
    private(set) var configuration: AIConfiguration
    private var gateway: AIGateway
    private let telemetry: AITelemetry
    private weak var log: LLMLog?

    init(
        configuration: AIConfiguration = .offline,
        log: LLMLog? = nil,
        telemetry: AITelemetry? = nil
    ) {
        self.configuration = configuration
        self.log = log
        if let telemetry {
            self.telemetry = telemetry
        } else if let log {
            self.telemetry = CompositeTelemetry(sinks: [LoggingTelemetry(), CapturingTelemetry(log: log)])
        } else {
            self.telemetry = LoggingTelemetry()
        }
        self.gateway = Self.makeGateway(for: configuration, log: log)
    }

    /// Swap the backend at runtime (e.g. after sign-in issues a client token).
    func configure(_ configuration: AIConfiguration) {
        self.configuration = configuration
        self.gateway = Self.makeGateway(for: configuration, log: log)
    }

    var isConfigured: Bool { configuration.isConfigured }

    func run(_ request: AIRequest) async throws -> AIResponse {
        let start = Date()
        do {
            let response = try await gateway.run(request)
            emit(request, model: response.model, start: start, cached: response.cached, ok: true, error: nil)
            return response
        } catch {
            // The call never reached a model, so there is no model name to report.
            emit(request, model: "—", start: start, cached: false, ok: false, error: error)
            throw error
        }
    }

    /// Convenience: run and return the text, or `nil` if anything went wrong.
    /// Callers use this when they have a deterministic fallback ready.
    func text(for request: AIRequest) async -> String? {
        try? await run(request).text
    }

    private func emit(_ request: AIRequest, model: String, start: Date, cached: Bool, ok: Bool, error: Error?) {
        telemetry.record(AIEvent(
            task: request.task,
            tier: request.tier,
            model: model,
            latencyMS: Int(Date().timeIntervalSince(start) * 1000),
            cached: cached,
            ok: ok,
            errorKind: error.map { "\($0)" }
        ))
    }

    private static func makeGateway(for config: AIConfiguration, log: LLMLog?) -> AIGateway {
        // Production: one hop to our backend, which runs the real
        // GLM → GLM → NVIDIA failover chain itself. `FallbackGateway` is the
        // tested shape of that chain; see FallbackGateway / DIRECTION.md.
        config.isConfigured ? HTTPGateway(config: config) : OfflineGateway()
    }
}
