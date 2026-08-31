import Foundation

enum PlanTier: String, Codable, CaseIterable {
    case free
    case solo
    case team
    case agency

    var displayName: String {
        switch self {
        case .free:   return "Free"
        case .solo:   return "Solo Pro"
        case .team:   return "Team"
        case .agency: return "Agency"
        }
    }
}

/// Things that are metered per period. `-1` in a plan's `limits` means unlimited.
enum UsageKey: String, Codable, CaseIterable {
    case storyAnalysis
    case activeCampaign
    case aiPitchDraft

    var displayName: String {
        switch self {
        case .storyAnalysis:  return "Story analyses"
        case .activeCampaign: return "Active campaigns"
        case .aiPitchDraft:   return "AI pitch drafts"
        }
    }
}

/// Things that are simply on or off for a plan.
enum FeatureKey: String, Codable, CaseIterable {
    case savedCampaigns
    case followUpReminders
    case exportPitch
    case teamWorkspace
    case multiClient
}

/// The entire commercial shape of a plan, as data. Nothing in the feature code
/// hard-codes any of these numbers — they are read through `Entitlements`.
struct Plan {
    var tier: PlanTier
    var limits: [UsageKey: Int]
    var features: Set<FeatureKey>
    var trialDays: Int
    /// Days in a metering period (calendar-month-ish; simple and good enough).
    var periodDays: Int

    func limit(for key: UsageKey) -> Int? {
        guard let raw = limits[key] else { return 0 }
        return raw < 0 ? nil : raw   // nil == unlimited
    }

    func has(_ feature: FeatureKey) -> Bool { features.contains(feature) }
}
