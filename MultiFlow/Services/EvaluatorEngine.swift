import Foundation

struct EvaluatorEngine {
    static func evaluate(
        purchasePrice: Double,
        annualCashFlow: Double,
        annualPrincipalPaydown: Double,
        appreciationRate: Double,
        cashflowBreakEvenThreshold: Double,
        marginalTaxRate: Double?,
        landValuePercent: Double?
    ) -> PillarEvaluation {
        let monthlyCashFlow = annualCashFlow / 12.0
        let threshold = max(cashflowBreakEvenThreshold, 0)
        let borderlineRange = threshold > 0 ? threshold * 0.10 : 0
        let isBorderline = threshold > 0 && abs(monthlyCashFlow - threshold) <= borderlineRange
        let cashFlowMet = monthlyCashFlow >= threshold && !isBorderline
        let delta = monthlyCashFlow - threshold
        let deltaLabel = delta >= 0 ? "+" : "-"
        let cashFlowDetail = "Delta vs threshold: \(deltaLabel)\(formatCurrency(abs(delta)))/mo"

        let paydownMet = annualPrincipalPaydown > 0
        let paydownDetail = "Year 1 principal paydown: \(formatCurrency(annualPrincipalPaydown))"

        let annualAppreciation = max(purchasePrice * (appreciationRate / 100.0), 0)
        let equityGain = annualAppreciation + annualPrincipalPaydown
        let equityMet = equityGain > 0
        let equityDetail = "Year 1 equity gain: \(formatCurrency(equityGain)) (Appreciation: \(formatCurrency(annualAppreciation)) + Paydown: \(formatCurrency(annualPrincipalPaydown)))"

        let taxResult: PillarResult
        if let marginalTaxRate, let landValuePercent {
            let basis = max(purchasePrice * (1.0 - landValuePercent / 100.0), 0)
            let annualDepreciation = basis / 27.5
            let taxBenefit = annualDepreciation * (marginalTaxRate / 100.0)
            let taxMet = taxBenefit > 0
            let taxDetail = "Estimated annual tax benefit: \(formatCurrency(taxBenefit))"
            taxResult = PillarResult(pillar: .taxIncentives, status: taxMet ? .met : .notMet, detail: taxDetail, value: taxBenefit, monthlyValue: nil, annualValue: nil, thresholdValue: nil)
        } else {
            taxResult = PillarResult(
                pillar: .taxIncentives,
                status: .needsInput,
                detail: "Add marginal tax rate and land value % to evaluate.",
                value: nil,
                monthlyValue: nil,
                annualValue: nil,
                thresholdValue: nil
            )
        }

        return PillarEvaluation(results: [
            PillarResult(
                pillar: .cashFlow,
                status: isBorderline ? .borderline : (cashFlowMet ? .met : .notMet),
                detail: cashFlowDetail,
                value: annualCashFlow,
                monthlyValue: monthlyCashFlow,
                annualValue: annualCashFlow,
                thresholdValue: threshold
            ),
            PillarResult(pillar: .mortgagePaydown, status: paydownMet ? .met : .notMet, detail: paydownDetail, value: annualPrincipalPaydown, monthlyValue: nil, annualValue: nil, thresholdValue: nil),
            PillarResult(pillar: .equity, status: equityMet ? .met : .notMet, detail: equityDetail, value: equityGain, monthlyValue: nil, annualValue: nil, thresholdValue: nil),
            taxResult
        ])
    }

    private static func formatCurrency(_ value: Double) -> String {
        let rounded = (value * 1).rounded() / 1
        let sign = rounded < 0 ? "-" : ""
        let absValue = abs(rounded)
        return "\(sign)$\(String(format: "%.0f", absValue))"
    }
}
