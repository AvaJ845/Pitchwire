import Foundation
import SwiftData

/// Portable JSON of everything the user has built — campaigns, the story, the
/// matches they kept, drafts, follow-ups. So their work is never trapped in an
/// opaque SwiftData store (see the parked-store recovery in `PitchwireApp`).
///
/// No contact data — matches export as name / outlet / reason, same as the app
/// shows.
@MainActor
enum WorkspaceExporter {

    static func json(_ context: ModelContext) -> String {
        let campaigns = (try? context.fetch(
            FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []

        let file = Export(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            app: "Pitchwire",
            campaigns: campaigns.map(Campaign.export)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return (try? encoder.encode(file)).flatMap { String(data: $0, encoding: .utf8) }
            ?? "{\"error\":\"encode failed\"}"
    }

    struct Export: Encodable {
        var exportedAt: String
        var app: String
        var campaigns: [CampaignDTO]
    }

    struct CampaignDTO: Encodable {
        var name: String
        var createdAt: String
        var story: StoryDTO?
        var matches: [MatchDTO]
        var drafts: [DraftDTO]
        var followUps: [FollowUpDTO]
    }
    struct StoryDTO: Encodable {
        var rawText: String
        var theme: String?; var vertical: String?; var region: String?
        var angle: String?; var audience: String?
        var subtopics: [String]; var mediaHooks: [String]
    }
    struct MatchDTO: Encodable {
        var name: String; var outlet: String?; var tier: String
        var score: Double; var status: String; var reason: String
    }
    struct DraftDTO: Encodable {
        var subject: String; var short: String; var long: String; var status: String
    }
    struct FollowUpDTO: Encodable {
        var title: String; var dueDate: String?; var done: Bool
    }
}

private extension Campaign {
    static func export(_ c: Campaign) -> WorkspaceExporter.CampaignDTO {
        let iso = ISO8601DateFormatter()
        return .init(
            name: c.name,
            createdAt: iso.string(from: c.createdAt),
            story: c.story.map { s in
                .init(rawText: s.rawText, theme: s.theme, vertical: s.vertical, region: s.region,
                      angle: s.angle, audience: s.audience, subtopics: s.subtopics, mediaHooks: s.mediaHooks)
            },
            matches: c.mediaTargets
                .sorted { $0.confidenceScore > $1.confidenceScore }
                .map { t in
                    .init(name: t.journalist?.name ?? "—",
                          outlet: t.journalist?.outlet?.name,
                          tier: t.confidenceTier.rawValue,
                          score: (t.confidenceScore * 100).rounded() / 100,
                          status: t.status.rawValue,
                          reason: t.explanation?.reasonText ?? "")
                },
            drafts: c.pitchDrafts.map {
                .init(subject: $0.subject, short: $0.shortBody, long: $0.longBody, status: $0.status.rawValue)
            },
            followUps: c.followUpTasks.map {
                .init(title: $0.title, dueDate: $0.dueDate.map { iso.string(from: $0) }, done: $0.isDone)
            }
        )
    }
}
