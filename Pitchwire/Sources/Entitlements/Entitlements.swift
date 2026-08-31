import Foundation
import Observation

/// The only thing feature code touches. Ask questions, don't check the plan:
///
///     if entitlements.can(.exportPitch) { … }
///     guard entitlements.consume(.storyAnalysis) else { showLimit() ; return }
///     Text("\(entitlements.remaining(.aiPitchDraft) ?? 0) drafts left")
///
/// Swapping `LocalEntitlementStore` for a StoreKit/server-backed store changes
/// none of the above.
@Observable
final class Entitlements {
    private let store: EntitlementStore
    /// Bumped after every `consume` so SwiftUI re-reads `remaining`.
    private var revision = 0

    init(store: EntitlementStore) {
        self.store = store
    }

    var plan: Plan {
        _ = revision
        return store.currentPlan()
    }

    /// Is this on/off feature included in the current plan?
    func can(_ feature: FeatureKey) -> Bool {
        plan.has(feature)
    }

    /// Remaining uses of a metered key this period. `nil` == unlimited.
    func remaining(_ key: UsageKey) -> Int? {
        _ = revision
        guard let limit = plan.limit(for: key) else { return nil }
        return max(0, limit - store.usage(key))
    }

    /// Uses of a metered key so far this period.
    func used(_ key: UsageKey) -> Int {
        _ = revision
        return store.usage(key)
    }

    func isUnlimited(_ key: UsageKey) -> Bool {
        plan.limit(for: key) == nil
    }

    /// Try to spend one use. Returns `false` (and records nothing) if over limit.
    @discardableResult
    func consume(_ key: UsageKey) -> Bool {
        if let remaining = remaining(key), remaining <= 0 { return false }
        store.record(key)
        revision &+= 1
        return true
    }

    /// Would `consume` succeed right now, without spending?
    func hasAllowance(for key: UsageKey) -> Bool {
        remaining(key).map { $0 > 0 } ?? true
    }

    func resetUsage() {
        store.resetUsage()
        revision &+= 1
    }
}
