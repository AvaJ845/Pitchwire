import SwiftUI

/// First-launch introduction. Four pages that state, honestly, what Pitchwire is
/// and what it refuses to be — shown once, gated by `pitchwire.hasOnboarded`.
struct OnboardingView: View {
    /// Called on "Get started" / "Skip". `seedExample` is true only for
    /// "Get started" — Home then pre-fills an example story so the user lands
    /// on something to act on, not an empty box.
    var onFinish: (_ seedExample: Bool) -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(symbol: "sparkles.rectangle.stack",
             title: "An AI press agent in your pocket",
             body: "Paste a launch story. Pitchwire tells you which editorial professionals "
                 + "cover it, why their published work makes them relevant, and gives you a "
                 + "first-draft pitch to work from."),
        Page(symbol: "text.magnifyingglass",
             title: "Every match, explained",
             body: "Each recommendation shows who they are, where they publish, what they "
                 + "cover, and the dated articles that prove it. Tap through to the source "
                 + "and check for yourself."),
        Page(symbol: "hand.raised.fingers.spread",
             title: "Research, not a mailing list",
             body: "No personal contact details — ever. No “send to 500 journalists” button. "
                 + "The score is editorial relevance, never a prediction that someone will "
                 + "reply or cover you."),
        Page(symbol: "lock.iphone",
             title: "Yours, on your device",
             body: "Your unpublished story is analysed on your phone. No account, no sign-up, "
                 + "nothing to lose."),
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    pageView(item).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .tint(Palette.accent)

            VStack(spacing: 4) {
                Button {
                    if isLastPage {
                        onFinish(true)
                    } else {
                        withAnimation(.snappy) { page += 1 }
                    }
                } label: {
                    Text(isLastPage ? "Get started" : "Continue")
                }
                .buttonStyle(.pitchwire)

                // Reserve the row height on every page so "Get started" doesn't
                // jump when Skip disappears.
                Button("Skip") { onFinish(false) }
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.vertical, 10)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
                    .accessibilityHidden(isLastPage)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 16)
        }
        .background(Palette.canvas.ignoresSafeArea())
    }

    private func pageView(_ item: Page) -> some View {
        // A ScrollView that only scrolls when the content is taller than the
        // page — so the largest Dynamic Type sizes stay readable instead of
        // clipping against the fixed layout.
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: item.symbol)
                    .font(.system(size: 66, weight: .semibold))
                    .foregroundStyle(
                        // Teal → dimmer teal. Never `Palette.navy` here — it's a
                        // fixed dark colour and would vanish into a dark canvas.
                        LinearGradient(colors: [Palette.accent, Palette.accent.opacity(0.55)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .accessibilityHidden(true)
                VStack(spacing: 14) {
                    Text(item.title)
                        .font(.system(.title, design: .serif).weight(.bold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(item.body)
                        .font(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding()
            .containerRelativeFrame(.vertical, alignment: .center)
            .accessibilityElement(children: .combine)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
