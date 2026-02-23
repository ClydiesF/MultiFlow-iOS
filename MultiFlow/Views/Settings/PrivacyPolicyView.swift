import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.openURL) private var openURL
    private let privacyURL = URL(string: "https://clydiesf.github.io/MultiFlow-iOS/privacy.html")

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.richBlack)

                    Text("Last updated: February 18, 2026")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.58))

                    VStack(alignment: .leading, spacing: 12) {
                        legalBlock(
                            title: "Data We Store",
                            body: "We store account identifiers and property analysis data that you create in the app so your portfolio can sync across sessions."
                        )
                        legalBlock(
                            title: "How Data Is Used",
                            body: "Data is used to provide app features such as calculations, grading, syncing, and exports. We do not sell your personal data."
                        )
                        legalBlock(
                            title: "Third-Party Services",
                            body: "MultiFlow uses third-party providers for authentication, storage, subscriptions, and market intelligence. Those services process only the data needed to provide their function."
                        )
                        legalBlock(
                            title: "Security",
                            body: "We apply account-level access controls and user-scoped data policies. You should still protect your account credentials and device access."
                        )
                        legalBlock(
                            title: "Your Choices",
                            body: "You can update or remove portfolio information from within the app. Subscription billing and cancellation are managed in Apple account settings."
                        )
                    }
                    .cardStyle()

                    if let privacyURL {
                        Button {
                            openURL(privacyURL)
                        } label: {
                            Label("View Full Privacy Policy Online", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
            Text(body)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
