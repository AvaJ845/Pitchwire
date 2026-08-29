import SwiftUI
import SwiftData

/// Campaign memory: the follow-ups you owe on a campaign. Create, check off,
/// re-date. This is the retention spine — keep it lightweight.
struct FollowUpsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var campaign: Campaign

    @State private var newTitle = ""
    @State private var newDue: Date = .now.addingTimeInterval(3 * 86_400)

    private var open: [FollowUpTask] {
        campaign.followUpTasks.filter { !$0.isDone }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    private var done: [FollowUpTask] {
        campaign.followUpTasks.filter(\.isDone).sorted { $0.title < $1.title }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(title: "Add a follow-up")
                        TextField("e.g. Nudge Dana with the demo link", text: $newTitle, axis: .vertical)
                            .font(.subheadline)
                        DatePicker("Due", selection: $newDue, displayedComponents: .date)
                            .font(.subheadline)
                        Button {
                            addTask()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(.pitchwireQuiet)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !open.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Open").padding(.horizontal, 4)
                        ForEach(open) { task in TaskRow(task: task, toggle: toggle) }
                    }
                }

                if !done.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Done").padding(.horizontal, 4).padding(.top, 4)
                        ForEach(done) { task in TaskRow(task: task, toggle: toggle) }
                    }
                }

                if campaign.followUpTasks.isEmpty {
                    ContentUnavailableView {
                        Label("No follow-ups yet", systemImage: "bell.slash")
                    } description: {
                        Text("Add one above, or mark a pitch as sent to be offered a reminder.")
                    }
                    .padding(.top, 40)
                }
            }
            .padding(Metrics.gutter)
        }
        .screenBackground()
        .navigationTitle("Follow-ups")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Haptics.tap()
        let task = FollowUpTask(title: title, dueDate: newDue, campaign: campaign)
        modelContext.insert(task)
        campaign.followUpTasks.append(task)
        try? modelContext.save()
        newTitle = ""
    }

    private func toggle(_ task: FollowUpTask) {
        Haptics.success()
        withAnimation(.snappy) { task.isDone.toggle() }
        try? modelContext.save()
    }
}

private struct TaskRow: View {
    @Bindable var task: FollowUpTask
    let toggle: (FollowUpTask) -> Void

    private var overdue: Bool {
        !task.isDone && (task.dueDate.map { $0 < .now } ?? false)
    }

    var body: some View {
        Card {
            HStack(spacing: 12) {
                Button { toggle(task) } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isDone ? Palette.evidence(.high) : Palette.inkTertiary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .strikethrough(task.isDone)
                    if let due = task.dueDate {
                        Text(overdue ? "Overdue — \(due.formatted(.relative(presentation: .named)))"
                                     : "Due \(due.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(overdue ? Palette.warning : Palette.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .opacity(task.isDone ? 0.6 : 1)
    }
}
