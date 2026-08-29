import SwiftUI
import SwiftData

struct DraftsView: View {
    @Query(sort: \PitchDraft.createdAt, order: .reverse) private var drafts: [PitchDraft]

    var body: some View {
        NavigationStack {
            List(drafts) { draft in
                NavigationLink {
                    PitchDraftView(draft: draft)
                } label: {
                    VStack(alignment: .leading) {
                        Text(draft.subject)
                            .font(.headline)
                        Text(draft.mediaTarget?.journalist?.name ?? "Unknown recipient")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Drafts")
            .overlay {
                if drafts.isEmpty {
                    ContentUnavailableView(
                        "No drafts yet",
                        systemImage: "envelope",
                        description: Text("Draft a pitch from a journalist's match detail.")
                    )
                }
            }
        }
    }
}
