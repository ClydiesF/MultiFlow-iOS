import Foundation

struct MFMetricEngine {
    struct ExpenseModule {
        let purchasePrice: Double
        let unitCount: Int
        let grossAnnualRent: Double
        let annualTaxes: Double?
        let annualInsurance: Double?
        let mgmtFee: Double?
        let maintenanceReserves: Double?

        var defaultAnnualTaxes: Double {
            purchasePrice * 0.0223
        }

        var defaultAnnualInsurance: Double {
            800.0 * Double(max(unitCount, 0))
        }

        var defaultManagementFee: Double {
            grossAnnualRent * 0.10
        }

        var defaultMaintenanceReserves: Double {
            grossAnnualRent * 0.05
        }

        var effectiveAnnualTaxes: Double {
            annualTaxes ?? defaultAnnualTaxes
        }

        var effectiveAnnualInsurance: Double {
            annualInsurance ?? defaultAnnualInsurance
        }

        var effectiveManagementFee: Double {
            mgmtFee ?? defaultManagementFee
        }

        var effectiveMaintenanceReserves: Double {
            maintenanceReserves ?? defaultMaintenanceReserves
        }

        var totalOperatingExpenses: Double {
            effectiveAnnualTaxes
            + effectiveAnnualInsurance
            + effectiveManagementFee
            + effectiveMaintenanceReserves
        }

        var netOperatingIncome: Double {
            (grossAnnualRent * 0.95) - totalOperatingExpenses
        }

        var expenseToIncomeRatio: Double {
            guard grossAnnualRent > 0 else { return 0 }
            return totalOperatingExpenses / grossAnnualRent
        }
    }

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

    static func grossAnnualRent(from rentRoll: [RentUnitInput]) -> Double {
        rentRoll.compactMap { InputFormatters.parseCurrency($0.monthlyRent) }.reduce(0, +) * 12.0
    }
}
