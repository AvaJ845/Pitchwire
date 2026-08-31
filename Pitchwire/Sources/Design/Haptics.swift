import UIKit

/// Small, consistent haptic vocabulary. One line at each meaningful moment.
/// Generators are held and pre-armed so the first tap after a lull isn't late.
@MainActor
enum Haptics {
    private static let notify = UINotificationFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let selection = UISelectionFeedbackGenerator()

    static func success() { notify.notificationOccurred(.success); notify.prepare() }
    static func warning() { notify.notificationOccurred(.warning); notify.prepare() }
    static func tap()     { impact.impactOccurred(); impact.prepare() }
    static func select()  { selection.selectionChanged(); selection.prepare() }
}
