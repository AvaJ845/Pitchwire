import SwiftUI
import SwiftData

struct DraftsView: View {
    @Environment(\.modelContext) private var modelContext
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
                    List {
                        if !open.isEmpty {
                            Section("In progress") { rows(open) }
                        }
                        if !sent.isEmpty {
                            Section("Sent") { rows(sent) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .screenBackground()
            .navigationTitle("Drafts")
        }
    }

    private func rows(_ drafts: [PitchDraft]) -> some View {
        ForEach(drafts) { draft in
            ZStack {
                NavigationLink { PitchDraftView(draft: draft) } label: { EmptyView() }.opacity(0)
                DraftRow(draft: draft)
            }
            .listRowInsets(EdgeInsets(top: 5, leading: Metrics.gutter, bottom: 5, trailing: Metrics.gutter))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    withAnimation { modelContext.delete(draft) }
                    try? modelContext.save()
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}
