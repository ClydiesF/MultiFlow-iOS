import SwiftUI

struct CashToCloseScenarioValues: Hashable {
    var downPaymentPercent: Double
    var closingCostRate: Double
    var renoReserve: Double
}

struct CashToCloseLabSheet: View {
    let purchasePrice: Double
    let baseline: CashToCloseScenarioValues
    let baselineMetrics: DealMetrics?
    let baselineGrade: Grade
    var evaluateScenario: (CashToCloseScenarioValues) -> (metrics: DealMetrics?, grade: Grade)
    var onApply: (CashToCloseScenarioValues) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var downPaymentPercent: Double
    @State private var closingCostRate: Double
    @State private var renoReserveText: String

    init(
        purchasePrice: Double,
        baseline: CashToCloseScenarioValues,
        baselineMetrics: DealMetrics?,
        baselineGrade: Grade,
        evaluateScenario: @escaping (CashToCloseScenarioValues) -> (metrics: DealMetrics?, grade: Grade),
        onApply: @escaping (CashToCloseScenarioValues) -> Void
    ) {
        self.purchasePrice = purchasePrice
        self.baseline = baseline
        self.baselineMetrics = baselineMetrics
        self.baselineGrade = baselineGrade
        self.evaluateScenario = evaluateScenario
        self.onApply = onApply
        _downPaymentPercent = State(initialValue: baseline.downPaymentPercent)
        _closingCostRate = State(initialValue: baseline.closingCostRate)
        _renoReserveText = State(initialValue: Formatters.currencyTwo.string(from: NSNumber(value: baseline.renoReserve)) ?? "\(baseline.renoReserve)")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Formatters.currency.string(from: NSNumber(value: scenarioTotal)) ?? "$0")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.richBlack)
                    Text("Scenario Total Cash Needed")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                    gradeImpactRow
                    scoreDriversRow

                    controlsCard
                    breakdownCard
                    comparisonCard

                    HStack(spacing: 10) {
                        Button("Reset") {
                            reset()
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.richBlack.opacity(0.2), lineWidth: 1)
                        )

                        Button("Apply To Property") {
                            onApply(currentScenario)
                            dismiss()
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.primaryYellow)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.richBlack)
                        )
                    }
                }
                .padding(20)
            }
            .background(Color.canvasWhite.ignoresSafeArea())
            .navigationTitle("Cash to Close Lab")
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

    private var controlsCard: some View {
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
            Slider(value: $downPaymentPercent, in: 0...100, step: 0.5)
                .tint(Color.primaryYellow)

            HStack {
                Text("Closing Cost Rate")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Text("\(closingCostRate, specifier: "%.2f")%")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
            }
            Slider(value: $closingCostRate, in: 0.5...8.0, step: 0.1)
                .tint(Color.primaryYellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("Reno Reserve")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.58))
                TextField("$0", text: $renoReserveText)
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
                    .onChange(of: renoReserveText) { _, newValue in
                        renoReserveText = InputFormatters.formatCurrencyLive(newValue)
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
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

    private var breakdownCard: some View {
        VStack(spacing: 10) {
            row("Down Payment", scenarioDownPayment)
            row("Closing Costs", scenarioClosingCosts)
            row("Reno Reserve", scenarioRenoReserve)
            Divider()
            row("Total Cash Needed", scenarioTotal, bold: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current vs Scenario")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            compareRow("Down Payment", baselineDownPayment, scenarioDownPayment)
            compareRow("Closing Costs", baselineClosingCosts, scenarioClosingCosts)
            compareRow("Reno Reserve", baseline.renoReserve, scenarioRenoReserve)
            compareRow("Total", baselineTotal, scenarioTotal, bold: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private func row(_ title: String, _ value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(bold ? .bold : .semibold))
                .foregroundStyle(Color.richBlack.opacity(0.72))
            Spacer()
            Text(Formatters.currency.string(from: NSNumber(value: value)) ?? "$0")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
    }

    private func compareRow(_ title: String, _ baseline: Double, _ scenario: Double, bold: Bool = false) -> some View {
        let delta = scenario - baseline
        return HStack {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(bold ? .bold : .semibold))
                .foregroundStyle(Color.richBlack.opacity(0.72))
            Spacer()
            Text(Formatters.currency.string(from: NSNumber(value: baseline)) ?? "$0")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.65))
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.richBlack.opacity(0.4))
            Text(Formatters.currency.string(from: NSNumber(value: scenario)) ?? "$0")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
            Text(signedCurrency(delta))
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(delta <= 0 ? Color.primaryYellow : Color.red.opacity(0.9))
        }
    }

    private var currentScenario: CashToCloseScenarioValues {
        CashToCloseScenarioValues(
            downPaymentPercent: downPaymentPercent,
            closingCostRate: closingCostRate,
            renoReserve: scenarioRenoReserve
        )
    }

    private var scenarioRenoReserve: Double {
        max(InputFormatters.parseCurrency(renoReserveText) ?? 0, 0)
    }

    private var scenarioDownPayment: Double {
        max(purchasePrice * (downPaymentPercent / 100.0), 0)
    }

    private var scenarioClosingCosts: Double {
        max(purchasePrice * (closingCostRate / 100.0), 0)
    }

    private var scenarioTotal: Double {
        scenarioDownPayment + scenarioClosingCosts + scenarioRenoReserve
    }

    private var baselineDownPayment: Double {
        max(purchasePrice * (baseline.downPaymentPercent / 100.0), 0)
    }

    private var baselineClosingCosts: Double {
        max(purchasePrice * (baseline.closingCostRate / 100.0), 0)
    }

    private var baselineTotal: Double {
        baselineDownPayment + baselineClosingCosts + max(baseline.renoReserve, 0)
    }

    private var scenarioEvaluation: (metrics: DealMetrics?, grade: Grade) {
        evaluateScenario(currentScenario)
    }

    private var scenarioGrade: Grade {
        scenarioEvaluation.grade
    }

    private var gradeDeltaText: String {
        let tiers: [Grade: Int] = [.a: 3, .b: 2, .c: 1, .dOrF: 0]
        let delta = (tiers[scenarioGrade] ?? 0) - (tiers[baselineGrade] ?? 0)
        if delta == 0 { return "No grade change" }
        return delta > 0 ? "+\(delta) tier" : "\(delta) tier"
    }

    private func metricsDelta(_ keyPath: KeyPath<DealMetrics, Double>) -> Double {
        guard let baselineMetrics, let scenarioMetrics = scenarioEvaluation.metrics else { return 0 }
        return scenarioMetrics[keyPath: keyPath] - baselineMetrics[keyPath: keyPath]
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

    private func reset() {
        downPaymentPercent = baseline.downPaymentPercent
        closingCostRate = baseline.closingCostRate
        renoReserveText = Formatters.currencyTwo.string(from: NSNumber(value: baseline.renoReserve)) ?? "\(baseline.renoReserve)"
    }
}

#Preview {
    CashToCloseLabSheet(
        purchasePrice: 560000,
        baseline: CashToCloseScenarioValues(
            downPaymentPercent: 25,
            closingCostRate: 3.0,
            renoReserve: 15000
        ),
        baselineMetrics: nil,
        baselineGrade: .b,
        evaluateScenario: { _ in (nil, .b) },
        onApply: { _ in }
    )
}
