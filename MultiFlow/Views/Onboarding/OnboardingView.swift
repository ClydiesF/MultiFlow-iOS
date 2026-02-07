import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = false
    @State private var selection = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Analyze Deals",
            subtitle: "Add properties fast, then evaluate ROI, Cap Rate, and Cash Flow with confidence.",
            symbol: "chart.line.uptrend.xyaxis.circle.fill",
            highlight: "Instant ROI insights",
            chips: ["ROI", "Cap Rate", "Cash Flow"]
        ),
        OnboardingPage(
            title: "Professional Export",
            subtitle: "Create polished PDF deal summaries ready for clients, partners, and lenders.",
            symbol: "doc.richtext.fill",
            highlight: "Client-ready reports",
            chips: ["PDF Export", "Client Ready", "Brand Safe"]
        ),
        OnboardingPage(
            title: "Portfolio Tracking",
            subtitle: "Track performance across time and keep every asset in a single, clean dashboard.",
            symbol: "building.2.crop.circle.fill",
            highlight: "Long-term clarity",
            chips: ["Performance", "Trends", "Hold Strategy"]
        )
    ]

    var body: some View {
        ZStack {
            CanvasBackground()
            OnboardingBackdrop(offsetX: CGFloat(selection) * -18)

            VStack(spacing: 20) {
                header

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageCard(page: page)
                            .padding(.horizontal, 16)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                pageIndicator

                actionRow
            }
            .padding(.top, 18)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRO FLOW")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow.opacity(0.85))
                )
                .padding(.top, 2)

            Text("MultiFlow")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text("The pro-grade toolkit for modern real estate decisions.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.7))

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                Text("Fast. Clear. Investor-ready.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Skip") {
                hasSeenOnboarding = true
                shouldShowOnboarding = false
            }
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.richBlack.opacity(0.7))

            Spacer()

            Button(selection == pages.count - 1 ? "Get Started" : "Next") {
                if selection < pages.count - 1 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        selection += 1
                    }
                } else {
                    hasSeenOnboarding = true
                    shouldShowOnboarding = false
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 24)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == selection ? Color.primaryYellow : Color.softGray)
                    .frame(width: index == selection ? 26 : 10, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selection)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingPage: Hashable {
    let title: String
    let subtitle: String
    let symbol: String
    let highlight: String
    let chips: [String]
}

private struct OnboardingPageCard: View {
    let page: OnboardingPage
    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            let minX = proxy.frame(in: .global).minX
            let parallax = min(max(minX / 18, -18), 18)

            VStack(alignment: .leading, spacing: 18) {
                hero(parallax: parallax)
                chipRow

                Text(page.title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)

                Text(page.subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow)
                        .frame(width: 12, height: 12)
                    Text(page.highlight)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primaryYellow.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
            )
            .overlay(gradientGlow, alignment: .topTrailing)
            .overlay(glassSweep, alignment: .top)
            .scaleEffect(animate ? 1 : 0.985)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: animate)
            .onAppear { animate = true }
            .onDisappear { animate = false }
            .offset(x: -parallax)
        }
        .frame(height: 360)
    }

    private func hero(parallax: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.primaryYellow.opacity(0.2), Color.cardSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primaryYellow.opacity(0.15), lineWidth: 1)
                )

            icon
                .offset(x: 16 + parallax * 0.25, y: -16)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Color.primaryYellow.opacity(0.25))
                .frame(width: 64, height: 64)
            Image(systemName: page.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.richBlack)
                .rotationEffect(.degrees(animate ? 0 : -8))
        }
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(page.chips, id: \.self) { chip in
                Text(chip)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.softGray)
                    )
            }
        }
    }

    private var gradientGlow: some View {
        LinearGradient(
            colors: [Color.primaryYellow.opacity(0.18), Color.clear],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .frame(width: 160, height: 160)
        .blendMode(.screen)
    }

    private var glassSweep: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.35), Color.white.opacity(0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 120)
        .opacity(0.5)
        .blendMode(.screen)
    }
}

#if DEBUG
#Preview {
    OnboardingView()
        .preferredColorScheme(.light)
}
#endif

private struct OnboardingBackdrop: View {
    let offsetX: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.primaryYellow.opacity(0.25), Color.clear],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 180
                    )
                )
                .frame(width: 260, height: 260)
                .offset(x: -110 + offsetX, y: -180)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.primaryYellow.opacity(0.18), Color.clear],
                        center: .bottomTrailing,
                        startRadius: 10,
                        endRadius: 200
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 140 - offsetX, y: 220)
        }
        .allowsHitTesting(false)
    }
}
