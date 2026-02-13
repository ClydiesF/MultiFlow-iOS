import SwiftUI

struct MortgageScenarioValues: Hashable {
    var downPaymentPercent: Double
    var interestRate: Double
    var annualTaxes: Double
    var annualInsurance: Double
    var termYears: Int
}

struct MortgageDetailSheet: View {
    let purchasePrice: Double
    let baseline: MortgageScenarioValues
    let baselineMetrics: DealMetrics?
    let baselineGrade: Grade
    var evaluateScenario: (MortgageScenarioValues) -> (metrics: DealMetrics?, grade: Grade)
    var onApply: (MortgageScenarioValues) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var downPaymentPercent: Double
    @State private var interestRateText: String
    @State private var annualTaxesText: String
    @State private var annualInsuranceText: String
    @State private var selectedTerm: Int

    init(
        purchasePrice: Double,
        baseline: MortgageScenarioValues,
        baselineMetrics: DealMetrics?,
        baselineGrade: Grade,
        evaluateScenario: @escaping (MortgageScenarioValues) -> (metrics: DealMetrics?, grade: Grade),
        onApply: @escaping (MortgageScenarioValues) -> Void
    ) {
        self.purchasePrice = purchasePrice
        self.baseline = baseline
        self.baselineMetrics = baselineMetrics
        self.baselineGrade = baselineGrade
        self.evaluateScenario = evaluateScenario
        self.onApply = onApply
        _downPaymentPercent = State(initialValue: baseline.downPaymentPercent)
        _interestRateText = State(initialValue: String(format: "%.2f", baseline.interestRate))
        _annualTaxesText = State(initialValue: Formatters.currencyTwo.string(from: NSNumber(value: baseline.annualTaxes)) ?? "\(baseline.annualTaxes)")
        _annualInsuranceText = State(initialValue: Formatters.currencyTwo.string(from: NSNumber(value: baseline.annualInsurance)) ?? "\(baseline.annualInsurance)")
        _selectedTerm = State(initialValue: baseline.termYears)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    gradeImpactRow
                    scoreDriversRow

                    controlsSection
                    presetsSection
                    comparisonSection

                    if let scenarioBreakdown {
                        MortgageDonutChart(breakdown: scenarioBreakdown)
                            .frame(height: 180)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.cardSurface)
                            )

                        valueSection(
                            title: "Scenario Monthly",
                            principal: scenarioBreakdown.monthlyPrincipal,
                            interest: scenarioBreakdown.monthlyInterest,
                            taxes: scenarioBreakdown.monthlyTaxes,
                            insurance: scenarioBreakdown.monthlyInsurance,
                            total: scenarioBreakdown.monthlyTotal
                        )

                        valueSection(
                            title: "Scenario Annual",
                            principal: scenarioBreakdown.annualPrincipal,
                            interest: scenarioBreakdown.annualInterest,
                            taxes: scenarioBreakdown.annualTaxes,
                            insurance: scenarioBreakdown.annualInsurance,
                            total: scenarioBreakdown.annualTotal
                        )
                    }

                    sensitivityStrip

                    Text("P&I includes principal paydown plus interest cost based on selected term.")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.62))

                    HStack(spacing: 10) {
                        Button("Reset") {
                            resetScenario()
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.richBlack.opacity(0.2), lineWidth: 1)
                        )

                        Button("Apply To Property") {
                            guard let scenario = currentScenario else { return }
                            onApply(scenario)
                            dismiss()
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.primaryYellow)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.richBlack)
                        )
                        .disabled(currentScenario == nil)
                        .opacity(currentScenario == nil ? 0.45 : 1.0)
                    }

                    Button("Back to Property") {
                        dismiss()
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack.opacity(0.72))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(20)
            }
            .background(Color.canvasWhite.ignoresSafeArea())
            .navigationTitle("Mortgage Scenario Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Formatters.currency.string(from: NSNumber(value: scenarioBreakdown?.monthlyTotal ?? baselineBreakdown?.monthlyTotal ?? 0)) ?? "$0")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.richBlack)
                Text("Scenario Monthly Total")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.58))
            }
            Spacer()
            Text("\(selectedTerm)y term")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow.opacity(0.24))
                )
        }
    }

    private var gradeImpactRow: some View {
        HStack(spacing: 10) {
            gradeChip(title: "Current", grade: baselineGrade)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.richBlack.opacity(0.45))
            gradeChip(title: "Scenario", grade: scenarioGrade)
            Spacer()
            Text(gradeDeltaText)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack.opacity(0.7))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private var scoreDriversRow: some View {
        HStack(spacing: 8) {
            driverPill(title: "Cash Flow", value: signedCurrency(metricsDelta(\.annualCashFlow)))
            driverPill(title: "CoC", value: signedPercent(metricsDelta(\.cashOnCash)))
            driverPill(title: "DCR", value: signedDecimal(metricsDelta(\.debtCoverageRatio)))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Down Payment")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Text("\(downPaymentPercent, specifier: "%.1f")%")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
            }
            Slider(value: $downPaymentPercent, in: 10...50, step: 0.5)
                .tint(Color.primaryYellow)

            HStack(spacing: 8) {
                scenarioField("Interest %", text: $interestRateText, placeholder: "6.50")
                    .onChange(of: interestRateText) { _, newValue in
                        interestRateText = InputFormatters.sanitizeDecimal(newValue)
                    }
                scenarioField("Annual Taxes", text: $annualTaxesText, placeholder: "$0")
                    .onChange(of: annualTaxesText) { _, newValue in
                        annualTaxesText = InputFormatters.formatCurrencyLive(newValue)
                    }
                scenarioField("Annual Insurance", text: $annualInsuranceText, placeholder: "$0")
                    .onChange(of: annualInsuranceText) { _, newValue in
                        annualInsuranceText = InputFormatters.formatCurrencyLive(newValue)
                    }
            }

            HStack(spacing: 8) {
                termTile(15)
                termTile(20)
                termTile(30)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private var presetsSection: some View {
        HStack(spacing: 8) {
            presetButton(label: "Low DP", value: 15)
            presetButton(label: "Conservative", value: 25)
            presetButton(label: "Aggressive", value: 35)
        }
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current vs Scenario")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if let baselineBreakdown, let scenarioBreakdown {
                comparisonRow(
                    title: "P&I",
                    baselineValue: baselineBreakdown.monthlyPrincipal + baselineBreakdown.monthlyInterest,
                    scenarioValue: scenarioBreakdown.monthlyPrincipal + scenarioBreakdown.monthlyInterest
                )
                comparisonRow(
                    title: "Taxes",
                    baselineValue: baselineBreakdown.monthlyTaxes,
                    scenarioValue: scenarioBreakdown.monthlyTaxes
                )
                comparisonRow(
                    title: "Insurance",
                    baselineValue: baselineBreakdown.monthlyInsurance,
                    scenarioValue: scenarioBreakdown.monthlyInsurance
                )
                comparisonRow(
                    title: "Total",
                    baselineValue: baselineBreakdown.monthlyTotal,
                    scenarioValue: scenarioBreakdown.monthlyTotal,
                    emphasize: true
                )
            } else {
                Text("Enter valid scenario values to compare.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private var sensitivityStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sensitivity")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))
            Text(rateSensitivityText)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.72))
            Text(taxSensitivityText)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.72))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.softGray)
        )
    }

    private func valueSection(
        title: String,
        principal: Double,
        interest: Double,
        taxes: Double,
        insurance: Double,
        total: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            lineItem("Principal", principal)
            lineItem("Interest", interest)
            lineItem("Taxes", taxes)
            lineItem("Insurance", insurance)
            Divider()
            lineItem("Total", total, bold: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
        )
    }

    private func lineItem(_ title: String, _ value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(bold ? .bold : .semibold))
                .foregroundStyle(Color.richBlack.opacity(bold ? 0.9 : 0.68))
            Spacer()
            Text(Formatters.currency.string(from: NSNumber(value: value)) ?? "$0")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
    }

    private var baselineBreakdown: MortgageBreakdown? {
        MetricsEngine.mortgageBreakdown(
            purchasePrice: purchasePrice,
            downPaymentPercent: baseline.downPaymentPercent,
            interestRate: baseline.interestRate,
            loanTermYears: Double(baseline.termYears),
            annualTaxes: baseline.annualTaxes,
            annualInsurance: baseline.annualInsurance
        )
    }

    private var scenarioEvaluation: (metrics: DealMetrics?, grade: Grade)? {
        guard let scenario = currentScenario else { return nil }
        return evaluateScenario(scenario)
    }

    private var scenarioGrade: Grade {
        scenarioEvaluation?.grade ?? baselineGrade
    }

    private var gradeDeltaText: String {
        let tiers: [Grade: Int] = [.a: 3, .b: 2, .c: 1, .dOrF: 0]
        let delta = (tiers[scenarioGrade] ?? 0) - (tiers[baselineGrade] ?? 0)
        if delta == 0 { return "No grade change" }
        return delta > 0 ? "+\(delta) tier" : "\(delta) tier"
    }

    private func metricsDelta(_ keyPath: KeyPath<DealMetrics, Double>) -> Double {
        guard let baselineMetrics, let scenarioMetrics = scenarioEvaluation?.metrics else { return 0 }
        return scenarioMetrics[keyPath: keyPath] - baselineMetrics[keyPath: keyPath]
    }

    private var currentScenario: MortgageScenarioValues? {
        guard let interest = Double(interestRateText), interest > 0 else { return nil }
        let taxes = InputFormatters.parseCurrency(annualTaxesText) ?? 0
        let insurance = InputFormatters.parseCurrency(annualInsuranceText) ?? 0
        return MortgageScenarioValues(
            downPaymentPercent: downPaymentPercent,
            interestRate: interest,
            annualTaxes: taxes,
            annualInsurance: insurance,
            termYears: selectedTerm
        )
    }

    private var scenarioBreakdown: MortgageBreakdown? {
        guard let scenario = currentScenario else { return nil }
        return MetricsEngine.mortgageBreakdown(
            purchasePrice: purchasePrice,
            downPaymentPercent: scenario.downPaymentPercent,
            interestRate: scenario.interestRate,
            loanTermYears: Double(scenario.termYears),
            annualTaxes: scenario.annualTaxes,
            annualInsurance: scenario.annualInsurance
        )
    }

    private var rateSensitivityText: String {
        guard let scenario = currentScenario,
              let baseline = scenarioBreakdown,
              let stressed = MetricsEngine.mortgageBreakdown(
                purchasePrice: purchasePrice,
                downPaymentPercent: scenario.downPaymentPercent,
                interestRate: scenario.interestRate + 0.5,
                loanTermYears: Double(scenario.termYears),
                annualTaxes: scenario.annualTaxes,
                annualInsurance: scenario.annualInsurance
              ) else {
            return "+0.5% rate impact unavailable"
        }
        let delta = stressed.monthlyTotal - baseline.monthlyTotal
        return "+0.5% rate: \(signedCurrency(delta))/mo"
    }

    private var taxSensitivityText: String {
        guard let scenario = currentScenario,
              let baseline = scenarioBreakdown,
              let stressed = MetricsEngine.mortgageBreakdown(
                purchasePrice: purchasePrice,
                downPaymentPercent: scenario.downPaymentPercent,
                interestRate: scenario.interestRate,
                loanTermYears: Double(scenario.termYears),
                annualTaxes: scenario.annualTaxes * 1.05,
                annualInsurance: scenario.annualInsurance
              ) else {
            return "+5% taxes impact unavailable"
        }
        let delta = stressed.monthlyTotal - baseline.monthlyTotal
        return "+5% taxes: \(signedCurrency(delta))/mo"
    }

    private func termTile(_ year: Int) -> some View {
        let selected = selectedTerm == year
        return Button {
            selectedTerm = year
        } label: {
            Text("\(year)y")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(selected ? Color.primaryYellow : Color.richBlack.opacity(0.65))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Color.primaryYellow.opacity(0.14) : Color.softGray)
                )
        }
        .buttonStyle(.plain)
    }

    private func gradeChip(title: String, grade: Grade) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.58))
            Text(grade.rawValue)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(gradeColor(for: grade).opacity(0.22))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(gradeColor(for: grade).opacity(0.65), lineWidth: 1)
        )
    }

    private func driverPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.55))
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.softGray)
        )
    }

    private func gradeColor(for grade: Grade) -> Color {
        switch grade {
        case .a: return Color.primaryYellow
        case .b: return Color.green.opacity(0.75)
        case .c: return Color.orange.opacity(0.8)
        case .dOrF: return Color.red.opacity(0.75)
        }
    }

    private func scenarioField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.58))
            TextField(placeholder, text: text)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 8)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.canvasWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.richBlack.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private func presetButton(label: String, value: Double) -> some View {
        Button(label) {
            downPaymentPercent = value
        }
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(Color.richBlack)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.softGray)
        )
    }

    private func comparisonRow(
        title: String,
        baselineValue: Double,
        scenarioValue: Double,
        emphasize: Bool = false
    ) -> some View {
        let delta = scenarioValue - baselineValue
        return HStack {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(emphasize ? .bold : .semibold))
                .foregroundStyle(Color.richBlack.opacity(0.72))
            Spacer()
            Text(Formatters.currency.string(from: NSNumber(value: baselineValue)) ?? "$0")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.65))
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.richBlack.opacity(0.4))
            Text(Formatters.currency.string(from: NSNumber(value: scenarioValue)) ?? "$0")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
            Text(signedCurrency(delta))
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(delta <= 0 ? Color.primaryYellow : Color.red.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill((delta <= 0 ? Color.primaryYellow : Color.red).opacity(0.12))
                )
        }
    }

    private func signedCurrency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        let absValue = abs(value)
        return "\(sign)\(Formatters.currency.string(from: NSNumber(value: absValue)) ?? "$0")"
    }

    private func signedPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.2f%%", abs(value) * 100.0))"
    }

    private func signedDecimal(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }

    private func resetScenario() {
        downPaymentPercent = baseline.downPaymentPercent
        interestRateText = String(format: "%.2f", baseline.interestRate)
        annualTaxesText = Formatters.currencyTwo.string(from: NSNumber(value: baseline.annualTaxes)) ?? "\(baseline.annualTaxes)"
        annualInsuranceText = Formatters.currencyTwo.string(from: NSNumber(value: baseline.annualInsurance)) ?? "\(baseline.annualInsurance)"
        selectedTerm = baseline.termYears
    }
}

#Preview {
    MortgageDetailSheet(
        purchasePrice: 560000,
        baseline: MortgageScenarioValues(
            downPaymentPercent: 25,
            interestRate: 6.4,
            annualTaxes: 12500,
            annualInsurance: 1800,
            termYears: 30
        ),
        baselineMetrics: nil,
        baselineGrade: .b,
        evaluateScenario: { _ in (nil, .b) },
        onApply: { _ in }
    )
}
