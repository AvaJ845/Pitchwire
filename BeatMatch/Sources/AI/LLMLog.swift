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

    var isCapturing: Bool {
        didSet { defaults.set(isCapturing, forKey: captureKey) }
    }

    init(capacity: Int = 300, defaults: UserDefaults = .standard) {
        self.capacity = capacity
        self.defaults = defaults
        #if DEBUG
        self.isCapturing = defaults.object(forKey: captureKey) as? Bool ?? true
        #else
        self.isCapturing = false
        #endif
    }

    func record(_ entry: LLMLogEntry) {
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
