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
        let status = event.ok ? "ok" : "ERR(\(Redaction.redact(event.errorKind ?? "?")))"
        print("[AI] \(event.task.rawValue) tier=\(event.tier.rawValue) model=\(event.model) \(event.latencyMS)ms cached=\(event.cached) \(status)")
    }
}

/// Serializes AI calls to one in-flight request, and hands the pipeline to a
/// person before a background sweep. Without this, an `ExplanationEnricher` run
/// (many calls, tens of seconds against slow free models) starves a user's
/// "Draft pitch" until it times out.
private actor RequestPipeline {
    private var busy = false
    private var userWaiters: [CheckedContinuation<Void, Never>] = []
    private var bgWaiters: [CheckedContinuation<Void, Never>] = []

    func acquire(_ origin: RequestOrigin) async {
        guard busy else { busy = true; return }
        await withCheckedContinuation { c in
            switch origin {
            case .userInitiated: userWaiters.append(c)
            case .background:     bgWaiters.append(c)
            }
        }
    }

    func release() {
        if !userWaiters.isEmpty { userWaiters.removeFirst().resume() }
        else if !bgWaiters.isEmpty { bgWaiters.removeFirst().resume() }
        else { busy = false }
    }
}

/// The single seam every feature uses for AI. Features never touch a gateway or a
/// provider — they call `client.run(...)` and fall back if it throws.
///
/// - Centralized observability: every call is timed and emitted as an `AIEvent`.
/// - Replaceable: `configure(_:)` swaps the underlying gateway with no feature changes.
/// - Provider-independent: the app has no concept of GLM / OpenAI / Anthropic.
/// - Serialized: one call at a time, user-initiated before background.
@Observable
final class AIClient {
    private(set) var configuration: AIConfiguration
    private var gateway: AIGateway
    private let telemetry: AITelemetry
    private weak var log: LLMLog?
    private let pipeline = RequestPipeline()

    init(
        configuration: AIConfiguration = .offline,
        log: LLMLog? = nil,
        telemetry: AITelemetry? = nil,
        gatewayOverride: AIGateway? = nil
    ) {
        self.configuration = configuration
        self.log = log
        Redaction.register(configuration.clientToken)
        if let telemetry {
            self.telemetry = telemetry
        } else if let log {
            self.telemetry = CompositeTelemetry(sinks: [LoggingTelemetry(), CapturingTelemetry(log: log)])
        } else {
            self.telemetry = LoggingTelemetry()
        }
        self.gateway = gatewayOverride ?? Self.makeGateway(for: configuration, log: log)
    }

    /// Swap the backend at runtime (e.g. after sign-in issues a client token).
    func configure(_ configuration: AIConfiguration) {
        self.configuration = configuration
        Redaction.register(configuration.clientToken)
        self.gateway = Self.makeGateway(for: configuration, log: log)
    }

    var isConfigured: Bool { configuration.isConfigured }

    func run(_ request: AIRequest) async throws -> AIResponse {
        // Bail before taking the pipeline if the caller is already gone.
        try Task.checkCancellation()
        await pipeline.acquire(request.origin)
        do {
            // …or if it went away while queued behind other work.
            try Task.checkCancellation()
            let response = try await perform(request)
            await pipeline.release()
            return response
        } catch {
            await pipeline.release()
            throw error
        }
    }

    private func perform(_ request: AIRequest) async throws -> AIResponse {
        let start = Date()
        do {
            let response = try await gateway.run(request)
            emit(request, model: response.model, start: start, cached: response.cached, ok: true, error: nil)
            capturePayload(request, responseText: response.text, error: nil)
            return response
        } catch {
            // A cancelled request is not a failure — the caller's task was torn
            // down (view dismissed, id changed) or superseded. Unwind quietly:
            // no telemetry, no log entry, no failure count. The caller still
            // gets `nil` and keeps its deterministic fallback.
            if error.isCancellation { throw error }
            // The call never reached a model, so there is no model name to report.
            emit(request, model: "—", start: start, cached: false, ok: false, error: error)
            capturePayload(request, responseText: nil, error: error)
            throw error
        }
    }

    private func capturePayload(_ request: AIRequest, responseText: String?, error: Error?) {
        #if DEBUG
        guard log?.isCapturingPayloads == true else { return }
        PayloadLog.record(request: request, responseText: responseText, error: error)
        #endif
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
