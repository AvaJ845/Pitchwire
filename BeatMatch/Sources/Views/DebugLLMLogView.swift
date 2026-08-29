import SwiftUI

#if DEBUG
/// Developer-only. Reachable only from the DEBUG section of Profile and compiled
/// out of release builds entirely.
struct DebugLLMLogView: View {
    @Environment(LLMLog.self) private var log
    @State private var failuresOnly = true

    private var rows: [LLMLogEntry] {
        (failuresOnly ? log.failures : log.entries).reversed()
    }

    var body: some View {
        List {
            Section {
                Toggle("Failures only", isOn: $failuresOnly)
                LabeledContent("Captured", value: "\(log.entries.count)")
                LabeledContent("Failures", value: "\(log.failures.count)")
            }

            if rows.isEmpty {
                ContentUnavailableView(
                    failuresOnly ? "No LLM failures" : "No LLM activity",
                    systemImage: "checkmark.circle",
                    description: Text(log.isCapturing
                        ? "Nothing logged yet this session."
                        : "Capture is off — turn it on in Profile.")
                )
            } else {
                ForEach(rows) { entry in
                    LogRow(entry: entry)
                }
            }
        }
        .navigationTitle("LLM log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Clear", role: .destructive) { log.clear() }
                .disabled(log.entries.isEmpty)
        }
    }
}

private struct LogRow: View {
    let entry: LLMLogEntry

    private var tint: Color {
        switch entry.outcome {
        case .ok:       return .green
        case .failover: return .orange
        case .failed:   return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entry.task).font(.subheadline.weight(.medium))
                Spacer()
                Text(entry.outcome.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
            }
            Text("\(entry.provider) · \(entry.tier) · \(entry.latencyMS)ms\(entry.cached ? " · cached" : "")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let detail = entry.detail {
                Text(detail)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            Text(entry.date.formatted(date: .omitted, time: .standard))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
#endif
