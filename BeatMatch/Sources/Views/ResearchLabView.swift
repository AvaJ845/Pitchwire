#if DEBUG
import SwiftUI
import SwiftData

/// Slice 4b — the internal editorial-research workflow. DEBUG-only, reached from
/// Profile → Developer. A researcher reviews candidates, opens their sources,
/// attaches real dated articles, and **verifies or rejects** them. AI never
/// verifies — this screen is the mandatory human step.
///
/// Rules it enforces: no contact data is ever entered here; "verified" needs ≥1
/// real article + a reviewer name; a rejected profile is excluded from matching.
struct ResearchLabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalistProfile.name) private var directory: [JournalistProfile]
    @Query(sort: \RemovalRequest.requestedAt, order: .reverse) private var removals: [RemovalRequest]

    private var candidates: [JournalistProfile] { directory.filter { $0.evidenceState == .candidate } }
    private var verified: [JournalistProfile]   { directory.filter { $0.evidenceState == .verified } }
    private var rejected: [JournalistProfile]   { directory.filter { $0.isRejected } }
    private var openRemovals: [RemovalRequest]  { removals.filter(\.isOpen) }

    var body: some View {
        List {
            Section {
                LabeledContent("Directory", value: "\(directory.count)")
                LabeledContent("Candidates", value: "\(candidates.count)")
                LabeledContent("Verified", value: "\(verified.count)")
                LabeledContent("Rejected", value: "\(rejected.count)")
            } footer: {
                Text("Seeded from editorial_seed.json. AI discovers and drafts; a human verifies. Verifying needs ≥1 real article and a reviewer name.")
            }

            if !openRemovals.isEmpty {
                Section("Removal requests") {
                    ForEach(openRemovals) { req in
                        if let profile = directory.first(where: { $0.id == req.journalistID }) {
                            NavigationLink { CandidateReviewView(profile: profile) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(req.journalistName).font(.subheadline.weight(.medium))
                                    Text(req.reason).font(.caption).foregroundStyle(.secondary)
                                    Text(req.requestedAt, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        } else {
                            Button("Resolve “\(req.journalistName)” (profile gone)") {
                                LabActions.resolveRemoval(req, resolution: "Profile no longer in directory", context: modelContext)
                            }
                        }
                    }
                }
            }

            group("Candidates", candidates)
            group("Verified", verified)
            group("Rejected", rejected)
        }
        .navigationTitle("Research Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func group(_ title: String, _ profiles: [JournalistProfile]) -> some View {
        if !profiles.isEmpty {
            Section(title) {
                ForEach(profiles) { profile in
                    NavigationLink { CandidateReviewView(profile: profile) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).font(.subheadline.weight(.medium))
                                Text("\(profile.outlet?.name ?? "—") · \(profile.vertical ?? "—")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(profile.allCoverage.count) art.")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("lab-row-\(title.lowercased())")
                }
            }
        }
    }
}

// MARK: - Review one candidate

struct CandidateReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: JournalistProfile
    @AppStorage("lab.reviewer") private var reviewer = ""
    @State private var confidence: EvidenceConfidence = .moderate
    @State private var showArticleEditor = false
    @State private var confirmReject = false
    @State private var confirmClaim = false

    private var record: EditorialEvidenceRecord? { profile.primaryEvidence }
    private var canVerify: Bool {
        !reviewer.trimmingCharacters(in: .whitespaces).isEmpty && !(record?.articles.isEmpty ?? true)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name).font(.title3.bold())
                    if let role = profile.role { Text(role).font(.caption).foregroundStyle(.secondary) }
                    Text("\(profile.outlet?.name ?? "—") · \(profile.vertical ?? "—")")
                        .font(.caption).foregroundStyle(.secondary)
                    Tag(text: profile.evidenceState.tagText, icon: profile.evidenceState.tagIcon,
                        color: profile.evidenceState.tagColor)
                        .padding(.top, 2)
                }
                if let src = record?.sourceURL, let url = URL(string: src) {
                    Link(destination: url) { Label("Open author page", systemImage: "safari") }
                }
                if let outletURL = profile.outlet?.url, let url = URL(string: outletURL), !outletURL.isEmpty {
                    Link(destination: url) { Label("Open outlet", systemImage: "building.columns") }
                }
            }

            Section {
                listField("Beat topics", get: { profile.beatTopics }, set: { profile.beatTopics = $0 })
                listField("Audiences", get: { profile.audiences }, set: { profile.audiences = $0 })
                listField("Covered angles", get: { profile.coveredAngles }, set: { profile.coveredAngles = $0 })
                listField("Do not pitch", get: { profile.doNotPitch }, set: { profile.doNotPitch = $0 })
            } header: {
                Text("Beat & fit")
            } footer: {
                Text("Comma-separated. Correct these against the author page before verifying.")
            }

            if let summary = record?.evidenceSummary, !summary.isEmpty {
                Section {
                    Text(summary).font(.footnote)
                } header: { Text("AI-drafted assessment") }
                footer: { Text("Not evidence. Verify every claim against the author page above.") }
            }

            Section {
                if profile.allCoverage.isEmpty {
                    Text("No articles attached. Open the author page, find recent on-topic pieces, add each with its real URL and date.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(profile.allCoverage) { article in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.title).font(.subheadline)
                            Text([article.publishedLabel, article.host].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                LabActions.removeArticle(article, context: modelContext)
                            } label: { Label("Remove", systemImage: "trash") }
                        }
                    }
                }
                Button { showArticleEditor = true } label: { Label("Add article", systemImage: "plus") }
            } header: { Text("Articles — the evidence") }

            Section("Verify") {
                TextField("Reviewer (your initials)", text: $reviewer)
                    .textInputAutocapitalization(.characters)
                Picker("Confidence", selection: $confidence) {
                    ForEach(EvidenceConfidence.allCases, id: \.self) { Text($0.label).tag($0) }
                }

                if profile.isVerified {
                    LabeledContent("Verified",
                                   value: record?.verificationDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    Button("Un-verify (back to candidate)") {
                        LabActions.unverify(profile, context: modelContext)
                    }
                } else {
                    Button("Verify this profile") {
                        if LabActions.verify(profile, reviewer: reviewer, confidence: confidence, context: modelContext) {
                            Haptics.success()
                        } else {
                            Haptics.warning()
                        }
                    }
                    .disabled(!canVerify)
                }

                Button("Mark as claimed profile") { confirmClaim = true }
            }

            Section {
                if profile.isRejected {
                    Button("Restore to directory") { LabActions.restore(profile, context: modelContext) }
                } else {
                    Button("Reject — exclude from matching", role: .destructive) { confirmReject = true }
                }
            } footer: {
                Text("Also resolve any open removal request for this profile.")
            }
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showArticleEditor) {
            ArticleEditorView(profile: profile)
        }
        .confirmationDialog("Reject \(profile.name)?", isPresented: $confirmReject, titleVisibility: .visible) {
            Button("Reject", role: .destructive) {
                LabActions.reject(profile, context: modelContext)
                resolveRemovals(resolution: "Rejected in review")
            }
        }
        .confirmationDialog("Mark as claimed?", isPresented: $confirmClaim, titleVisibility: .visible) {
            Button("Confirm — the journalist has claimed this") {
                LabActions.markClaimed(profile, reviewer: reviewer, context: modelContext)
                Haptics.success()
            }
        } message: {
            Text("Only if they've confirmed it, e.g. by email. This sets provenance to CLAIMED_PROFILE.")
        }
        .onAppear { confidence = record?.confidence ?? .moderate }
    }

    /// A comma-separated editor over a `[String]` model field. Commits on every
    /// edit; empty entries are dropped.
    private func listField(_ label: String, get: @escaping () -> [String],
                           set: @escaping ([String]) -> Void) -> some View {
        let binding = Binding(
            get: { get().joined(separator: ", ") },
            set: { raw in
                let list = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                set(list)
                try? modelContext.save()
            }
        )
        return VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: binding, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private func resolveRemovals(resolution: String) {
        let open = ((try? modelContext.fetch(FetchDescriptor<RemovalRequest>())) ?? [])
            .filter { $0.isOpen && $0.journalistID == profile.id }
        for req in open { LabActions.resolveRemoval(req, resolution: resolution, context: modelContext) }
    }
}

// MARK: - Add an article

struct ArticleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let profile: JournalistProfile

    @State private var title = ""
    @State private var url = ""
    @State private var dateKnown = true
    @State private var publishedAt = Date()
    @State private var topics = ""

    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && url.trimmingCharacters(in: .whitespaces).hasPrefix("https://")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Article") {
                    TextField("Headline (as published)", text: $title, axis: .vertical)
                    TextField("URL (https://…)", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section("Published") {
                    Toggle("Date known", isOn: $dateKnown)
                    if dateKnown {
                        DatePicker("Date", selection: $publishedAt, in: ...Date(), displayedComponents: .date)
                    } else {
                        Text("Left blank — never guessed.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Topics") {
                    TextField("comma, separated, story topics", text: $topics)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let list = topics.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        if LabActions.addArticle(to: profile, title: title, url: url,
                                                 publishedAt: dateKnown ? publishedAt : nil,
                                                 topics: list, context: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(!valid)
                }
            }
        }
    }
}
#endif
