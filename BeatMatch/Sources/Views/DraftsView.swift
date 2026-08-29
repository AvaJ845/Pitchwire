import SwiftUI
import SwiftData

struct DraftsView: View {
    @Query(sort: \PitchDraft.createdAt, order: .reverse) private var drafts: [PitchDraft]

    private var sent: [PitchDraft] { drafts.filter { $0.status == .markedSent } }
    private var open: [PitchDraft] { drafts.filter { $0.status == .draft } }

    var body: some View {
        NavigationStack {
            Group {
                if drafts.isEmpty {
                    ContentUnavailableView {
                        Label("No drafts yet", systemImage: "paperplane")
                    } description: {
                        Text("Draft a pitch from a journalist's match detail.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if !open.isEmpty {
                                SectionLabel(title: "In progress").padding(.horizontal, 4)
                                ForEach(open) { row($0) }
                            }
                            if !sent.isEmpty {
                                SectionLabel(title: "Sent").padding(.horizontal, 4).padding(.top, 8)
                                ForEach(sent) { row($0) }
                            }
                        }
                        .padding(Metrics.gutter)
                    }
                }
            }
            .screenBackground()
            .navigationTitle("Drafts")
        }
    }

    private func row(_ draft: PitchDraft) -> some View {
        NavigationLink {
            PitchDraftView(draft: draft)
        } label: {
            DraftRow(draft: draft)
        }
        .buttonStyle(.plain)
    }
}
