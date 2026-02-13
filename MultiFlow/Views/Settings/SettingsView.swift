import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @AppStorage("defaultAppreciationRate") private var defaultAppreciationRate = 3.0
    @AppStorage("defaultMarginalTaxRate") private var defaultMarginalTaxRate = 24.0
    @AppStorage("defaultLandValuePercent") private var defaultLandValuePercent = 20.0
    @AppStorage("defaultMonthlyRentPerUnit") private var defaultMonthlyRentPerUnit = 1500.0
    @AppStorage("colorSchemePreference") private var colorSchemePreference = 0

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header

                    accountAppearanceSection
                    estimatedDefaultsSection
                    glossarySection

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
                    Text("Used across evaluator assumptions and grading.")
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

            VStack(alignment: .leading, spacing: 12) {
                Text("Equity & Tax Defaults")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))

                HStack {
                    TextField("", value: $defaultAppreciationRate, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.softGray)
                        )
                        .onChange(of: defaultAppreciationRate) { _, newValue in
                            let sanitized = InputFormatters.sanitizeDecimal(String(newValue))
                            if let sanitizedValue = Double(sanitized) {
                                defaultAppreciationRate = sanitizedValue
                            }
                        }
                    Text("Appreciation %")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }

                HStack {
                    TextField("", value: $defaultMarginalTaxRate, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.softGray)
                        )
                        .onChange(of: defaultMarginalTaxRate) { _, newValue in
                            let sanitized = InputFormatters.sanitizeDecimal(String(newValue))
                            if let sanitizedValue = Double(sanitized) {
                                defaultMarginalTaxRate = sanitizedValue
                            }
                        }
                    Text("Tax Rate %")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }

                HStack {
                    TextField("", value: $defaultLandValuePercent, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.softGray)
                        )
                        .onChange(of: defaultLandValuePercent) { _, newValue in
                            let sanitized = InputFormatters.sanitizeDecimal(String(newValue))
                            if let sanitizedValue = Double(sanitized) {
                                defaultLandValuePercent = sanitizedValue
                            }
                        }
                    Text("Land Value %")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }
            }
        }
        .cardStyle()
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
    }
}
