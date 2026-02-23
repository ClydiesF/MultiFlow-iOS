import SwiftUI

struct TermsAndConditionsView: View {
    @Environment(\.openURL) private var openURL
    private let termsURL = URL(string: "https://clydiesf.github.io/MultiFlow-iOS/terms.html")

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms & Conditions")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.richBlack)

                    Text("Last updated: February 18, 2026")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.58))

                    VStack(alignment: .leading, spacing: 12) {
                        legalBlock(
                            title: "Use of MultiFlow",
                            body: "MultiFlow provides underwriting and analysis tools for educational and planning purposes. It does not provide legal, tax, accounting, lending, or investment advice."
                        )
                        legalBlock(
                            title: "Investor Responsibility",
                            body: "You are responsible for verifying all assumptions, market data, and calculations before making financial decisions. Always confirm deal data with your own due diligence."
                        )
                        legalBlock(
                            title: "Accounts and Access",
                            body: "You are responsible for keeping account credentials secure and for activity performed under your account."
                        )
                        legalBlock(
                            title: "Subscription Billing",
                            body: "Pro features are billed through your Apple account based on your selected plan. Billing, trial, renewal, and cancellation are managed by Apple."
                        )
                        legalBlock(
                            title: "Service Availability",
                            body: "Some features depend on third-party services. Availability and response quality may vary by region and provider limits."
                        )
                    }
                    .cardStyle()

                    if let termsURL {
                        Button {
                            openURL(termsURL)
                        } label: {
                            Label("View Full Terms Online", systemImage: "safari")
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
        TermsAndConditionsView()
    }
}
