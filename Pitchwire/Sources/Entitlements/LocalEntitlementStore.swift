import Foundation

/// The ONE place the commercial model is defined. Change these values — free
/// limits, Pro entitlements, trial length, per-task AI caps, add a plan — and
/// nothing else in the app has to change.
///
/// This local store always reports the Free plan and meters usage in
/// `UserDefaults` per period. The paid path (StoreKit product → entitlement,
/// or a server-issued entitlement) is a different `EntitlementStore` behind the
/// same protocol.
final class LocalEntitlementStore: EntitlementStore {

    // MARK: - The catalog

    static let catalog: [PlanTier: Plan] = [
        .free: Plan(
            tier: .free,
            limits: [.storyAnalysis: 3, .activeCampaign: 2, .aiPitchDraft: 5],
            // Campaign memory (saved campaigns + follow-ups) is the retention
            // spine — never paywalled. Team/export/multi-client are the paid line.
            features: [.savedCampaigns, .followUpReminders],
            trialDays: 0,
            periodDays: 30
        ),
        .solo: Plan(
            tier: .solo,
            limits: [.storyAnalysis: 30, .activeCampaign: 15, .aiPitchDraft: 100],
            features: [.savedCampaigns, .followUpReminders, .exportPitch],
            trialDays: 7,
            periodDays: 30
        ),
        .team: Plan(
            tier: .team,
            limits: [.storyAnalysis: 150, .activeCampaign: 60, .aiPitchDraft: 500],
            features: [.savedCampaigns, .followUpReminders, .exportPitch, .teamWorkspace],
            trialDays: 14,
            periodDays: 30
        ),
        .agency: Plan(
            tier: .agency,
            limits: [.storyAnalysis: -1, .activeCampaign: -1, .aiPitchDraft: -1],
            features: Set(FeatureKey.allCases),
            trialDays: 14,
            periodDays: 30
        )
    ]

    static func plan(_ tier: PlanTier) -> Plan { catalog[tier] ?? catalog[.free]! }

    // MARK: - State

    private let defaults: UserDefaults
    /// The entitlement source. Today it's just a stored tier; later a StoreKit or
    /// server entitlement sets this.
    var activeTier: PlanTier

    init(defaults: UserDefaults = .standard, activeTier: PlanTier = .free) {
        self.defaults = defaults
        self.activeTier = activeTier
    }

    func currentPlan() -> Plan { Self.plan(activeTier) }

    func usage(_ key: UsageKey) -> Int {
        defaults.integer(forKey: storageKey(key))
    }

    func record(_ key: UsageKey) {
        defaults.set(usage(key) + 1, forKey: storageKey(key))
    }

    func resetUsage() {
        for key in UsageKey.allCases {
            for period in (currentPeriod - 1)...(currentPeriod + 1) {
                defaults.removeObject(forKey: rawKey(key, period: period))
            }
        }
    }

    // MARK: - Period bucketing
    //
    // The period number is baked into the storage key, so counters roll to zero
    // on their own when a new period begins — no stamp, no migration.

    private var currentPeriod: Int {
        let days = max(1, currentPlan().periodDays)
        return Int(Date().timeIntervalSince1970 / Double(days * 86_400))
    }

    private func rawKey(_ key: UsageKey, period: Int) -> String {
        "entitlements.usage.\(key.rawValue).\(period)"
    }

    private func storageKey(_ key: UsageKey) -> String {
        rawKey(key, period: currentPeriod)
    }
}
