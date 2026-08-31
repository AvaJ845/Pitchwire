import SwiftUI

/// First-launch introduction. Four pages that state, honestly, what Pitchwire is
/// and what it refuses to be — shown once, gated by `pitchwire.hasOnboarded`.
struct OnboardingView: View {
    var onFinish: () -> Void

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
                 + "cover it, why their published work makes them relevant, and what to say."),
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

            VStack(spacing: 12) {
                Button {
                    if isLastPage {
                        onFinish()
                    } else {
                        withAnimation(.snappy) { page += 1 }
                    }
                } label: {
                    Text(isLastPage ? "Get started" : "Continue")
                }
                .buttonStyle(.pitchwire)

                Button("Skip", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
                    .accessibilityHidden(isLastPage)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 20)
        }
        .background(Palette.canvas.ignoresSafeArea())
    }

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: item.symbol)
                .font(.system(size: 66, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [Palette.accent, Palette.navy],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .accessibilityHidden(true)
            VStack(spacing: 14) {
                Text(item.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}
