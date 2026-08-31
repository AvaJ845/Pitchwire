import SwiftUI

/// The plan lineup — read straight from `LocalEntitlementStore.catalog`, so it
/// can never drift from what the app actually enforces. Paid plans aren't
/// purchasable yet (no StoreKit); this is an honest "here's what's coming" plus
/// a way to register interest, not a dead end at the free cap.
struct PlansView: View {
    @Environment(Entitlements.self) private var entitlements

    private var plans: [Plan] {
        PlanTier.allCases.map { LocalEntitlementStore.plan($0) }
    }

    var body: some View {
        List {
            ForEach(plans, id: \.tier) { plan in
                Section {
                    ForEach(UsageKey.allCases, id: \.self) { key in
                        LabeledContent(key.displayName) {
                            Text(plan.limit(for: key).map { "\($0) / period" } ?? "Unlimited")
                                .foregroundStyle(.secondary)
                        }
                    }
                    let extras = FeatureKey.allCases.filter { plan.has($0) && !LocalEntitlementStore.plan(.free).has($0) }
                    if !extras.isEmpty {
                        LabeledContent("Also includes") {
                            Text(extras.map(featureName).joined(separator: ", "))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    HStack {
                        Text(plan.tier.displayName)
                        if plan.tier == entitlements.plan.tier {
                            Text("current").font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Palette.accentSoft, in: Capsule())
                                .foregroundStyle(Palette.accent)
                        }
                    }
                }
            }

            Section {
                Link(destination: URL(string: "mailto:avaresearchllc@gmail.com?subject=Pitchwire%20paid%20plans")!) {
                    Label("Tell us you want paid plans", systemImage: "envelope")
                }
            } footer: {
                Text("Paid plans aren't available for purchase yet. Campaign memory and follow-ups stay free forever — the paid line is team workspaces, exports, and multi-client.")
            }
        }
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func featureName(_ feature: FeatureKey) -> String {
        switch feature {
        case .savedCampaigns:    return "saved campaigns"
        case .followUpReminders: return "follow-up reminders"
        case .exportPitch:       return "pitch export"
        case .teamWorkspace:     return "team workspace"
        case .multiClient:       return "multi-client campaigns"
        }
    }
}
