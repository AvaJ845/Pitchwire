import Foundation

/// Scrubs secrets out of anything before it reaches a log sink. Applied at every
/// boundary that writes a log line (`LLMLog.record`, `LoggingTelemetry`,
/// `PayloadLog`). The app holds no provider keys, but it may hold a scoped
/// client token, and wrapped transport errors can carry URLs and headers.
enum Redaction {
    private static let lock = NSLock()
    private static var exactSecrets: Set<String> = []

    /// Register a known secret (e.g. the current client token) for exact removal.
    static func register(_ secret: String?) {
        guard let secret, secret.count >= 6 else { return }
        lock.lock(); defer { lock.unlock() }
        exactSecrets.insert(secret)
    }

    static func redact(_ text: String) -> String {
        var out = text

        lock.lock()
        let secrets = exactSecrets
        lock.unlock()
        for secret in secrets {
            out = out.replacingOccurrences(of: secret, with: "‹redacted›")
        }

        for pattern in patterns {
            out = out.replacingOccurrences(
                of: pattern.regex,
                with: pattern.replacement,
                options: .regularExpression
            )
        }
        return out
    }

    static func redact(_ text: String?) -> String { text.map(redact) ?? "nil" }

    private struct Pattern { let regex: String; let replacement: String }

    private static let patterns: [Pattern] = [
        Pattern(regex: #"(?i)bearer\s+[A-Za-z0-9._\-]{6,}"#, replacement: "Bearer ‹redacted›"),
        Pattern(regex: #"nvapi-[A-Za-z0-9._\-]{6,}"#,          replacement: "nvapi-‹redacted›"),
        Pattern(regex: #"sk-[A-Za-z0-9._\-]{6,}"#,             replacement: "sk-‹redacted›"),
        Pattern(regex: #"(?i)(api[_\-]?key|token|secret|authorization)\s*[:=]\s*["']?[A-Za-z0-9._\-]{8,}"#,
                replacement: "$1=‹redacted›")
    ]
}
