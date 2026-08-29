import Foundation

/// The seam behind which pricing lives. `LocalEntitlementStore` ships today; a
/// remote-config- or StoreKit-backed store replaces it later with no change to
/// any feature — they all go through `Entitlements`, which goes through this.
protocol EntitlementStore {
    /// The plan the user is currently entitled to.
    func currentPlan() -> Plan
    /// Usage of `key` in the current metering period.
    func usage(_ key: UsageKey) -> Int
    /// Record one use of `key`.
    func record(_ key: UsageKey)
    /// Test / support hook.
    func resetUsage()
}
