import Foundation
import OSLog

#if DEBUG
/// Writes full LLM prompts and responses to the unified log — **on the device
/// only** (`.private` fields; visible in Xcode's console when attached, hidden
/// from sysdiagnose / remote collection).
///
/// This is separate from `LLMLog` on purpose: prompts contain the user's
/// *unpublished* story text. It is gated behind its own toggle
/// (`LLMLog.isCapturingPayloads`) which is **OFF by default even in DEBUG**, and
/// this whole file is compiled out of release.
enum PayloadLog {
    private static let logger = Logger(subsystem: "com.avaresearch.pitchwire", category: "llm-payload")

    static func record(request: AIRequest, responseText: String?, error: Error?) {
        let prompt = Redaction.redact(request.prompt)
        let facts = Redaction.redact(request.input.map { "\($0.key)=\($0.value)" }.joined(separator: " | "))
        let response = Redaction.redact(responseText)
        let err = error.map { Redaction.redact("\($0)") } ?? "-"

        logger.debug("""
        task=\(request.task.rawValue, privacy: .public) tier=\(request.tier.rawValue, privacy: .public)
        prompt=\(prompt, privacy: .private)
        facts=\(facts, privacy: .private)
        response=\(response, privacy: .private)
        error=\(err, privacy: .public)
        """)
    }
}
#endif
