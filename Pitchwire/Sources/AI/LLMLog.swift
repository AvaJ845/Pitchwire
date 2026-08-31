import Foundation
import Observation

/// One line in the developer LLM log. Captures enough to debug a failure or a
/// failover without a network trace.
struct LLMLogEntry: Identifiable {
    enum Outcome: String {
        case ok
        case failover   // one provider failed, moving to the next
        case failed     // every provider failed; caller fell back to deterministic output
    }

    let id = UUID()
    var date = Date()
    var task: String
    var tier: String
    var provider: String
    var latencyMS: Int
    var cached: Bool
    var outcome: Outcome
    var detail: String?

    var isFailure: Bool { outcome != .ok }
}

/// A capped, in-memory ring of recent LLM activity. Feeds the DEBUG-only log
/// viewer in Settings. Capture is off unless the developer turns it on (and it
/// can never be reached in a release build — the UI is `#if DEBUG`).
@Observable
final class LLMLog {
    private(set) var entries: [LLMLogEntry] = []
    private let capacity: Int
    private let defaults: UserDefaults
    private let captureKey = "llmlog.capture"
    private let payloadKey = "llmlog.capture.payloads"

    /// Metadata capture — task, tier, provider, latency, outcome. No payloads.
    var isCapturing: Bool {
        didSet { defaults.set(isCapturing, forKey: captureKey) }
    }

    /// Full prompt + response capture to the on-device unified log (`PayloadLog`).
    /// OFF by default even in DEBUG — prompts carry the user's unpublished story.
    var isCapturingPayloads: Bool {
        didSet { defaults.set(isCapturingPayloads, forKey: payloadKey) }
    }

    init(capacity: Int = 300, defaults: UserDefaults = .standard) {
        self.capacity = capacity
        self.defaults = defaults
        #if DEBUG
        self.isCapturing = defaults.object(forKey: captureKey) as? Bool ?? true
        self.isCapturingPayloads = defaults.object(forKey: payloadKey) as? Bool ?? false
        #else
        self.isCapturing = false
        self.isCapturingPayloads = false
        #endif
    }

    /// Thread-safe entry point. `AIClient` emits from whatever executor ran the
    /// request — often several at once (e.g. `ExplanationEnricher`) — but `entries`
    /// is `@Observable` and read by SwiftUI, so every mutation is funnelled onto
    /// the main thread. A call already on main mutates synchronously (keeps the
    /// unit tests straightforward); an off-main call hops.
    func record(_ entry: LLMLogEntry) {
        var entry = entry
        entry.detail = entry.detail.map(Redaction.redact)   // never store a secret
        if Thread.isMainThread {
            ingest(entry)
        } else {
            DispatchQueue.main.async { [weak self] in self?.ingest(entry) }
        }
    }

    /// Always runs on the main thread (see `record`). Not marked `@MainActor` so
    /// the non-isolated `record` can call it directly on the fast path.
    private func ingest(_ entry: LLMLogEntry) {
        guard isCapturing else { return }
        entries.append(entry)
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }

    func clear() { entries.removeAll() }

    var failures: [LLMLogEntry] { entries.filter(\.isFailure) }
}

/// Bridges `AIClient`'s per-call events into the log. Paired with `LoggingTelemetry`
/// via `CompositeTelemetry` so console logging is unaffected.
struct CapturingTelemetry: AITelemetry {
    let log: LLMLog

    func record(_ event: AIEvent) {
        // "notConfigured" is the designed offline state, not a failure — don't
        // flood the log with it every time a feature falls back to a template.
        if let kind = event.errorKind, kind.contains("notConfigured") { return }

        log.record(LLMLogEntry(
            task: event.task.rawValue,
            tier: event.tier.rawValue,
            provider: event.model,
            latencyMS: event.latencyMS,
            cached: event.cached,
            outcome: event.ok ? .ok : .failed,
            detail: event.errorKind
        ))
    }
}

/// Fans one event out to several sinks.
struct CompositeTelemetry: AITelemetry {
    let sinks: [AITelemetry]
    func record(_ event: AIEvent) { sinks.forEach { $0.record(event) } }
}
