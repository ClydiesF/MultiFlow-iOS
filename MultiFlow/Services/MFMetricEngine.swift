import Foundation

struct MFMetricEngine {
    static func maximumAllowableOffer(for property: Property, targetDCR: Double) -> Double? {
        guard targetDCR > 0 else { return nil }
        guard let metrics = MetricsEngine.computeMetrics(property: property) else { return nil }
        guard let downPaymentPercent = property.downPaymentPercent else { return nil }
        guard let interestRate = property.interestRate else { return nil }

        let termYears = Double(property.loanTermYears ?? Int(MetricsEngine.defaultLoanTermYears))
        guard termYears > 0 else { return nil }

        let annualDebtServiceTarget = metrics.netOperatingIncome / targetDCR
        let paymentPerLoanDollar = annualMortgagePaymentPerDollar(
            annualInterestRate: interestRate,
            years: termYears
        )
        guard paymentPerLoanDollar > 0 else { return nil }

        let maxLoanAmount = annualDebtServiceTarget / paymentPerLoanDollar
        let ltv = 1.0 - (downPaymentPercent / 100.0)
        guard ltv > 0 else { return nil }

        return max(maxLoanAmount / ltv, 0)
    }

    private static func annualMortgagePaymentPerDollar(annualInterestRate: Double, years: Double) -> Double {
        let monthlyRate = (annualInterestRate / 100.0) / 12.0
        let numberOfPayments = years * 12.0
        guard numberOfPayments > 0 else { return 0 }

        if monthlyRate == 0 {
            return 1.0 / years
        }

        let numerator = monthlyRate * pow(1 + monthlyRate, numberOfPayments)
        let denominator = pow(1 + monthlyRate, numberOfPayments) - 1
        let monthlyPaymentPerDollar = numerator / denominator
        return monthlyPaymentPerDollar * 12.0
    }
}
