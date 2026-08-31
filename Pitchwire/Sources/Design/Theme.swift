import SwiftUI
import UIKit

/// One-time UIKit appearance wiring, so every navigation bar large/inline title
/// picks up the editorial serif without each screen opting in. SwiftUI text uses
/// `Font.editorial*` (see Typography.swift); this keeps the nav chrome in step.
enum Theme {
    static func apply() {
        guard let serif = UIFont.systemFont(ofSize: 17, weight: .semibold)
            .fontDescriptor.withDesign(.serif) else { return }

        let large = UIFont(descriptor: serif, size: 32)
        let inline = UIFont(descriptor: serif, size: 17)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [.font: bold(large)]
        appearance.titleTextAttributes = [.font: bold(inline)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    /// Re-derive a bold variant of a descriptor-built font (withDesign drops the
    /// weight trait on some OS versions).
    private static func bold(_ font: UIFont) -> UIFont {
        guard let d = font.fontDescriptor.withSymbolicTraits(
            font.fontDescriptor.symbolicTraits.union(.traitBold)) else { return font }
        return UIFont(descriptor: d, size: font.pointSize)
    }
}
