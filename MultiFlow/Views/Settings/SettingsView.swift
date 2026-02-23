import SwiftUI
import RevenueCatUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @AppStorage("defaultMonthlyRentPerUnit") private var defaultMonthlyRentPerUnit = 1500.0
    @AppStorage("colorSchemePreference") private var colorSchemePreference = 0
    @State private var showCustomerCenter = false
    @State private var showPaywall = false
    @State private var showChangePasswordSheet = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordUpdateError: String?
    @StateObject private var usageManager = RentCastUsageManager.shared
    private let shareAppURL = URL(string: "https://multiflow.app")!
    private let termsURL = URL(string: "https://clydiesf.github.io/MultiFlow-iOS/terms.html")!
    private let privacyURL = URL(string: "https://clydiesf.github.io/MultiFlow-iOS/privacy.html")!

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header

                    accountAppearanceSection
                    subscriptionSection
                    estimatedDefaultsSection
                    glossarySection
                    legalSection
                    shareAppSection

                    Button("Sign Out") {
                        authViewModel.signOut()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text(versionString)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Change Password")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)

                    Text("Set a new password for your account.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.68))

                    LabeledSecureField(title: "New Password", text: $newPassword)
                    LabeledSecureField(title: "Confirm Password", text: $confirmPassword)

                    if let passwordUpdateError {
                        Text(passwordUpdateError)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    Button("Update Password") {
                        Task {
                            passwordUpdateError = nil
                            guard newPassword.count >= 8 else {
                                passwordUpdateError = "Password must be at least 8 characters."
                                return
                            }
                            guard newPassword == confirmPassword else {
                                passwordUpdateError = "Passwords do not match."
                                return
                            }
                            let success = await authViewModel.updatePassword(newPassword: newPassword)
                            if success {
                                showChangePasswordSheet = false
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Spacer()
                }
                .padding(24)
                .background(CanvasBackground())
            }
        }
    }


    private var accountAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Account & Appearance")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Color.richBlack.opacity(0.5))
            }
            if let email = authViewModel.user?.email {
                Text(email)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
            }

            Divider().background(Color.richBlack.opacity(0.1))

            Text("Appearance")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))

            Picker("Theme", selection: $colorSchemePreference) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            .pickerStyle(.segmented)

            Divider().background(Color.richBlack.opacity(0.1))

            Button {
                passwordUpdateError = nil
                newPassword = ""
                confirmPassword = ""
                showChangePasswordSheet = true
            } label: {
                HStack {
                    Text("Change Password")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.richBlack)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private var estimatedDefaultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Defaults")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Used by fast add, portfolio health, and scoring.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color.richBlack.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Default Operating Expense")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))

                HStack {
                    TextField("", value: $standardOperatingExpenseRate, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.softGray)
                        )
                        .onChange(of: standardOperatingExpenseRate) { _, newValue in
                            let sanitized = InputFormatters.sanitizeDecimal(String(newValue))
                            if let sanitizedValue = Double(sanitized) {
                                standardOperatingExpenseRate = sanitizedValue
                            }
                        }
                    Text("%")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Cashflow Break-Even Threshold")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))

                HStack {
                    TextField("", value: $cashflowBreakEvenThreshold, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.softGray)
                        )
                        .onChange(of: cashflowBreakEvenThreshold) { _, newValue in
                            let sanitized = InputFormatters.sanitizeDecimal(String(newValue))
                            if let sanitizedValue = Double(sanitized) {
                                cashflowBreakEvenThreshold = sanitizedValue
                            }
                        }
                    Text("USD")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Default Monthly Rent / Unit")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))

                HStack {
                    TextField("", value: $defaultMonthlyRentPerUnit, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.softGray)
                        )
                        .onChange(of: defaultMonthlyRentPerUnit) { _, newValue in
                            let sanitized = InputFormatters.sanitizeDecimal(String(newValue))
                            if let sanitizedValue = Double(sanitized) {
                                defaultMonthlyRentPerUnit = sanitizedValue
                            }
                        }
                    Text("USD")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }
            }

        }
        .cardStyle()
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Subscription")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Text(subscriptionManager.isPremium ? "Pro Active" : "Free")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(subscriptionManager.isPremium ? Color.primaryYellow : Color.richBlack.opacity(0.5))
            }

            if !subscriptionManager.isPremium {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Text("Upgrade to Pro")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Spacer()
                        Image(systemName: "lock.open.fill")
                    }
                    .foregroundStyle(Color.richBlack)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.primaryYellow, Color.orange.opacity(0.92)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                showCustomerCenter = true
            } label: {
                HStack {
                    Text("Manage Subscription")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(Color.richBlack)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.softGray)
                )
            }
            .buttonStyle(.plain)

            Button {
                Task { _ = await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.72))
            }
            .buttonStyle(.plain)

            if subscriptionManager.isPremium {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Insight Credits")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.7))
                        Spacer()
                        Text("\(usageManager.snapshot.remainingCredits) / \(usageManager.snapshot.quotaCredits)")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.primaryYellow)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.softGray)
                            Capsule(style: .continuous)
                                .fill(Color.primaryYellow)
                                .frame(width: geo.size.width * usageManager.snapshot.usageRatio)
                        }
                    }
                    .frame(height: 8)

                    Text("Costs: Markets 1 • Rent AVM 1 • Value AVM 1 • Property Records 2")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .cardStyle()
        .task {
            await subscriptionManager.refreshCustomerInfo()
            usageManager.ensureCurrentMonth()
        }
    }

    private var glossarySection: some View {
        NavigationLink {
            GlossaryView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primaryYellow.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.closed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.richBlack)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Glossary")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Common real-estate terms and formulas")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.65))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var shareAppSection: some View {
        ShareLink(
            item: shareAppURL,
            message: Text("Check out MultiFlow: Property Evaluator."),
            preview: SharePreview("MultiFlow: Property Evaluator", image: Image("logo"))
        ) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primaryYellow.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.richBlack)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Share MultiFlow")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Invite friends to download the app")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.65))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            Link(destination: termsURL) {
                legalRow(title: "Terms & Conditions", icon: "doc.text")
            }
            .buttonStyle(.plain)

            Link(destination: privacyURL) {
                legalRow(title: "Privacy Policy", icon: "lock.doc")
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private func legalRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primaryYellow.opacity(0.2))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.richBlack)
            }

            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.richBlack.opacity(0.4))
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text("Tune your default assumptions.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.7))

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                Text("Defaults that shape every deal.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthViewModel())
            .environmentObject(SubscriptionManager())
    }
}
