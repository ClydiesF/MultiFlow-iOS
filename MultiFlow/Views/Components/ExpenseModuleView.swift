import SwiftUI
import UIKit

enum ExpenseInputMode: String, CaseIterable, Identifiable {
    case simple = "Simple"
    case detailed = "Detailed"

    var id: String { rawValue }
}

struct ExpenseModuleView: View {
    let module: MFMetricEngine.ExpenseModule?
    let annualCashFlow: Double?
    @Binding var mode: ExpenseInputMode
    @Binding var simpleRate: String
    @Binding var annualTaxes: String
    @Binding var annualInsurance: String
    @Binding var managementFee: String
    @Binding var maintenanceReserves: String
    private let panel = Color(red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 247.0 / 255.0)
    private let mutedInk = Color(red: 92.0 / 255.0, green: 92.0 / 255.0, blue: 98.0 / 255.0)
    
    private let canvasGrey = Color.canvasWhite
    private let ink = Color.richBlack
    private let buttonBlack = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.16, alpha: 1.0)
        : UIColor(red: 14.0 / 255.0, green: 14.0 / 255.0, blue: 16.0 / 255.0, alpha: 1.0)
    })

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Operating Expenses")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(ink)

            Text("Choose how to model operating expenses for this deal.")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(ink)

            expenseModeTiles

            if mode == .simple {
                VStack(alignment: .leading, spacing: 10) {
                    moduleField(
                        title: "Flat Expense % of Income",
                        placeholder: "35.0",
                        text: $simpleRate,
                        keyboard: .decimalPad,
                        suffix: "%"
                    )
                    .onChange(of: simpleRate) { _, newValue in
                        simpleRate = InputFormatters.sanitizeDecimal(newValue)
                    }

                    if let gross = module?.grossAnnualRent {
                        let rate = (Double(simpleRate) ?? 0) / 100.0
                        let simpleTotal = gross * rate
                        MetricRow(
                            title: "Estimated Annual Expenses",
                            value: Formatters.currency.string(from: NSNumber(value: simpleTotal)) ?? "$0"
                        )
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cardSurface)
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    moduleField(title: "Annual Taxes", placeholder: "$0.00", text: $annualTaxes, keyboard: .decimalPad)
                        .onChange(of: annualTaxes) { _, newValue in
                            annualTaxes = InputFormatters.formatCurrencyLive(newValue)
                        }
                    moduleField(title: "Annual Insurance", placeholder: "$0.00", text: $annualInsurance, keyboard: .decimalPad)
                        .onChange(of: annualInsurance) { _, newValue in
                            annualInsurance = InputFormatters.formatCurrencyLive(newValue)
                        }
                    moduleField(title: "Management Fee", placeholder: "$0.00", text: $managementFee, keyboard: .decimalPad)
                        .onChange(of: managementFee) { _, newValue in
                            managementFee = InputFormatters.formatCurrencyLive(newValue)
                        }
                    moduleField(title: "Maintenance Reserves", placeholder: "$0.00", text: $maintenanceReserves, keyboard: .decimalPad)
                        .onChange(of: maintenanceReserves) { _, newValue in
                            maintenanceReserves = InputFormatters.formatCurrencyLive(newValue)
                        }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cardSurface)
                )

                if let module {
                    MetricRow(
                        title: "Total Operating Expenses",
                        value: Formatters.currency.string(from: NSNumber(value: module.totalOperatingExpenses)) ?? "$0"
                    )
                    MetricRow(
                        title: "NOI",
                        value: Formatters.currency.string(from: NSNumber(value: module.netOperatingIncome)) ?? "$0"
                    )
                }
            }

            if let cashFlow = annualCashFlow {
                let monthlyCashFlow = cashFlow / 12.0

                HStack(spacing: 6) {
                    Text("Monthly Cash Flow")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(ink)
                    Spacer()
                    Text((Formatters.currency.string(from: NSNumber(value: monthlyCashFlow)) ?? "$0") + "/mo")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(ink)

                    if shouldShowExpenseWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primaryYellow)
                    }
                }

                HStack(spacing: 6) {
                    Text("Annual Cash Flow")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(ink.opacity(0.76))
                    Spacer()
                    Text((Formatters.currency.string(from: NSNumber(value: cashFlow)) ?? "$0") + "/yr")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(ink.opacity(0.9))
                }

                Text("Cash Flow = Rent Revenue - Operating Expenses - Debt Service")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(ink.opacity(0.58))
            }
        }
    }

    private var expenseModeTiles: some View {
        HStack(spacing: 10) {
            expenseModeTile(
                mode: .simple,
                title: "Simple",
                body: "One blended % for fastest underwriting."
            )
            expenseModeTile(
                mode: .detailed,
                title: "Detailed",
                body: "Edit taxes, insurance, management, and maintenance."
            )
        }
    }

    private func expenseModeTile(mode tileMode: ExpenseInputMode, title: String, body: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                mode = tileMode
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(mode == tileMode ? Color.primaryYellow : .white)
                Text(body)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(mode == tileMode ? Color.primaryYellow.opacity(0.9) : Color.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(mode == tileMode ? buttonBlack : Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        mode == tileMode
                        ? Color.primaryYellow.opacity(0.55)
                        : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .scaleEffect(mode == tileMode ? 1.0 : 0.985)
        }
        .buttonStyle(.plain)
    }

    private func moduleField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(ink)

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: text,
                    prompt: Text(placeholder)
                        .foregroundStyle(Color(red: 96.0 / 255.0, green: 96.0 / 255.0, blue: 102.0 / 255.0))
                )
                .keyboardType(keyboard)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if let suffix {
                    Text(suffix)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.72))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var shouldShowExpenseWarning: Bool {
        switch mode {
        case .simple:
            return (Double(simpleRate) ?? 0) / 100.0 > 0.5
        case .detailed:
            guard let module else { return false }
            return module.expenseToIncomeRatio > 0.5
        }
    }
}
