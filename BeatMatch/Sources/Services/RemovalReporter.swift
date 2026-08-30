import Foundation

/// Best-effort delivery of a removal / issue report to the backend, which
/// forwards it to a monitored channel. The local `RemovalRequest` is the source
/// of truth and the backstop — this is fire-and-forget notification only.
///
/// Body carries editorial context only (name, record id, reason). No user data.
enum RemovalReporter {
    static func send(name: String, journalistID: UUID, reason: String,
                     using config: AIConfiguration) async {
        guard let base = config.baseURL, let token = config.clientToken, !token.isEmpty else { return }
        var request = URLRequest(url: base.appendingPathComponent("v1/removal-request"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "journalistName": name,
            "journalistID": journalistID.uuidString,
            "reason": reason,
        ])
        _ = try? await HTTPGateway.defaultSession.data(for: request)
    }
}
